import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import yaml

from verify_canary import CanaryFailure, CanaryRunner, classify_failure, main, write_evidence


class CanaryTest(unittest.TestCase):
    def test_failure_areas_distinguish_components_and_unresolved_solver_failures(self):
        cases = [
            ('test', 'dart', 'Expected: true', 'factory'),
            ('test', 'provider-control', 'Expected: second', 'provider'),
            ('test', 'flutter', 'Expected: hello', 'factory-provider-integration'),
            ('generation', 'flutter', 'Builder failed', 'generation'),
            ('generated-test', 'flutter', 'Expected: hello', 'generation'),
            ('resolution', 'flutter', 'requires SDK version >=4.0.0', 'sdk'),
            ('resolution', 'flutter', 'flutter_test from sdk which depends on meta', 'sdk'),
            ('resolution', 'dart', 'version solving failed', 'dependency-resolution'),
            ('generation', 'dart_generated', 'SocketException: connection reset', 'infrastructure'),
        ]
        for phase, consumer, output, expected in cases:
            with self.subTest(phase=phase, consumer=consumer, output=output):
                self.assertEqual(classify_failure(phase, consumer, output), expected)

    def test_failed_command_retains_exit_log_and_classification(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            runner = CanaryRunner(root)
            command = [sys.executable, '-c', 'print("Expected: true"); raise SystemExit(2)']
            with self.assertRaises(CanaryFailure) as failure:
                runner.run(command, root, None, 'test', 'dart')
            self.assertEqual(failure.exception.category, 'factory')
            self.assertEqual(runner.records[0]['exit'], 2)
            self.assertEqual(runner.records[0]['command'], command)
            self.assertIn('Expected: true', (root / runner.records[0]['log']).read_text())

    def test_missing_sdk_executable_is_infrastructure_not_a_factory_regression(self):
        with tempfile.TemporaryDirectory() as directory:
            runner = CanaryRunner(Path(directory))
            with self.assertRaises(CanaryFailure) as failure:
                runner.run([str(Path(directory) / 'missing-dart')], Path(directory), None, 'sdk', 'dart')
            self.assertEqual(failure.exception.category, 'infrastructure')
            self.assertEqual(len(runner.records), 1)

    def test_timeout_is_recorded_as_infrastructure(self):
        with tempfile.TemporaryDirectory() as directory:
            runner = CanaryRunner(Path(directory))
            with patch('verify_canary.subprocess.run', side_effect=subprocess.TimeoutExpired(
                    'dart', 600, output=b'Partial compiler diagnostics')):
                with self.assertRaises(CanaryFailure) as failure:
                    runner.run(['dart', 'test'], Path(directory), None, 'test', 'dart')
            self.assertEqual(failure.exception.category, 'infrastructure')
            self.assertEqual(runner.records[0]['exit'], -1)
            self.assertIn('Partial compiler diagnostics',
                          (Path(directory) / runner.records[0]['log']).read_text())

    def test_cli_continues_after_consumer_failure_and_preserves_replay_files(self):
        real_run = subprocess.run

        def fake_sdk(command, **kwargs):
            if command[0] not in ('dart', 'flutter'):
                return real_run(command, **kwargs)
            cwd = Path(kwargs['cwd'])
            if command[1:3] == ['pub', 'upgrade']:
                # Emulate the external Pub boundary, not consumer implementation.
                spec = yaml.safe_load((cwd / 'pubspec.yaml').read_text())
                names = set(spec['dependencies']) | set(spec.get('dev_dependencies', {}))
                names -= {'flutter', 'flutter_test'}
                packages = {name: dict(version='6.1.5+1' if name == 'provider' else '1.0.0',
                                       source='hosted', description=dict(url='https://pub.dev', sha256='test'))
                            for name in names}
                (cwd / 'pubspec.lock').write_text(yaml.safe_dump(dict(packages=packages)))
                (cwd / '.dart_tool').mkdir()
                cache = Path(kwargs['env']['PUB_CACHE'])
                config = {'packages': [dict(name=n, rootUri=(cache / n).as_uri()) for n in names]}
                (cwd / '.dart_tool/package_config.json').write_text(json.dumps(config))
            failed = cwd.name == 'dart' and command[1:] == ['test']
            return subprocess.CompletedProcess(command, 1 if failed else 0,
                                               stdout='Expected: true' if failed else 'SDK stub success')

        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'report'
            with patch.object(sys, 'argv', ['verify_canary', '--output', str(output)]), \
                    patch('verify_canary.subprocess.run', side_effect=fake_sdk):
                self.assertEqual(main(), 1)
            evidence = json.loads((output / 'evidence.json').read_text())
            self.assertEqual(evidence['result'], 'failed')
            self.assertEqual([r['result'] for r in evidence['consumers']],
                             ['failed', 'passed', 'passed', 'passed'])
            self.assertEqual(evidence['consumers'][0]['category'], 'factory')
            for consumer in ('dart', 'dart_generated', 'flutter', 'provider-control'):
                self.assertTrue((output / 'consumers' / consumer / 'pubspec.lock').is_file())
            control = yaml.safe_load((output / 'consumers/provider-control/pubspec.yaml').read_text())
            self.assertEqual(control['dependencies']['provider'], '6.1.5+1')

    def test_failure_evidence_keeps_successful_and_failed_consumers(self):
        evidence = dict(result='failed', consumers=[
            dict(consumer='dart', result='passed'),
            dict(consumer='provider-control', result='failed', category='provider')])
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            write_evidence(output, evidence)
            self.assertEqual(json.loads((output / 'evidence.json').read_text()), evidence)
            summary = (output / 'summary.md').read_text()
            self.assertIn('| dart | passed |', summary)
            self.assertIn('| provider-control | failed | provider |', summary)


if __name__ == '__main__':
    unittest.main()
