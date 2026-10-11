"""Offline macOS installer regression tests; no real packages or user files are changed.

Run with: python3 -m unittest discover -s tests -v
"""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
MARKERS = {
    "ohmyzsh": ["oh-my-zsh.sh", "lib/completion.zsh", "tools/check_for_upgrade.sh",
                "templates/zshrc.zsh-template"],
    "zsh-autosuggestions": ["zsh-autosuggestions.plugin.zsh", "zsh-autosuggestions.zsh"],
    "zsh-syntax-highlighting": ["zsh-syntax-highlighting.plugin.zsh", "zsh-syntax-highlighting.zsh"],
    "fzf-tab": ["fzf-tab.plugin.zsh", "fzf-tab.zsh"],
    "zsh-z": ["zsh-z.plugin.zsh"],
    "powerlevel10k": ["powerlevel10k.zsh-theme", "internal/p10k.zsh"],
}

FAKE_TOOL = r'''
import json, os, pathlib, shlex, sys
tool = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
state = pathlib.Path(os.environ["TEST_STATE"])
with (state / "calls").open("a") as log:
    log.write(json.dumps([tool] + args) + "\n")
if tool == "brew":
    if args == ["shellenv", "bash"] or args == ["shellenv", "zsh"]:
        if os.environ.get("FAIL_SHELLENV"):
            sys.exit(42)
        print("export PATH=" + shlex.quote(os.environ["TEST_BIN"]) + ':"$PATH"')
    elif len(args) == 2 and args[0] == "install":
        if args[1] == os.environ.get("FAIL_INSTALL"):
            sys.exit(43)
        (state / ("available-" + args[1])).touch()
    else:
        sys.exit("Unexpected brew command: " + repr(args))
elif args == ["--version"]:
    if not (state / ("available-" + tool)).exists():
        sys.exit(127)
    print(tool + " 99.0.0")
elif tool == "git" and args[:2] == ["clone", "--depth=1"]:
    name = args[2].rsplit("/", 1)[-1].removesuffix(".git")
    if name == os.environ.get("FAIL_CLONE"):
        sys.exit(44)
    dest = pathlib.Path(args[3])
    markers = json.loads(os.environ["TEST_MARKERS"])[name]
    for marker in markers:
        path = dest / marker
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("# fixture for " + name + "\n")
    (dest / ".git").mkdir()
    (dest / ".git" / "fixture").write_text("preserve git metadata\n")
elif tool == "fnm" and args == ["env", "--use-on-cd", "--shell", "zsh"]:
    print("export FNM_FIXTURE_LOADED=yes")
else:
    sys.exit("Unexpected tool command: " + repr([tool] + args))
'''


