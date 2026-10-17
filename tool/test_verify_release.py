"""Integrity checks for the published-baseline verification boundary.

Run with: python -m unittest discover -s tool -p 'test_*.py'
Requires release tags/history, as does verify_release.py. Network is stubbed.
"""
import io
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import verify_release as release


class CandidateEvidenceTest(unittest.TestCase):
    def test_command_failure_preserves_diagnostics_and_triage_area(self):
        cases = [('resolution', 'version solving failed', 'dependency-resolution'),
                 ('resolution', 'requires SDK version >=4.0.0', 'sdk'),
                 ('generation', 'Builder failed', 'generation'),
                 ('test', 'Expected: true', 'factory'),
                 ('resolution', 'SocketException: connection reset', 'infrastructure')]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for phase, output, category in cases:
                with self.subTest(phase=phase, category=category):
                    runner = release.Runner(root)
                    command = [sys.executable, '-c', f'print({output!r}); raise SystemExit(2)']
                    with self.assertRaises(release.VerificationFailure) as failure:
                        runner.run(command, root, phase=phase)
                    self.assertEqual(failure.exception.category, category)
                    self.assertEqual(runner.records[0]['exit'], 2)
                    self.assertEqual(runner.records[0]['phase'], phase)
                    self.assertIn(output, (root / runner.records[0]['log']).read_text())

    def test_missing_executable_cannot_satisfy_an_expected_failure_probe(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            runner = release.Runner(root)
            with self.assertRaises(release.VerificationFailure) as failure:
                runner.run([str(root / 'missing-dart')], root, fails=True)
            self.assertEqual(failure.exception.category, 'infrastructure')
            self.assertEqual(runner.records[0]['exit'], -1)

    def test_timeout_retains_partial_log(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            runner = release.Runner(root)
            with patch.object(release.subprocess, 'run', side_effect=subprocess.TimeoutExpired(
                    'dart', 600, output=b'Partial diagnostics')):
                with self.assertRaises(release.VerificationFailure) as failure:
                    runner.run(['dart', 'test'], root)
            self.assertEqual(failure.exception.category, 'infrastructure')
            self.assertIn('Partial diagnostics', (root / runner.records[0]['log']).read_text())


class PublishedBaselineTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.history = self.root / 'history'
        shutil.copytree(release.PUBLISHED_HISTORY, self.history)
        override = patch.object(release, 'PUBLISHED_HISTORY', self.history)
        override.start()
        self.addCleanup(override.stop)

    def test_original_release_consumers_are_verified_against_git(self):
        provenance = release.verify_published_history()
        self.assertEqual(provenance['commit'], 'ccbcf3a4be58f89b4c898b52fbd4af3c380134b2')

    def test_edited_consumer_is_rejected_even_if_its_manifest_hash_is_updated(self):
        name = 'dart/test/interfaces_test.dart'
        changed = b'// Removed the public interface implementer.\n'
        (self.history / name).write_bytes(changed)
        path = self.history / 'provenance.json'
        provenance = json.loads(path.read_text())
        provenance['files'][name] = release.digest(changed)
        path.write_text(json.dumps(provenance))
        with self.assertRaisesRegex(RuntimeError, 'differs from release'):
            release.verify_published_history()

    def test_added_or_removed_consumer_files_are_rejected(self):
        added = self.history / 'dart/test/extra_test.dart'
        added.write_text('// Unrecorded retrospective probe.\n')
        with self.assertRaisesRegex(RuntimeError, 'file set changed'):
            release.verify_published_history()
        added.unlink()
        (self.history / 'dart/test/interfaces_test.dart').unlink()
        with self.assertRaisesRegex(RuntimeError, 'file set changed'):
            release.verify_published_history()

    def test_consumer_copies_change_only_resolution_metadata(self):
        for kind in ('dart', 'flutter', 'dart_generated'):
            for runtime_only in (False, True):
                with self.subTest(kind=kind, runtime_only=runtime_only):
                    source = self.history / kind
                    destination = self.root / f'{kind}-{runtime_only}'
                    release.copy_consumer(source, destination, '1.1.0', runtime_only)
                    originals = {p.relative_to(source): p.read_bytes()
                                 for p in source.rglob('*') if p.is_file()}
                    copies = {p.relative_to(destination): p.read_bytes()
                              for p in destination.rglob('*') if p.is_file()}
                    self.assertEqual(set(copies), set(originals))
                    originals.pop(Path('pubspec.yaml'))
                    copies.pop(Path('pubspec.yaml'))
                    self.assertEqual(copies, originals)
                    spec = release.manifest(destination / 'pubspec.yaml')
                    package = 'factory_provider' if kind == 'flutter' else 'factory_core'
                    self.assertEqual(spec['dependencies'][package], '^1.1.0')

    def pin_test_archives(self):
        path = self.history / 'published_archives.json'
        provenance = json.loads(path.read_text())
        for entry in provenance['packages'].values():
            entry['sha256'] = '79917366a2d55364e0380eba79304f6c4aad8dfcfdc30a968dacaa1f9f9a78f3'
        path.write_text(json.dumps(provenance))
        archives = self.root / 'archives'
        archives.mkdir()
        return archives

    def test_downloads_all_pinned_archives_and_reuses_only_verified_bytes(self):
        archives = self.pin_test_archives()
        with patch.object(release.urllib.request, 'urlopen',
                          side_effect=lambda *a, **kw: io.BytesIO(b'published bytes')) as download:
            provenance = release.published_archives(archives)
        self.assertEqual(download.call_count, 3)
        self.assertEqual(set(provenance['packages']), set(release.PACKAGES))
        for call, entry in zip(download.call_args_list, provenance['packages'].values()):
            self.assertEqual(call.args[0], entry['archive_url'])
        with patch.object(release.urllib.request, 'urlopen') as download:
            release.published_archives(archives)
            download.assert_not_called()
            (archives / 'factory_core.tar.gz').write_bytes(b'corrupt cache')
            with self.assertRaisesRegex(RuntimeError, 'SHA-256 mismatch: factory_core'):
                release.published_archives(archives)
            download.assert_not_called()

    def test_corrupt_download_is_rejected_without_persisting_it(self):
        archives = self.pin_test_archives()
        with patch.object(release.urllib.request, 'urlopen', return_value=io.BytesIO(b'corrupt')):
            with self.assertRaisesRegex(RuntimeError, 'SHA-256 mismatch: factory_core'):
                release.published_archives(archives)
        self.assertEqual(list(archives.iterdir()), [])


if __name__ == '__main__':
    unittest.main()
