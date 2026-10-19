"""Offline Linux setup checks; tools and HOME are isolated on macOS and Linux."""
import os
import shutil
import subprocess
import unittest

from installer_fixture import InstallerFixture


@unittest.skipUnless(shutil.which('zsh'), 'requires zsh')
class LinuxSetupTest(InstallerFixture, unittest.TestCase):
    def run_setup(self, *args, script='debian.sh', expect=0, **env):
        result = subprocess.run(
            ['/bin/bash', '-c', 'umask 000; exec bash "$@"',
             'test', str(self.repo / script), *args],
            env={**self.env, 'OSTYPE': 'linux-gnu', **env}, cwd=self.root, text=True, capture_output=True, timeout=30,
        )
        output = result.stdout + result.stderr
        if expect == 0:
            self.assertEqual(result.returncode, 0, output)
            if script == "debian.sh":
                self.assertIn("Environment setup finished.", output)
        else:
            self.assertNotEqual(result.returncode, 0, output)
            self.assertNotIn('Environment setup finished.', output)
        self.assertEqual(list(self.tmp.iterdir()), [], output)
        self.assertEqual(list(self.home.rglob('.dotfiles-checkout.*')), [], output)
        return output

    def test_proxy_mode_survives_reinstall_from_a_clean_environment(self):
        self.run_setup('--proxy-mode', 'tun')
        config = self.home / '.zshrc'
        original = config.read_text()
        self.run_setup()
        self.assertEqual(config.read_text(), original)
        self.run_setup(script='configure.sh')
        self.assertEqual(config.read_text(), original)

    def test_manual_proxy_reaches_package_manager_without_persistent_git_config(self):
        (self.state / 'available-fzf').unlink()
        self.run_setup('--proxy-mode', 'manual', DOTFILES_HTTP_PROXY='http://proxy.test:8080',
                       EXPECT_HTTP_PROXY='http://proxy.test:8080', HTTP_PROXY='http://wrong:1')
        self.assertEqual(len(self.apt_calls()), 2)
        self.assertFalse((self.home / '.gitconfig').exists())

    def test_explicit_proxy_mode_replaces_saved_mode_and_invalid_mode_preserves_config(self):
        self.run_setup('--proxy-mode', 'tun')
        self.run_setup('--proxy-mode', 'inherit', script='configure.sh')
        config = self.home / '.zshrc'
        expected = config.read_text()
        self.assertIn('export DOTFILES_PROXY_MODE=inherit', expected)
        self.run_setup(script='configure.sh')
        self.assertEqual(config.read_text(), expected)
        self.run_setup('--proxy-mode', 'invalid', expect=1)
        self.assertEqual(config.read_text(), expected)

    def test_configure_only_rejects_package_flags_before_changes(self):
        self.run_setup('--with-dev', script='configure.sh', expect=1)
        self.assertEqual(self.calls(), [])
        self.assertFalse((self.home / '.zshrc').exists())

    def test_unsafe_checkout_targets_fail_before_installs(self):
        alias = self.root / 'home alias'
        alias.symlink_to(self.home, target_is_directory=True)
        for target in (str(self.home) + '/', str(self.repo), str(self.root), str(alias),
                       str(self.home / 'not-created/..')):
            with self.subTest(target=target):
                self.run_setup(expect=1, ZSH=target)
                self.assertEqual(self.calls(), [])
                self.assertTrue(self.repo.is_dir())
                self.assertEqual(self.backups(), [])

    def test_fifo_configuration_fails_before_installing_or_opening_it(self):
        target = self.home / '.vimrc'
        os.mkfifo(target)
        self.run_setup(expect=1)
        self.assertEqual(self.calls(), [])
        self.assertTrue(target.exists())

    def apt_calls(self):
        return [call for call in self.calls() if call[0] == 'apt-get']

    def test_linux_config_and_repeat_preserve_user_files_and_history(self):
        old = self.write('.zshrc', '# user config\n')
        keep = self.write('.dotfiles/.git/keep', 'history')
        (self.repo / '.git').mkdir()
        (self.repo / '.git/keep').write_text('checkout history')
        self.run_setup('--proxy-mode', 'tun')
        config = old.read_text()
        self.assertIn('export DOTFILES_PROXY_MODE=tun', config)
        self.assertNotIn('Added by CatPaw', config)
        self.assertEqual((self.backups()[0] / '.zshrc').read_text(), '# user config\n')
        self.assertEqual(keep.read_text(), 'history')
        self.assertEqual((self.repo / '.git/keep').read_text(), 'checkout history')
        first_calls = len(self.calls())
        first_mtime = old.stat().st_mtime_ns
        self.run_setup('--proxy-mode', 'tun')
        self.assertEqual(old.stat().st_mtime_ns, first_mtime)
        self.assertEqual(len(self.backups()), 1)
        self.assertFalse(any(call[:2] == ['git', 'clone'] for call in self.calls()[first_calls:]))
        self.assertEqual(self.apt_calls(), [])
        self.assertEqual((self.home / '.local/bin/fd').resolve(), (self.bin / 'fdfind').resolve())
        result = subprocess.run(['zsh', '-fc', '\n'.join(config.splitlines()[:4]) + '\nprint -r -- "$DOTFILES_DIR"'],
                                env=self.env, text=True, capture_output=True, check=True)
        self.assertEqual(result.stdout.strip(), str(self.repo.resolve()))

    def test_missing_fzf_uses_native_apt_and_is_not_reinstalled(self):
        (self.state / 'available-fzf').unlink()
        self.run_setup()
        self.run_setup()
        self.assertEqual(self.apt_calls(), [['apt-get', 'update'],
                         ['apt-get', 'install', '-y', '--no-install-recommends', 'fzf']])
        sudo_calls = [call for call in self.calls() if call[0] == 'sudo']
        self.assertEqual(len(sudo_calls), 0 if os.geteuid() == 0 else 2)
        self.assertFalse(any(call[0] in ('curl', 'wget') and call[1:] != ['--version'] for call in self.calls()))

    def test_skip_packages_and_failed_apt_preserve_configs(self):
        old = self.write('.zshrc', '# keep\n')
        (self.state / 'available-fzf').unlink()
        self.run_setup('--skip-packages', expect=1)
        self.assertEqual(self.apt_calls(), [])
        self.run_setup(expect=1, FAIL_APT_UPDATE='yes')
        self.assertEqual(old.read_text(), '# keep\n')
        self.assertEqual(self.backups(), [])
        self.assertFalse(any(call[:2] == ['git', 'clone'] for call in self.calls()))

    def test_extras_are_explicit_and_never_use_pip(self):
        self.run_setup('--with-dev', '--with-security')
        packages = self.apt_calls()[1][4:]
        self.assertIn('python3-venv', packages)
        self.assertIn('pipx', packages)
        self.assertIn('gdb', packages)
        count = len(self.apt_calls())
        self.run_setup('--with-dev', '--with-security')
        self.assertEqual(len(self.apt_calls()), count)
        self.assertFalse((self.home / '.config/pip').exists())

    def test_failed_download_and_repair_preserve_custom_content(self):
        old = self.write('.oh-my-zsh/.git/history', 'keep history')
        custom = self.write('.oh-my-zsh/custom/personal.zsh', '# keep custom\n')
        config = self.write('.zshrc', '# keep config\n')
        self.run_setup(expect=1, FAIL_CLONE='ohmyzsh')
        self.assertEqual(self.backups(), [])
        self.assertEqual(config.read_text(), '# keep config\n')
        self.assertEqual(old.read_text(), 'keep history')
        self.run_setup()
        self.assertEqual(custom.read_text(), '# keep custom\n')
        self.assertEqual((self.backups()[0] / '.oh-my-zsh/.git/history').read_text(), 'keep history')

    def test_created_framework_is_safe_even_under_umask_zero(self):
        self.run_setup()
        for path in (self.home / '.oh-my-zsh').rglob('*'):
            self.assertEqual(path.stat().st_mode & 0o022, 0, str(path))
        self.assertEqual((self.home / '.oh-my-zsh/custom').stat().st_mode & 0o022, 0)

    def test_configure_only_handles_real_and_broken_symlinks_without_downloads(self):
        target = self.write('personal-vimrc', 'my vim config\n')
        (self.home / '.vimrc').symlink_to(target)
        (self.home / '.inputrc').symlink_to('missing-inputrc')
        self.run_setup(script='configure.sh')
        self.assertEqual(target.read_text(), 'my vim config\n')
        self.assertFalse((self.home / '.vimrc').is_symlink())
        self.assertEqual((self.backups()[0] / '.vimrc').read_text(), 'my vim config\n')
        self.assertTrue((self.backups()[0] / '.inputrc').is_symlink())
        self.assertEqual((self.home / '.inputrc').read_text(), (self.repo / 'inputrc/inputrc').read_text())
        self.run_setup(script='configure.sh')
        self.assertEqual(len(self.backups()), 1)
        self.assertEqual(self.calls(), [])

    def test_existing_fd_and_ssh_are_not_modified(self):
        fd = self.write('.local/bin/fd', '# custom fd\n')
        ssh = self.write('.ssh/config', 'Host shared\n')
        self.run_setup('--proxy-mode', 'tun')
        self.run_setup('--proxy-mode', 'tun')
        self.assertEqual(fd.read_text(), '# custom fd\n')
        self.assertEqual(ssh.read_text(), 'Host shared\n')

    def test_custom_locations_and_invalid_destination(self):
        (self.home / '.zshrc').mkdir()
        self.run_setup(expect=1)
        self.assertEqual(self.calls(), [])
        self.run_setup(ZDOTDIR=str(self.home / 'shell config'), ZSH=str(self.home / 'shell framework'),
                       ZSH_CUSTOM=str(self.home / 'shell plugins'))
        self.assertTrue((self.home / 'shell config/.zshrc').is_file())
        self.assertTrue((self.home / 'shell plugins/plugins/fzf-tab/fzf-tab.plugin.zsh').is_file())

    def test_p10k_loads_once_after_framework_and_optional_tools_are_quiet(self):
        self.run_setup('--proxy-mode', 'tun')
        (self.home / '.oh-my-zsh/oh-my-zsh.sh').write_text('typeset -g OMZ_READY=yes\n')
        (self.home / '.p10k.zsh').write_text('typeset -gi P10K_LOADS=$(( ${P10K_LOADS:-0} + 1 ))\n'
                                          'typeset -g P10K_ORDER=${OMZ_READY:-no}\n')
        (self.bin / 'fnm').unlink()
        (self.bin / 'fzf').unlink()
        shutil.rmtree(self.home / '.oh-my-zsh/custom/plugins/fzf-tab')
        ssh = self.write('.ssh/config', 'shared SSH\n')
        env = {**self.env, 'TZ': 'Asia/Singapore', 'http_proxy': 'http://wrong:1', 'ALL_PROXY': 'socks5://wrong:2'}
        result = subprocess.run(['zsh', '-dfc', 'source "$HOME/.zshrc"; '
                                 'print -r -- "$P10K_LOADS:$P10K_ORDER:$TZ:${http_proxy-unset}:${ALL_PROXY-unset}"'],
                                env=env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), '1:yes:Asia/Singapore:unset:unset')
        self.assertEqual(result.stderr, '')
        self.assertEqual(ssh.read_text(), 'shared SSH\n')
        self.assertFalse((self.home / '.gitconfig').exists())


    def test_direct_and_legacy_entries_are_quiet_without_optional_components(self):
        (self.bin / 'fnm').unlink()
        (self.bin / 'fzf').unlink()
        self.run_setup(script='configure.sh')
        config = self.home / '.zshrc'
        config.unlink()
        for entry in ('debian.zshrc', 'zshrc'):
            with self.subTest(entry=entry):
                config.symlink_to(self.repo / 'zshrc' / entry)
                result = subprocess.run(['zsh', '-dfc', 'source "$HOME/.zshrc"; print -r -- "$dotpath:$+functions[cproxy]"'],
                                        env=self.env, text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stderr, '')
                self.assertEqual(result.stdout.strip(), str(self.repo.resolve()) + ':1')
                config.unlink()

    def test_staged_permission_repairs_do_not_follow_shared_directory_links(self):
        shared = self.root / 'shared'
        shared.mkdir(mode=0o777)
        shared.chmod(0o777)
        target = shared / 'config'
        target.write_text('shared configuration')
        target.chmod(0o666)
        custom = self.home / '.oh-my-zsh/custom'
        custom.mkdir(parents=True)
        (custom / 'shared').symlink_to(shared, target_is_directory=True)
        self.run_setup()
        self.assertEqual(shared.stat().st_mode & 0o777, 0o777)
        self.assertEqual(target.stat().st_mode & 0o777, 0o666)
        self.assertEqual(target.read_text(), 'shared configuration')
        self.assertEqual((custom / 'shared').resolve(), shared.resolve())


if __name__ == '__main__':
    unittest.main()
