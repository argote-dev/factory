#!/usr/bin/env python3
"""Informational published-1.x canary; never builds or publishes Factory packages."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

import yaml

from verify_release import (ROOT, PUBLISHED_HISTORY, assert_isolated,
                            copy_consumer, digest, manifest, verify_published_history)


def classify_failure(phase, consumer, output):
    """Return a triage area, not a claim of proven root cause."""
    text = output.lower()
    if any(marker in text for marker in (
            'socketexception', 'connection timed out', 'connection reset',
            'could not resolve host', 'http error', 'tls', 'permission denied',
            'no space left', 'failed host lookup', 'timeout expired')):
        return 'infrastructure'
    if phase == 'sdk' or (phase == 'resolution' and any(marker in text for marker in (
            'requires sdk version', 'requires flutter sdk version',
            'current dart sdk version', 'current flutter sdk version',
            'from sdk which depends on'))):
        return 'sdk'
    if phase == 'resolution':
        return 'dependency-resolution'
    if phase in ('generation', 'generated-analysis', 'generated-test', 'generated-drift'):
        return 'generation'
    if consumer == 'flutter':
        return 'factory-provider-integration'
    return 'provider' if consumer == 'provider-control' else 'factory'


class CanaryFailure(RuntimeError):
    def __init__(self, category, message):
        super().__init__(message)
        self.category = category


class CanaryRunner:
    def __init__(self, output):
        self.output = output
        self.records = []

    def run(self, command, cwd, env, phase, consumer):
        index = len(self.records)
        print(f'[{index}] {consumer}/{phase}: {" ".join(command)}', flush=True)
        category = None
        try:
            result = subprocess.run(command, cwd=cwd, env=env, text=True,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    timeout=600)
            output, code = result.stdout, result.returncode
        except (OSError, subprocess.TimeoutExpired) as error:
            partial = getattr(error, 'stdout', None) or ''
            if isinstance(partial, bytes):
                partial = partial.decode(errors='replace')
            output, code, category = partial + '\n' + str(error), -1, 'infrastructure'
        log = f'{index:03d}-{consumer}-{phase}.log'
        (self.output / log).write_text(output)
        self.records.append(dict(command=command, cwd=str(cwd), consumer=consumer,
                                 phase=phase, exit=code, log=log))
        if code:
            category = category or classify_failure(phase, consumer, output)
            self.records[-1]['category'] = category
            raise CanaryFailure(category, f'{consumer}/{phase}: see {log}')
        return output


def check_consumer(runner, source, name, scratch, env, evidence, provider_version=None):
    destination = scratch / name
    record = dict(consumer=name, result='failed')
    evidence['consumers'].append(record)
    phase = 'preparation'
    try:
        copy_consumer(source, destination, '1.0.0', False)
        if provider_version:
            spec = manifest(destination / 'pubspec.yaml')
            spec['dependencies']['provider'] = provider_version
            (destination / 'pubspec.yaml').write_text(yaml.safe_dump(spec, sort_keys=False))
        executable = 'flutter' if 'flutter' in manifest(destination / 'pubspec.yaml')['dependencies'] else 'dart'
        phase = 'resolution'
        runner.run([executable, 'pub', 'upgrade'], destination, env, phase, name)
        record['resolution'] = manifest(destination / 'pubspec.lock')
        phase = 'isolation'
        assert_isolated(destination, scratch, False)
        for package in record['resolution']['packages'].values():
            if package['source'] == 'hosted' and package['description']['url'] != 'https://pub.dev':
                raise RuntimeError('Unexpected hosted repository')
            if package['source'] not in ('hosted', 'sdk'):
                raise RuntimeError('Unexpected non-published dependency')
        for phase, arguments in (('analysis', ['analyze']), ('test', ['test'])):
            runner.run([executable, *arguments], destination, env, phase, name)
        if 'factory_generator' in manifest(destination / 'pubspec.yaml').get('dev_dependencies', {}):
            before = {p.relative_to(destination).as_posix(): digest(p.read_bytes())
                      for p in destination.rglob('*.factory.dart')}
            record['generated'] = dict(before=before)
            for phase, command in (
                    ('generation', ['dart', 'run', 'build_runner', 'build']),
                    ('generated-analysis', [executable, 'analyze']),
                    ('generated-test', [executable, 'test'])):
                runner.run(command, destination, env, phase, name)
            after = {p.relative_to(destination).as_posix(): digest(p.read_bytes())
                     for p in destination.rglob('*.factory.dart')}
            record['generated']['after'] = after
            if before != after:
                phase = 'generated-drift'
                raise CanaryFailure('generation', 'Frozen output changed; inspect saved generated files')
        record['result'] = 'passed'
    except Exception as error:
        record.update(phase=phase, category=(error.category if isinstance(error, CanaryFailure)
                                            else 'infrastructure'), error=str(error))
    finally:
        if destination.exists():
            saved = runner.output / 'consumers' / name
            shutil.copytree(destination, saved, ignore=shutil.ignore_patterns('.dart_tool', 'build'))
            record['files'] = {p.relative_to(saved).as_posix(): digest(p.read_bytes())
                               for p in saved.rglob('*') if p.is_file()}
        write_evidence(runner.output, evidence)
    return record


def write_evidence(output, evidence):
    (output / 'evidence.json').write_text(json.dumps(evidence, indent=2) + '\n')
    rows = [f'| {r["consumer"]} | {r["result"]} | {r.get("category", "—")} |'
            for r in evidence['consumers']]
    summary = ('# Published dependency canary (informational)\n\n'
               f'Result: **{evidence["result"]}**. Categories are triage areas, not proven causes.\n\n'
               '| Consumer | Result | Area |\n| --- | --- | --- |\n' + '\n'.join(rows) + '\n')
    if 'error' in evidence:
        summary += f'\nSetup failure ({evidence["category"]}): {evidence["error"]}\n'
    (output / 'summary.md').write_text(summary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'build/canary')
    args = parser.parse_args()
    output = args.output.resolve()
    if output.exists():
        parser.error('--output must be a new directory to avoid mixing evidence')
    output.mkdir(parents=True)
    runner = CanaryRunner(output)
    evidence = dict(started=datetime.now(timezone.utc).isoformat(), result='failed',
                    informational=True, factory_constraint='^1.0.0', hosted_url='https://pub.dev',
                    commands=runner.records, consumers=[])
    try:
        evidence['commit'] = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
        evidence['worktree_status'] = subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True)
        evidence['consumer_provenance'] = verify_published_history()
        with tempfile.TemporaryDirectory(prefix='factory-canary-') as directory:
            scratch = Path(directory).resolve()
            env = dict(os.environ, PUB_CACHE=str(scratch / 'cache'), PUB_HOSTED_URL='https://pub.dev')
            for sdk in ('dart', 'flutter'):
                evidence[sdk] = runner.run([sdk, '--version'], scratch, env, 'sdk', sdk).strip()
            for kind in ('dart', 'dart_generated', 'flutter'):
                record = check_consumer(runner, PUBLISHED_HISTORY / kind, kind, scratch, env, evidence)
            provider = record.get('resolution', {}).get('packages', {}).get('provider', {}).get('version')
            check_consumer(runner, ROOT / 'tool/canary_contracts/provider', 'provider-control',
                           scratch, env, evidence, provider)
        evidence['result'] = 'passed' if all(r['result'] == 'passed' for r in evidence['consumers']) else 'failed'
    except Exception as error:
        evidence.update(category=error.category if isinstance(error, CanaryFailure) else 'infrastructure',
                        error=str(error))
    finally:
        evidence['finished'] = datetime.now(timezone.utc).isoformat()
        write_evidence(output, evidence)
    return 0 if evidence['result'] == 'passed' else 1


if __name__ == '__main__':
    raise SystemExit(main())
