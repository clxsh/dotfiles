"""Isolated installer fixtures shared by the macOS and Linux regression tests."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


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
if tool == "sudo":
    if args[0] != "-n":
        sys.exit("sudo must be non-interactive")
    command = args[1:]
    if command[0].startswith("--preserve-env="):
        preserve = command.pop(0).split("=", 1)[1].split(",")
    else:
        preserve = []
    for key in ("http_proxy", "https_proxy", "all_proxy", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY"):
        if key not in preserve:
            os.environ.pop(key, None)
    os.execvp(command[0], command)
elif tool == "dpkg-query":
    if (state / ("available-" + args[-1])).exists():
        print("install ok installed")
    else:
        sys.exit(1)
elif tool == "apt-get":
    if "EXPECT_HTTP_PROXY" in os.environ:
        for key in ("http_proxy", "https_proxy", "HTTP_PROXY", "HTTPS_PROXY"):
            if os.environ.get(key) != os.environ["EXPECT_HTTP_PROXY"]:
                sys.exit("Proxy environment was not applied/preserved for " + key)
    if os.environ.get("DEBIAN_FRONTEND") != "noninteractive":
        sys.exit("apt must be non-interactive")
    if args == ["update"]:
        sys.exit(1 if os.environ.get("FAIL_APT_UPDATE") else 0)
    if args[:3] != ["install", "-y", "--no-install-recommends"]:
        sys.exit("Unexpected apt command")
    for package in args[3:]:
        if package == os.environ.get("FAIL_INSTALL"):
            sys.exit(43)
        (state / ("available-" + package)).touch()
elif tool == "brew":
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


class InstallerFixture:
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
        for tool in ("brew", "curl", "git", "fnm", "jq", "wget", "fzf", "apt-get", "dpkg-query", "sudo", "fdfind"):
            path = self.bin / tool
            path.write_text(f"#!{sys.executable}\n" + FAKE_TOOL)
            path.chmod(0o755)
            (self.state / ("available-" + tool)).touch()

        (self.state / "available-ca-certificates").touch()

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
        return list(root.glob("*-*"))
