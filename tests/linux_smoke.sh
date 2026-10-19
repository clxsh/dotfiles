#!/bin/bash
# Opt-in integration test for a fresh disposable Debian/Ubuntu Docker container.
set -Eeuo pipefail
trap 'printf "Smoke test failed at line %s (status %s)\n" "$LINENO" "$?" >&2' ERR
[[ -f /.dockerenv && "${DOTFILES_TEST_CONTAINER:-}" == 1 && "$EUID" == 0 ]] || {
  echo 'Run only in a new disposable container with DOTFILES_TEST_CONTAINER=1.' >&2
  exit 1
}
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
sandbox=$(mktemp -d /tmp/dotfiles-smoke.XXXXXX)
chmod 755 "$sandbox"
repo="$sandbox/repo ' quoted"
mkdir -p "$repo" "$sandbox/root home" "$sandbox/shared-ssh"
cp -R "$SOURCE_DIR/." "$repo/"
printf 'Host preserved\n' > "$sandbox/shared-ssh/config"
ln -s "$sandbox/shared-ssh" "$sandbox/root home/.ssh"
printf '# original user configuration\n' > "$sandbox/root home/.zshrc"
mkdir -p "$sandbox/root home/.dotfiles/.git"
printf 'keep\n' > "$sandbox/root home/.dotfiles/.git/sentinel"
umask 000

env -i HOME="$sandbox/root home" PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  DOTFILES_PROXY_MODE=tun TZ=Asia/Singapore TERM=xterm-256color \
  bash "$repo/install.sh" > "$sandbox/root-install.log" 2>&1 || { tail -60 "$sandbox/root-install.log"; exit 1; }
cp "$sandbox/root home/.zshrc" "$sandbox/first-zshrc"
env -i HOME="$sandbox/root home" PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  TZ=Asia/Singapore TERM=xterm-256color \
  bash "$repo/install.sh" --skip-packages > "$sandbox/root-repeat.log" 2>&1
cmp "$sandbox/first-zshrc" "$sandbox/root home/.zshrc"
test -f "$sandbox/root home/.dotfiles/.git/sentinel"
test "$(find "$sandbox/root home/.dotfiles-backups" -mindepth 1 -maxdepth 1 -type d | wc -l)" -eq 1
if grep -q 'Cloning into' "$sandbox/root-repeat.log"; then
  echo 'Repeat install unexpectedly cloned repositories.' >&2
  exit 1
fi
[[ "$(cat "$sandbox/shared-ssh/config")" == 'Host preserved' ]]
cat > "$sandbox/check.zsh" <<'ZSH'
[[ "$TZ" == Asia/Singapore ]] || exit 10
[[ -z "${http_proxy-}${https_proxy-}${all_proxy-}${HTTP_PROXY-}${HTTPS_PROXY-}${ALL_PROXY-}" ]] || exit 11
for fn in git_prompt_info _zsh_autosuggest_start _zsh_highlight zshz; do
  (( $+functions[$fn] )) || { print -u2 -- "Missing plugin function: $fn"; exit 12; }
done
(( $+functions[p10k] && $+functions[_p9k_precmd] && $+widgets[fzf-tab-complete] )) || {
  print -u2 -- "Missing theme/fzf-tab: $+functions[p10k] $+functions[_p9k_precmd] $+widgets[fzf-tab-complete]"; exit 13;
}
(( ${#POWERLEVEL9K_LEFT_PROMPT_ELEMENTS} > 0 )) || exit 14
autoload -Uz compaudit
audit="$(compaudit)"
[[ -z "$audit" ]] || { print -u2 -- "$audit"; exit 15; }
cproxy
proxy_git
[[ "$TZ" == Asia/Singapore && -z "${http_proxy-}${all_proxy-}" ]] || exit 16
print -r -- 'PASS: theme, plugins, compaudit and TUN startup'
ZSH

env -i HOME="$sandbox/root home" PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
  TZ=Asia/Singapore TERM=xterm-256color HTTP_PROXY=http://invalid:1 ALL_PROXY=socks5://invalid:2 \
  zsh -dic "source \"$sandbox/check.zsh\"" > "$sandbox/shell.out" 2> "$sandbox/shell.err" || {
    printf "Root shell failed (%s)\n" "$?"; cat "$sandbox/shell.err"; exit 1;
  }
[[ ! -s "$sandbox/shell.err" ]] || { cat "$sandbox/shell.err"; exit 1; }
cat "$sandbox/shell.out"

# Test a non-root user without package-manager privileges, reusing real checkouts.
useradd -M -d "$sandbox/user home" -s /bin/bash dotfiles-smoke
install -d -m 700 "$sandbox/user home"
cp -R "$sandbox/root home/.oh-my-zsh" "$sandbox/user home/.oh-my-zsh"
chown -R dotfiles-smoke:dotfiles-smoke "$sandbox/user home"
# The shared SSH target is deliberately not chowned or chmodded by setup.
ln -s "$sandbox/shared-ssh" "$sandbox/user home/.ssh"
runuser -u dotfiles-smoke -- env -i HOME="$sandbox/user home" \
  PATH=/usr/local/bin:/usr/bin:/bin TZ=Asia/Singapore TERM=xterm-256color \
  bash "$repo/install.sh" --skip-packages --proxy-mode tun > "$sandbox/user-install.log" 2>&1 || {
    tail -60 "$sandbox/user-install.log"; exit 1;
  }
runuser -u dotfiles-smoke -- env -i HOME="$sandbox/user home" PATH=/usr/local/bin:/usr/bin:/bin \
  TZ=Asia/Singapore TERM=xterm-256color \
  zsh -dic "source \"$sandbox/check.zsh\"" > "$sandbox/user-shell.out" 2> "$sandbox/user-shell.err" || {
    cat "$sandbox/user-shell.err"; exit 1;
  }
[[ ! -s "$sandbox/user-shell.err" ]] || { cat "$sandbox/user-shell.err"; exit 1; }
cat "$sandbox/user-shell.out"
[[ "$(cat "$sandbox/shared-ssh/config")" == 'Host preserved' ]]
printf 'PASS: root and unprivileged installs, repeat, backups, shared SSH preserved; architecture %s, fzf %s\n' \
  "$(dpkg --print-architecture)" "$(fzf --version)"
