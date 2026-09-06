"""Offline installer tests; all filesystem writes stay in temporary directories."""
import configparser
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('setup', Path(__file__).with_name('setup.py'))
setup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup)


class SetupTests(unittest.TestCase):
    def test_shell_initialization_is_idempotent(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'bashrc'
            path.write_text('export EXISTING=value\n')
            setup.append_once(path, '. /example/env.sh # nvim-setup')
            setup.append_once(path, '. /example/env.sh # nvim-setup')
            self.assertEqual(path.read_text().count('# nvim-setup'), 1)
            self.assertIn('export EXISTING=value', path.read_text())

    def test_wakapi_private_write_preserves_other_settings(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'wakatime.cfg'
            path.write_text('[settings]\ndebug = true\n[other]\nvalue = retained\n')
            with patch.object(setup.getpass, 'getpass', return_value='test-key'):
                self.assertTrue(setup.configure_wakapi(path, True))
            config = configparser.ConfigParser()
            config.read(path)
            self.assertEqual(config['settings']['api_url'], 'https://wakapi.dev/api')
            self.assertEqual(config['settings']['api_key'], 'test-key')
            self.assertEqual(config['settings']['debug'], 'true')
            self.assertEqual(config['other']['value'], 'retained')
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            with patch.object(setup.getpass, 'getpass', side_effect=AssertionError('should not prompt')):
                self.assertTrue(setup.configure_wakapi(path, True))

    def test_noninteractive_wakapi_never_overwrites_other_service(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'wakatime.cfg'
            original = '[settings]\napi_key = another-service-key\n'
            path.write_text(original)
            self.assertFalse(setup.configure_wakapi(path, False))
            self.assertEqual(path.read_text(), original)

    def test_checksum_failure_does_not_extract_or_install(self):
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / 'tool'
            with patch.object(setup, 'download', side_effect=lambda url, target: target.write_bytes(b'corrupt')):
                with patch.object(setup, 'run') as run:
                    with self.assertRaisesRegex(RuntimeError, 'Checksum'):
                        setup.install_archive('https://example.test', 'tool.tar.gz', '0' * 64, destination, 'bin/tool')
                    run.assert_not_called()
            self.assertFalse(destination.exists())

    def test_verified_archive_is_installed_and_reused(self):
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / 'tool'
            def extract(*args):
                binary = Path(args[-1]) / 'bin/tool'
                binary.parent.mkdir()
                binary.write_text('test binary')
            with patch.object(setup, 'download', side_effect=lambda url, target: target.write_bytes(b'archive')) as download:
                with patch.object(setup, 'run', side_effect=extract):
                    setup.install_archive('https://example.test', 'tool.tar.gz', hashlib.sha256(b'archive').hexdigest(), destination, 'bin/tool')
                    setup.install_archive('https://example.test', 'tool.tar.gz', hashlib.sha256(b'archive').hexdigest(), destination, 'bin/tool')
                self.assertEqual(download.call_count, 1)
            self.assertTrue((destination / 'bin/tool').exists())

    def test_dry_run_never_executes_commands(self):
        with patch.object(setup.sys, 'argv', ['setup.py', '--dry-run']):
            with patch.object(setup, 'run', side_effect=AssertionError('unexpected mutation')):
                self.assertEqual(setup.main(), 0)


if __name__ == '__main__':
    unittest.main()
