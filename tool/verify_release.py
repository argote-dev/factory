#!/usr/bin/env python3
"""Build with Pub, then verify isolated hosted consumers without local overrides.

Requires tool/requirements.txt. The loopback server is test infrastructure, not
publication. Only GET requests are supported; candidate uploads are impossible.
"""
import argparse
import hashlib
import http.server
import json
import io
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import threading
import urllib.error
import urllib.request

import yaml

ROOT = Path(__file__).resolve().parent.parent
PACKAGES = {
    'factory_core': ROOT / 'packages/factory_core',
    'factory_provider': ROOT,
    'factory_generator': ROOT / 'packages/factory_generator',
}
PUBLISHED_HISTORY = ROOT / 'tool/consumer_contracts/historical/1.0.0'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def manifest(path):
    return yaml.safe_load(path.read_text())


def check_versions():
    specs = {name: manifest(path / 'pubspec.yaml') for name, path in PACKAGES.items()}
    versions = {spec['version'] for spec in specs.values()}
    if len(versions) != 1:
        raise RuntimeError(f'Uncoordinated package versions: {versions}')
    version = versions.pop()
    for name, path in PACKAGES.items():
        if not (path / 'CHANGELOG.md').read_text().startswith(f'## {version}\n'):
            raise RuntimeError(f'{name} changelog does not lead with {version}')
        spec = specs[name]
        if name != 'factory_core' and spec['dependencies']['factory_core'] != f'^{version}':
            raise RuntimeError(f'{name} must constrain core to ^{version}')
        if name != 'factory_generator' and 'factory_generator' in spec.get('dependencies', {}):
            raise RuntimeError('Generator leaked into runtime dependencies')
    return version