@unittest.skipUnless(sys.platform == "darwin", "uses macOS Bash and zsh")
class MacOSSetupTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles tests ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home ' quoted"
        self.home.mkdir()
        self.repo = self.root / "repo ' quoted"
        shutil.copytree(REPO, self.repo, ignore=shutil.ignore_patterns(".git", "__pycache__"))
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.state = self.root / "state"
        self.state.mkdir()
        self.tmp = self.root / "tmp"
        self.tmp.mkdir()
        self.env = {
            "HOME": str(self.home), "PATH": f"{self.bin}:/usr/bin:/bin:/usr/sbin:/sbin",
            "TMPDIR": str(self.tmp), "SHELL": "/bin/zsh", "LC_ALL": "C",
            "TEST_STATE": str(self.state), "TEST_BIN": str(self.bin),
            "TEST_MARKERS": json.dumps(MARKERS),
        }
        for tool in ("brew", "curl", "git", "fnm", "jq", "wget", "fzf"):
            path = self.bin / tool
            path.write_text(f"#!{sys.executable}\n" + FAKE_TOOL)
            path.chmod(0o755)
            (self.state / ("available-" + tool)).touch()

    def run_setup(self, expect=0, prelude="", **env):
        result = subprocess.run(
            ["/bin/bash", "-c", 'source "$1"; ' + prelude + '; main' if prelude
             else 'source "$1"; main', "test", str(self.repo / "macos.sh")],
            env={**self.env, **env}, cwd=self.root, text=True, capture_output=True,
        )
        output = result.stdout + result.stderr
        if expect == 0:
            self.assertEqual(result.returncode, 0, output)
            self.assertIn("Environment setup finished.", output)
        else:
            self.assertNotEqual(result.returncode, 0, output)
            self.assertNotIn("Environment setup finished.", output)
        self.assertEqual(list(self.tmp.iterdir()), [], output)
        self.assertEqual(list(self.home.rglob(".dotfiles-checkout.*")), [], output)
        return output

    def calls(self):
        path = self.state / "calls"
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def write(self, relative, text):
        path = self.home / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def backups(self):
        root = self.home / ".dotfiles-backups"
        return list(root.glob("macos-*"))

    def test_repeat_is_noop_and_preserves_existing_repositories(self):
        old_profile = "export KEEP_ME=yes\n"
        self.write(".zprofile", old_profile)
        old_zshrc = self.write(".zshrc", "# my old shell config\n")
        keep_repo = self.write(".dotfiles/.git/keep", "history")
        keep_dir = self.write("dotfiles/keep", "user files")
        self.run_setup()
        backup = self.backups()[0]
        self.assertEqual((backup / ".zprofile").read_text(), old_profile)
        self.assertEqual((backup / ".zshrc").read_text(), "# my old shell config\n")
        first_calls = len(self.calls())
        first_mtime = old_zshrc.stat().st_mtime_ns
        self.run_setup()
        self.assertEqual(old_zshrc.stat().st_mtime_ns, first_mtime)
        self.assertEqual(self.backups(), [backup])
        self.assertEqual(keep_repo.read_text(), "history")
        self.assertEqual(keep_dir.read_text(), "user files")
        self.assertEqual((self.home / ".zprofile").read_text().count("shellenv"), 1)
        self.assertFalse(any(c[:2] == ["brew", "install"] for c in self.calls()))
        self.assertFalse(any(c[:2] == ["git", "clone"] for c in self.calls()[first_calls:]))
        # Generated shell assignments must handle spaces and quotes in repository paths.
        preamble = "\n".join(old_zshrc.read_text().splitlines()[:4])
        result = subprocess.run(["/bin/zsh", "-fc", preamble + '\nprintf "%s" "$DOTFILES_DIR"'],
                                env=self.env, capture_output=True, text=True, check=True)
        self.assertEqual(result.stdout, str(self.repo.resolve()))

    def test_repairs_partial_framework_and_plugin_preserving_custom_files(self):
        self.write(".oh-my-zsh/.git/old-history", "old git metadata")
        self.write(".oh-my-zsh/custom/personal.zsh", "# personal customization\n")
        plugin = ".oh-my-zsh/custom/plugins/zsh-autosuggestions"
        self.write(plugin + "/local-notes", "keep these notes")
        self.run_setup()
        backup = self.backups()[0]
        self.assertTrue((self.home / ".oh-my-zsh/oh-my-zsh.sh").is_file())
        self.assertEqual((self.home / ".oh-my-zsh/custom/personal.zsh").read_text(),
                         "# personal customization\n")
        self.assertEqual((backup / ".oh-my-zsh/.git/old-history").read_text(), "old git metadata")
        self.assertEqual((backup / "zsh-autosuggestions/local-notes").read_text(), "keep these notes")
        self.run_setup()
        self.assertEqual(self.backups(), [backup])

    def test_failed_download_leaves_old_installation_and_configs_untouched(self):
        old = self.write(".oh-my-zsh/custom/personal.zsh", "# keep\n")
        config = self.write(".zshrc", "# untouched\n")
        self.run_setup(expect=1, FAIL_CLONE="ohmyzsh")
        self.assertEqual(old.read_text(), "# keep\n")
        self.assertEqual(config.read_text(), "# untouched\n")
        self.assertEqual(self.backups(), [])
        self.run_setup()

    def test_missing_tool_is_installed_once_without_reinstalling_system_tools(self):
        (self.state / "available-fzf").unlink()
        self.run_setup()
        self.run_setup()
        self.assertEqual([c for c in self.calls() if c[:2] == ["brew", "install"]],
                         [["brew", "install", "fzf"]])

    def test_failed_package_install_does_not_claim_success_or_write_configs(self):
        (self.state / "available-fnm").unlink()
        original = self.write(".zshrc", "# keep\n")
        self.run_setup(expect=1, FAIL_INSTALL="fnm")
        self.assertEqual(original.read_text(), "# keep\n")
        self.assertFalse(any(c[:2] == ["git", "clone"] for c in self.calls()))

    def test_failed_shellenv_stops_before_other_actions(self):
        self.run_setup(expect=1, FAIL_SHELLENV="yes")
        self.assertEqual(self.calls(), [["brew", "shellenv", "bash"]])
        self.assertFalse((self.home / ".zshrc").exists())

    def test_symlinked_config_is_backed_up_without_editing_its_target(self):
        original = self.write("original-vimrc", '" personal vim config\n')
        (self.home / ".vimrc").symlink_to("original-vimrc")
        self.run_setup()
        self.assertFalse((self.home / ".vimrc").is_symlink())
        self.assertEqual(original.read_text(), '" personal vim config\n')
        self.assertEqual((self.backups()[0] / ".vimrc").read_text(), original.read_text())

    def test_backup_failure_preserves_original(self):
        original = self.write(".zshrc", "# original\n")
        self.write(".dotfiles-backups", "not a directory")
        self.run_setup(expect=1)
        self.assertEqual(original.read_text(), "# original\n")

    def test_invalid_profile_is_not_overwritten(self):
        original = self.write(".zprofile", "if broken syntax\n")
        self.run_setup(expect=1)
        self.assertEqual(original.read_text(), "if broken syntax\n")
        self.assertFalse((self.home / ".zshrc").exists())

    def test_configuration_directory_conflict_fails_before_installs(self):
        (self.home / ".zshrc").mkdir()
        self.run_setup(expect=1)
        self.assertEqual(self.calls(), [])

    def test_missing_repository_file_fails_before_installs(self):
        (self.repo / "vim/vimrc").unlink()
        self.run_setup(expect=1)
        self.assertEqual(self.calls(), [])

    def test_custom_locations_are_used_consistently(self):
        config = self.home / "shell config"
        framework = self.home / "shell framework"
        custom = self.home / "shell plugins"
        self.run_setup(ZDOTDIR=str(config), ZSH=str(framework), ZSH_CUSTOM=str(custom))
        self.assertTrue((config / ".zprofile").is_file())
        self.assertTrue((config / ".zshrc").is_file())
        self.assertTrue((framework / "oh-my-zsh.sh").is_file())
        self.assertTrue((custom / "plugins/fzf-tab/fzf-tab.plugin.zsh").is_file())
        self.assertFalse((self.home / ".zshrc").exists())

    def test_all_tools_available_does_not_require_homebrew(self):
        self.run_setup(prelude="find_homebrew() { return 1; }")
        self.assertFalse(any(c[0] == "brew" for c in self.calls()))
        self.assertFalse((self.home / ".zprofile").exists())


if __name__ == "__main__":
    unittest.main()
