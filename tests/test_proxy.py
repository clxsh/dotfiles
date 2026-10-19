"""Proxy functions change the caller's requested environment, not shared files."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('zsh'), 'requires zsh')
class ProxyTest(unittest.TestCase):
    def run_shell(self, code, **extra_env):
        with tempfile.TemporaryDirectory(prefix='dotfiles proxy ') as tmp:
            root = Path(tmp)
            (root / '.ssh').mkdir()
            ssh = root / '.ssh/config'
            ssh.write_text('Host keep-shared\n')
            config = root / '.gitconfig'
            config.write_text('[user]\n\tname = keep\n')
            env = {'HOME': str(root), 'PATH': '/usr/bin:/bin', 'TZ': 'Asia/Singapore',
                   'LANG': 'C', 'LC_ALL': 'C', **extra_env}
            result = subprocess.run(['zsh', '-dfc', 'source "$1"; ' + code, 'test', str(REPO / 'functions.sh')],
                                    env=env, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stderr, '')
            self.assertEqual(ssh.read_text(), 'Host keep-shared\n')
            self.assertEqual(config.read_text(), '[user]\n\tname = keep\n')
            return result.stdout.strip()

    def test_manual_defaults_keep_mac_behavior_without_changing_timezone(self):
        output = self.run_shell('cproxy; print -r -- "$http_proxy:$all_proxy:$TZ:$LANG:$LC_ALL"')
        self.assertEqual(output, 'http://127.0.0.1:7897:socks5://127.0.0.1:7898:Asia/Singapore:C:C')

    def test_custom_endpoints_and_bypass(self):
        output = self.run_shell('cproxy manual; print -r -- "$HTTP_PROXY|$HTTPS_PROXY|$ALL_PROXY|$NO_PROXY"',
                                DOTFILES_HTTP_PROXY='http://proxy.test:8080',
                                DOTFILES_HTTPS_PROXY='http://proxy.test:8443',
                                DOTFILES_ALL_PROXY='socks5h://proxy.test:1080', DOTFILES_NO_PROXY='localhost,.example.test')
        self.assertEqual(output, 'http://proxy.test:8080|http://proxy.test:8443|socks5h://proxy.test:1080|localhost,.example.test')

    def test_custom_http_does_not_leave_the_mac_socks_endpoint_enabled(self):
        output = self.run_shell('cproxy; print -r -- "$HTTP_PROXY|$ALL_PROXY"',
                                DOTFILES_HTTP_PROXY='http://proxy.test:8080')
        self.assertEqual(output, 'http://proxy.test:8080|http://proxy.test:8080')

    def test_explicit_empty_proxy_overrides_and_uppercase_bypass_are_preserved(self):
        output = self.run_shell('cproxy; print -r -- "$ALL_PROXY|$NO_PROXY"',
                                DOTFILES_ALL_PROXY='', NO_PROXY='existing.example')
        self.assertEqual(output, '|existing.example')
        self.assertEqual(self.run_shell('cproxy; print -r -- "bypass:$NO_PROXY"',
                                        DOTFILES_NO_PROXY='', NO_PROXY='existing.example'), 'bypass:')

    def test_tun_and_compatibility_helper_clear_inherited_proxies(self):
        output = self.run_shell('cproxy; proxy_git; print -r -- "$TZ:${http_proxy-unset}:${https_proxy-unset}:${all_proxy-unset}:${HTTP_PROXY-unset}:${HTTPS_PROXY-unset}:${ALL_PROXY-unset}"',
                                DOTFILES_PROXY_MODE='tun', http_proxy='http://wrong:1', https_proxy='http://wrong:1',
                                all_proxy='socks5://wrong:2', HTTP_PROXY='http://wrong:1', HTTPS_PROXY='http://wrong:1', ALL_PROXY='socks5://wrong:2')
        self.assertEqual(output, 'Asia/Singapore:unset:unset:unset:unset:unset:unset')

    def test_off_and_inherit_are_explicit(self):
        self.assertEqual(self.run_shell('cproxy off; print -r -- "${http_proxy-unset}:$DOTFILES_PROXY_MODE"',
                                       http_proxy='http://keep:1'), 'unset:off')
        self.assertEqual(self.run_shell('cproxy inherit; print -r -- "$http_proxy:$DOTFILES_PROXY_MODE"',
                                       http_proxy='http://keep:1', DOTFILES_PROXY_MODE='manual'), 'http://keep:1:inherit')

    def test_sourcing_functions_alone_has_no_proxy_side_effect(self):
        self.assertEqual(self.run_shell('print -r -- "$http_proxy:$TZ"', http_proxy='http://keep:1'),
                         'http://keep:1:Asia/Singapore')


if __name__ == '__main__':
    unittest.main()