class Runner:
    def __init__(self, output):
        self.output = output
        self.records = []

    def run(self, command, cwd, env=None, fails=False):
        index = len(self.records)
        print(f'[{index}] {cwd.name}: {" ".join(command)}', flush=True)
        result = subprocess.run(command, cwd=cwd, env=env, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        log = f'{index:03d}-{Path(command[0]).name}.log'
        (self.output / log).write_text(result.stdout)
        self.records.append(dict(command=command, cwd=str(cwd), exit=result.returncode,
                                 expected_failure=fails, log=log))
        if (result.returncode == 0) == fails:
            raise RuntimeError(f'Unexpected exit {result.returncode}; see {self.output / log}\n'
                               + result.stdout[-4000:])
        return result.stdout


class PackageServer(http.server.ThreadingHTTPServer):
    request_queue_size = 128
    daemon_threads = True
    def __init__(self, archives):
        super().__init__(('127.0.0.1', 0), PackageHandler)
        self.url = f'http://127.0.0.1:{self.server_port}'
        self.packages = {}
        for archive in archives.glob('factory_*.tar.gz'):
            data = archive.read_bytes()
            with tarfile.open(archive) as package:
                spec = yaml.safe_load(package.extractfile('pubspec.yaml').read())
                if any(p.endswith('pubspec_overrides.yaml') for p in package.getnames()):
                    raise RuntimeError(f'Local overrides leaked into {archive.name}')
            self.packages[spec['name']] = (spec, data)


class PackageHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_GET(self):
        name = self.path.removeprefix('/api/packages/').split('/')[0]
        if self.path.startswith('/api/packages/') and name in self.server.packages:
            spec, data = self.server.packages[name]
            entry = dict(version=spec['version'], pubspec=spec,
                         archive_url=f'{self.server.url}/archives/{name}.tar.gz',
                         archive_sha256=digest(data))
            body = json.dumps(dict(name=name, latest=entry, versions=[entry])).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
        elif self.path.startswith('/archives/'):
            name = self.path.split('/')[-1].removesuffix('.tar.gz')
            if name not in self.server.packages:
                self.send_error(404)
                return
            body = self.server.packages[name][1]
            self.send_response(200)
            self.send_header('Content-Type', 'application/octet-stream')
        else:
            # Public dependencies retain their pub.dev archive URLs and hashes.
            try:
                with urllib.request.urlopen('https://pub.dev' + self.path, timeout=60) as response:
                    body = response.read()
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
            except urllib.error.HTTPError as error:
                self.send_error(error.code)
                return
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def copy_consumer(source, destination, version, runtime_only):
    shutil.copytree(source, destination, ignore=shutil.ignore_patterns(
        '.dart_tool', 'build', 'pubspec.lock', 'pubspec_overrides.yaml'))
    spec = manifest(destination / 'pubspec.yaml')
    for section in ('dependencies', 'dev_dependencies'):
        for name in PACKAGES:
            if name in spec.get(section, {}):
                spec[section][name] = f'^{version}'
    if runtime_only:
        spec['environment']['sdk'] = '>=3.3.0 <4.0.0'
        for name in ('build_runner', 'factory_generator'):
            spec.get('dev_dependencies', {}).pop(name, None)
    (destination / 'pubspec.yaml').write_text(yaml.safe_dump(spec, sort_keys=False))
    # The isolated directory cannot inherit checkout analysis options. Preserve
    # the consumer's own configuration (or its absence) verbatim.


def assert_isolated(consumer, scratch, runtime_only):
    config = json.loads((consumer / '.dart_tool/package_config.json').read_text())
    from urllib.parse import urljoin, urlparse, unquote
    for package in config['packages']:
        uri = urljoin((consumer / '.dart_tool/package_config.json').as_uri(), package['rootUri'])
        path = Path(unquote(urlparse(uri).path)).resolve()
        if path.is_relative_to(ROOT):
            raise RuntimeError(f'Checkout dependency leaked: {path}')
        if package['name'] in PACKAGES and not path.is_relative_to(scratch / 'cache'):
            raise RuntimeError(f'Factory not installed from isolated hosted cache: {path}')
        if runtime_only and package['name'] == 'factory_generator':
            raise RuntimeError('Runtime check installed generator')
    if (consumer / 'pubspec_overrides.yaml').exists():
        raise RuntimeError('Unexpected local overrides')


def verify_consumer(runner, source, destination, version, env, scratch, runtime_only, lower_dependencies=False):
    copy_consumer(source, destination, version, runtime_only)
    if lower_dependencies:
        spec = manifest(destination / 'pubspec.yaml')
        if 'provider' in spec.get('dependencies', {}):
            spec['dependencies']['provider'] = '6.1.5+1'
            (destination / 'pubspec.yaml').write_text(yaml.safe_dump(spec, sort_keys=False))
    executable = 'flutter' if 'flutter' in manifest(destination / 'pubspec.yaml').get('dependencies', {}) else 'dart'
    runner.run([executable, 'pub', 'get'], destination, env)
    assert_isolated(destination, scratch, runtime_only)
    runner.records[-1]['resolved_packages'] = manifest(destination / 'pubspec.lock')['packages']
    runner.run([executable, 'analyze'], destination, env)
    runner.run([executable, 'test'], destination, env)
    spec = manifest(destination / 'pubspec.yaml')
    if 'factory_generator' in spec.get('dev_dependencies', {}):
        generated = {p.relative_to(destination): p.read_bytes() for p in destination.rglob('*.factory.dart')}
        runner.run(['dart', 'run', 'build_runner', 'build'], destination, env)
        for path, previous in generated.items():
            if (destination / path).read_bytes() != previous:
                raise RuntimeError(f'Generated drift: {path}')
        runner.run([executable, 'test'], destination, env)


def verify_history():
    base = ROOT / 'tool/consumer_contracts/historical/0.3.0'
    provenance = json.loads((base / 'provenance.json').read_text())
    release_commit = subprocess.check_output(
        ['git', 'rev-parse', provenance['tag'] + '^{}'], cwd=ROOT, text=True).strip()
    if release_commit != provenance['commit']:
        raise RuntimeError('Historical tag does not identify the recorded release commit')
    for path, expected in provenance['files'].items():
        released = subprocess.check_output(
            ['git', 'show', f'{release_commit}:tool/consumer_contracts/{path}'], cwd=ROOT)
        if (base / path).read_bytes() != released or digest(released) != expected:
            raise RuntimeError(f'Historical consumer differs from release: {path}')
    generated = ROOT / 'tool/consumer_contracts/historical/0.3.0-generated'
    frozen = json.loads((generated / 'provenance.json').read_text())
    if frozen['generator_commit'] != release_commit:
        raise RuntimeError('Frozen generated Dart targets a different baseline release')
    for path, expected in frozen['files'].items():
        if digest((generated / path).read_bytes()) != expected:
            raise RuntimeError(f'Frozen generated Dart consumer edited: {path}')
    return base


def verify_published_history():
    provenance = json.loads((PUBLISHED_HISTORY / 'provenance.json').read_text())
    commit = subprocess.check_output(
        ['git', 'rev-parse', provenance['tag'] + '^{}'], cwd=ROOT, text=True).strip()
    if commit != provenance['commit']:
        raise RuntimeError('Published baseline tag differs from its release commit')
    released_paths = subprocess.check_output(
        ['git', 'ls-tree', '-r', '--name-only', commit, '--', *[
            provenance['source_prefix'] + kind for kind in ('dart', 'flutter', 'dart_generated')]],
        cwd=ROOT, text=True).splitlines()
    expected_paths = {path.removeprefix(provenance['source_prefix']) for path in released_paths}
    actual_paths = {path.relative_to(PUBLISHED_HISTORY).as_posix()
                    for kind in ('dart', 'flutter', 'dart_generated')
                    for path in (PUBLISHED_HISTORY / kind).rglob('*') if path.is_file()}
    if expected_paths != set(provenance['files']) or actual_paths != expected_paths:
        raise RuntimeError('Published baseline consumer file set changed')
    for path, expected in provenance['files'].items():
        released = subprocess.check_output(
            ['git', 'show', f'{commit}:{provenance["source_prefix"]}{path}'], cwd=ROOT)
        if (PUBLISHED_HISTORY / path).read_bytes() != released or digest(released) != expected:
            raise RuntimeError(f'Published baseline consumer differs from release: {path}')
    return provenance


def published_archives(archives):
    provenance = json.loads((PUBLISHED_HISTORY / 'published_archives.json').read_text())
    if set(provenance['packages']) != set(PACKAGES):
        raise RuntimeError('Published baseline must pin all three packages')
    for name, entry in provenance['packages'].items():
        commit = subprocess.check_output(
            ['git', 'rev-parse', entry['tag'] + '^{}'], cwd=ROOT, text=True).strip()
        if commit != entry['commit'] or commit != json.loads(
                (PUBLISHED_HISTORY / 'provenance.json').read_text())['commit']:
            raise RuntimeError(f'Published package tag differs from consumer release: {name}')
        if entry['version'] != '1.0.0':
            raise RuntimeError(f'Unexpected published baseline version: {name}')
        archive = archives / f'{name}.tar.gz'
        if not archive.exists():
            with urllib.request.urlopen(entry['archive_url'], timeout=60) as response:
                data = response.read()
            if digest(data) != entry['sha256']:
                raise RuntimeError(f'Published archive SHA-256 mismatch: {name}')
            archive.write_bytes(data)
        if digest(archive.read_bytes()) != entry['sha256']:
            raise RuntimeError(f'Published archive SHA-256 mismatch: {name}')
    return provenance


def sensitivity_probes(runner, scratch, version, env, server):
    consumer = scratch / 'current-dart'
    interfaces = consumer / 'test/interfaces_test.dart'
    original = interfaces.read_text()
    try:
        # Reproduce the real pre-0.3 FactoryRef implementer shape.
        interfaces.write_text(original.replace(
            '  @override\n  FactoryResolver get resolver => delegate.resolver;\n', ''))
        output = runner.run(['dart', 'analyze'], consumer, env, fails=True)
        if 'non_abstract_class_inherits_abstract_member' not in output or 'FactoryRef.resolver' not in output:
            raise RuntimeError('Interface probe failed for an unrelated reason')
    finally:
        interfaces.write_text(original)
    runner.run(['dart', 'analyze'], consumer, env)

    config = json.loads((consumer / '.dart_tool/package_config.json').read_text())
    from urllib.parse import urljoin, urlparse, unquote
    core = next(p for p in config['packages'] if p['name'] == 'factory_core')
    core_path = Path(unquote(urlparse(urljoin(
        (consumer / '.dart_tool/package_config.json').as_uri(), core['rootUri'])).path))
    lifecycle = core_path / 'lib/src/container.dart'
    original = lifecycle.read_text()
    test = consumer / 'test/resolver_sensitivity_test.dart'
    shutil.copyfile(ROOT / 'packages/factory_core/test/resolver_test.dart', test)
    try:
        changed = original.replace('    _markClosed();', '    // Controlled closing regression.')
        if changed == original:
            raise RuntimeError('Lifecycle mutation no longer applies')
        lifecycle.write_text(changed)
        output = runner.run(['dart', 'test', str(test), '--name',
                             'resolution stops as soon as asynchronous parent closure begins'],
                            consumer, env, fails=True)
        if 'Expected:' not in output:
            raise RuntimeError('Lifecycle probe did not reach its behavioral assertion')
    finally:
        lifecycle.write_text(original)
    runner.run(['dart', 'test', str(test)], consumer, env)

    # Serve a broken archive through the same hosted boundary. Preserve all
    # third-party downloads, but force Pub to reinstall Factory from the server.
    broken_cache = scratch / 'broken-cache'
    shutil.copytree(scratch / 'cache', broken_cache)
    for item in list(broken_cache.rglob('*')):
        if item.exists() and item.name.startswith('factory_core'):
            if item.is_dir():
                shutil.rmtree(item)
            else:
                item.unlink()
    spec, original_bytes = server.packages['factory_core']
    damaged = io.BytesIO()
    with tarfile.open(fileobj=io.BytesIO(original_bytes), mode='r:gz') as source:
        with tarfile.open(fileobj=damaged, mode='w:gz') as target:
            for member in source.getmembers():
                if member.name != 'lib/factory_core.dart':
                    target.addfile(member, source.extractfile(member) if member.isfile() else None)
    server.packages['factory_core'] = (spec, damaged.getvalue())
    destination = scratch / 'omitted-public-file'
    copy_consumer(ROOT / 'tool/consumer_contracts/dart', destination, version, True)
    broken_env = dict(env, PUB_CACHE=str(broken_cache))
    try:
        runner.run(['dart', 'pub', 'get'], destination, broken_env)
        output = runner.run(['dart', 'test'], destination, broken_env, fails=True)
        if 'factory_core.dart' not in output:
            raise RuntimeError('Archive probe failed for an unrelated reason')
    finally:
        server.packages['factory_core'] = (spec, original_bytes)
    runner.run(['dart', 'test'], consumer, env)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'build/release-verification')
    parser.add_argument('--archives', type=Path, help='Consume existing Pub archives instead of building')
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--runtime-only', action='store_true')
    mode.add_argument('--probes-only', action='store_true')
    mode.add_argument('--generator-only', action='store_true')
    mode.add_argument('--baseline-release', action='store_true', help='Build and execute immutable v0.3.0 runtime baseline')
    mode.add_argument('--published-baseline', action='store_true',
                      help='Execute immutable 1.0 consumers against pinned pub.dev 1.0.0 archives')
    parser.add_argument('--lower-dependencies', action='store_true')
    args = parser.parse_args()
    if args.published_baseline and (args.archives or args.lower_dependencies):
        parser.error('--published-baseline cannot use candidate archives or lower dependencies')
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    runner = Runner(args.output)
    archives = args.archives.resolve() if args.archives else args.output / (
        'published-archives' if args.published_baseline else 'archives')
    archives.mkdir(parents=True, exist_ok=True)
    evidence = dict(commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                    dirty=bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT)),
                    runtime_only=args.runtime_only, commands=runner.records, result='failed',
                    archive_source='pub.dev' if args.published_baseline else (
                        'rebuilt-v0.3.0' if args.baseline_release else 'candidate'))
    try:
        version = check_versions()
        history = verify_history()
        if not args.baseline_release:
            evidence['consumer_provenance'] = verify_published_history()
        evidence['version'] = version
        evidence['dart'] = runner.run(['dart', '--version'], ROOT).strip()
        if not args.generator_only:
            evidence['flutter'] = runner.run(['flutter', '--version'], ROOT).strip()
        if args.baseline_release and args.archives:
            raise RuntimeError('Baseline must be built from its recorded release commit')
        if args.published_baseline:
            evidence['published_provenance'] = published_archives(archives)
            version = evidence['version'] = '1.0.0'
        elif args.baseline_release:
            release_commit = json.loads((history / 'provenance.json').read_text())['commit']
            evidence['runtime_commit'] = release_commit
            with tempfile.TemporaryDirectory(prefix='factory-baseline-') as directory:
                release = Path(directory)
                archive_bytes = subprocess.check_output(['git', 'archive', release_commit], cwd=ROOT)
                with tarfile.open(fileobj=io.BytesIO(archive_bytes)) as archive:
                    archive.extractall(release, filter='data')
                version = manifest(release / 'pubspec.yaml')['version']
                evidence['version'] = version
                for name, path in PACKAGES.items():
                    runner.run(['dart', 'pub', 'publish', '--skip-validation',
                                f'--to-archive={archives / (name + ".tar.gz")}'],
                               release / path.relative_to(ROOT))
        elif not args.archives:
            for name, path in PACKAGES.items():
                runner.run(['dart', 'pub', 'publish', '--skip-validation',
                            f'--to-archive={archives / (name + ".tar.gz")}'], path)
        evidence['archives'] = {p.name: digest(p.read_bytes()) for p in archives.glob('*.tar.gz')}
        with tempfile.TemporaryDirectory(prefix='factory-hosted-') as directory:
            scratch = Path(directory).resolve()
            server = PackageServer(archives)
            if set(server.packages) != set(PACKAGES) or any(
                    spec['version'] != version for spec, _ in server.packages.values()):
                server.server_close()
                raise RuntimeError('Archives must contain the three coordinated candidate versions')
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            env = dict(os.environ, PUB_CACHE=str(scratch / 'cache'), PUB_HOSTED_URL=server.url)
            try:
                # Validate the exact archive contents; no source overrides or sibling paths.
                for name in PACKAGES:
                    if args.probes_only or args.published_baseline:
                        continue
                    if args.generator_only and name != 'factory_generator':
                        continue
                    if args.runtime_only and name == 'factory_generator':
                        continue
                    package = scratch / name
                    package.mkdir()
                    with tarfile.open(archives / f'{name}.tar.gz') as archive:
                        archive.extractall(package, filter='data')
                    executable = 'flutter' if name == 'factory_provider' else 'dart'
                    runner.run([executable, 'pub', 'publish', '--dry-run'], package, env)
                    runner.run([executable, 'test', *(['--no-pub'] if executable == 'flutter' else [])], package, env)
                    runner.run([executable, 'analyze', *(['--no-pub'] if executable == 'flutter' else []), 'lib', 'test'], package, env)
                consumers = [('current', ROOT / 'tool/consumer_contracts'),
                             ('historical', history),
                             ('previous-generation', history.parent / '0.3.0-generated')]
                if args.published_baseline:
                    consumers = [('published-1.0.0', PUBLISHED_HISTORY)]
                elif not args.baseline_release:
                    consumers.append(('published-1.0.0', PUBLISHED_HISTORY))
                for label, base in consumers:
                    for kind in ('dart', 'flutter', 'dart_generated'):
                        if args.probes_only and (label != 'current' or kind != 'dart'):
                            continue
                        if args.generator_only and kind != 'dart_generated':
                            continue
                        if not (base / kind).exists():
                            continue
                        verify_consumer(runner, base / kind, scratch / f'{label}-{kind}',
                                        version, env, scratch, args.runtime_only, args.lower_dependencies)
                if not args.generator_only and not args.probes_only and not args.published_baseline:
                    frozen = ROOT / 'tool/consumer_contracts/historical/0.3.0-interfaces'
                    provenance = json.loads((frozen / 'provenance.json').read_text())
                    for path, expected in provenance['files'].items():
                        if digest((frozen / path).read_bytes()) != expected:
                            raise RuntimeError(f'Frozen implementer changed: {path}')
                    verify_consumer(runner, frozen, scratch / 'historical-interfaces',
                                    version, env, scratch, args.runtime_only)
                if not any((args.runtime_only, args.generator_only, args.baseline_release,
                            args.published_baseline)):
                    sensitivity_probes(runner, scratch, version, env, server)
                evidence['result'] = 'passed'
            finally:
                server.shutdown()
                server.server_close()
    except Exception as error:
        evidence['error'] = str(error)
        raise
    finally:
        (args.output / 'evidence.json').write_text(json.dumps(evidence, indent=2) + '\n')


if __name__ == '__main__':
    main()
