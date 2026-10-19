"""Provider aliases read credentials at invocation without storing them."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
PROVIDERS = (
    ('kc', 'KIMI_API_KEY', 'ANTHROPIC_API_KEY'),
    ('zc', 'ZHIPU_API_KEY', 'ANTHROPIC_AUTH_TOKEN'),
)


@unittest.skipUnless(shutil.which('zsh'), 'requires zsh')
class AliasTest(unittest.TestCase):
    def run_shell(self, code):
        with tempfile.TemporaryDirectory(prefix='dotfiles aliases ') as home:
            return subprocess.run(
                ['zsh', '-dfc', 'source "$1"; eval "$2"', 'test', str(REPO / 'aliases.sh'), code],
                env={'HOME': home, 'PATH': '/usr/bin:/bin'}, text=True, capture_output=True,
            )

    def test_credentials_are_read_at_invocation_and_arguments_are_preserved(self):
        for alias, source, target in PROVIDERS:
            with self.subTest(alias=alias):
                result = self.run_shell(
                    f'claude() {{ print -r -- "${target}|$#|$1"; }}\n'
                    f'{source}="fixture value"\n'
                    f'{alias} "two words"\n'
                    f'{source}="updated value"\n'
                    f'{alias} "two words"\n'
                    f'print -r -- "${{{target}-unset}}"\n'
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stderr, '')
                self.assertEqual(result.stdout, 'fixture value|1|two words\nupdated value|1|two words\nunset\n')

    def test_missing_or_empty_credentials_do_not_start_claude(self):
        for alias, source, _ in PROVIDERS:
            for setup in ('', f'{source}=""\n'):
                with self.subTest(alias=alias, empty=bool(setup)):
                    result = self.run_shell('claude() { print -r -- started; }\n' + setup + alias + '\n')
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(result.stdout, '')
                    self.assertIn(source, result.stderr)


if __name__ == '__main__':
    unittest.main()
