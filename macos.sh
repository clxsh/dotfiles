#!/bin/bash
# Compatible with the Bash 3.2 shipped by macOS.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
WORK_DIR=""
CONFIG_TEMP=""
CHECKOUT_TEMP=""
BACKUP_DIR=""
BACKUP_PATH=""
BREW_BIN=""

log() { printf '%s\n' "$*"; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

cleanup() {
  # Only remove temporary paths created by this run.
  if [[ -n "$CONFIG_TEMP" ]]; then rm -f -- "$CONFIG_TEMP"; fi
  if [[ -n "$CHECKOUT_TEMP" ]]; then rm -rf -- "$CHECKOUT_TEMP"; fi
  if [[ -n "$WORK_DIR" ]]; then rm -rf -- "$WORK_DIR"; fi
}

on_error() {
  printf 'Setup failed at line %s (exit %s). Fix the error and rerun.\n' "$2" "$1" >&2
  exit "$1"
}

backup_destination() {
  local target="$1" name
  if [[ -z "$BACKUP_DIR" ]]; then
    mkdir -p "$HOME/.dotfiles-backups"
    BACKUP_DIR=$(mktemp -d "$HOME/.dotfiles-backups/macos-$(date +%Y%m%d-%H%M%S).XXXXXX")
    log "Backups: $BACKUP_DIR"
  fi
  name=$(basename -- "$target")
  BACKUP_PATH="$BACKUP_DIR/$name"
  # Different custom installation paths can have the same basename.
  if [[ -e "$BACKUP_PATH" || -L "$BACKUP_PATH" ]]; then
    BACKUP_PATH="$(mktemp -d "$BACKUP_DIR/extra.XXXXXX")/$name"
  fi
}

install_config() {
  local source="$1" target="$2"
  [[ ! -d "$target" ]] || die "Expected a configuration file, found a directory: $target"
  if [[ -f "$target" ]] && cmp -s "$source" "$target"; then
    log "Unchanged: $target"
    return
  fi
  if [[ -e "$target" || -L "$target" ]]; then
    backup_destination "$target"
    if [[ -f "$target" ]]; then
      # Save the contents of symlinked configs; never overwrite their referents.
      cp -pL "$target" "$BACKUP_PATH"
    else
      cp -pP "$target" "$BACKUP_PATH"
    fi
    log "Backed up: $target -> $BACKUP_PATH"
  fi
  mkdir -p "$(dirname -- "$target")"
  CONFIG_TEMP=$(mktemp "${target}.tmp.XXXXXX")
  cat "$source" > "$CONFIG_TEMP"
  mv -f -- "$CONFIG_TEMP" "$target"
  CONFIG_TEMP=""
  log "Installed: $target"
}

find_homebrew() {
  local candidate
  candidate=$(type -P brew || true)
  for candidate in "$candidate" /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      BREW_BIN="$candidate"
      return 0
    fi
  done
  return 1
}

activate_homebrew() {
  local shell_env
  shell_env=$("$BREW_BIN" shellenv bash)
  eval "$shell_env"
}

ensure_homebrew() {
  if [[ -z "$BREW_BIN" ]]; then
    if ! find_homebrew; then
      log 'Installing Homebrew...'
      # A failed download must not turn into a successful empty bash command.
      /usr/bin/curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh \
        -o "$WORK_DIR/install-homebrew.sh"
      /bin/bash "$WORK_DIR/install-homebrew.sh"
      find_homebrew || die 'Homebrew installer finished, but brew could not be found.'
    fi
    activate_homebrew
  fi
}

tool_available() {
  command -v "$1" >/dev/null 2>&1 || return 1
  "$1" --version >/dev/null 2>&1 || return 1
  if [[ "$1" == zsh ]]; then
    zsh -fc 'autoload -Uz is-at-least; is-at-least 5.0.8 "$ZSH_VERSION"' || return 1
  fi
}

install_packages() {
  local package
  if find_homebrew; then activate_homebrew; fi
  for package in curl git zsh fnm jq wget fzf; do
    if tool_available "$package"; then
      log "Using existing $package: $(command -v "$package")"
      continue
    fi
    ensure_homebrew
    # Activating an existing Homebrew may have made this tool available.
    if ! tool_available "$package"; then
      log "Installing missing or unusable tool: $package"
      "$BREW_BIN" install "$package"
      hash -r
      tool_available "$package" || die "$package is still unusable after installation; check PATH."
    fi
  done
}

checkout_complete() {
  local directory="$1" marker
  shift
  for marker in "$@"; do
    [[ -s "$directory/$marker" ]] || return 1
  done
}

ensure_checkout() {
  local url="$1" target="$2" preserve_custom="$3" staged previous=""
  shift 3
  if checkout_complete "$target" "$@"; then
    log "Using existing checkout: $target"
    return
  fi

  # Stage next to the target, so publishing the checkout is a same-filesystem rename.
  mkdir -p "$(dirname -- "$target")"
  staged=$(mktemp -d "$(dirname -- "$target")/.dotfiles-checkout.XXXXXX")
  CHECKOUT_TEMP="$staged"
  git clone --depth=1 "$url" "$staged"
  checkout_complete "$staged" "$@" || die "Downloaded checkout is incomplete: $url"
  if [[ "$preserve_custom" == yes && -d "$target/custom" ]]; then
    # Overlay user plugins, themes and configuration onto the fresh framework.
    mkdir -p "$staged/custom"
    cp -pPR "$target/custom/." "$staged/custom/"
  fi

  if [[ -e "$target" || -L "$target" ]]; then
    backup_destination "$target"
    previous="$BACKUP_PATH"
    mv -- "$target" "$previous"
    log "Backed up incomplete checkout: $target -> $previous"
  fi
  if ! mv -- "$staged" "$target"; then
    if [[ -n "$previous" ]]; then mv -- "$previous" "$target"; fi
    die "Could not install checkout: $target"
  fi
  CHECKOUT_TEMP=""
}

setup_omz() {
  ensure_checkout https://github.com/ohmyzsh/ohmyzsh.git "$ZSH" yes \
    oh-my-zsh.sh lib/completion.zsh tools/check_for_upgrade.sh templates/zshrc.zsh-template
  ensure_checkout https://github.com/zsh-users/zsh-autosuggestions.git \
    "$ZSH_CUSTOM/plugins/zsh-autosuggestions" no zsh-autosuggestions.plugin.zsh zsh-autosuggestions.zsh
  ensure_checkout https://github.com/zsh-users/zsh-syntax-highlighting.git \
    "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" no zsh-syntax-highlighting.plugin.zsh zsh-syntax-highlighting.zsh
  ensure_checkout https://github.com/Aloxaf/fzf-tab.git \
    "$ZSH_CUSTOM/plugins/fzf-tab" no fzf-tab.plugin.zsh fzf-tab.zsh
  ensure_checkout https://github.com/agkozak/zsh-z.git \
    "$ZSH_CUSTOM/plugins/zsh-z" no zsh-z.plugin.zsh
  ensure_checkout https://github.com/romkatv/powerlevel10k.git \
    "$ZSH_CUSTOM/themes/powerlevel10k" no powerlevel10k.zsh-theme internal/p10k.zsh
}

configure_shell() {
  local profile="$ZSH_CONFIG_DIR/.zprofile" brew_line
  {
    printf '# Generated by dotfiles/macos.sh; keep this repository at the following path.\n'
    printf 'export DOTFILES_DIR=%q\n' "$SCRIPT_DIR"
    printf 'export ZSH=%q\n' "$ZSH"
    printf 'export ZSH_CUSTOM=%q\n' "$ZSH_CUSTOM"
    # Interactive, non-login shells do not read .zprofile.
    if [[ -n "$BREW_BIN" ]]; then
      printf 'eval "$(%q shellenv zsh)"\n' "$BREW_BIN"
    fi
    cat "$SCRIPT_DIR/zshrc/macos.zshrc"
  } > "$WORK_DIR/zshrc"
  zsh -n "$WORK_DIR/zshrc"

  if [[ -n "$BREW_BIN" ]]; then
    brew_line=$(printf 'eval "$(%q shellenv zsh)"' "$BREW_BIN")
    : > "$WORK_DIR/zprofile"
    if [[ -f "$profile" ]]; then cat "$profile" > "$WORK_DIR/zprofile"; fi
    if ! grep -Fxq "$brew_line" "$WORK_DIR/zprofile"; then
      printf '\n# Homebrew (managed by dotfiles/macos.sh)\n%s\n' "$brew_line" >> "$WORK_DIR/zprofile"
    fi
    zsh -n "$WORK_DIR/zprofile"
    install_config "$WORK_DIR/zprofile" "$profile"
  fi
  install_config "$WORK_DIR/zshrc" "$ZSH_CONFIG_DIR/.zshrc"
  install_config "$SCRIPT_DIR/p10k/p10k.zsh" "$HOME/.p10k.zsh"
  install_config "$SCRIPT_DIR/vim/vimrc" "$HOME/.vimrc"
  install_config "$SCRIPT_DIR/inputrc/inputrc" "$HOME/.inputrc"
  mkdir -p "$HOME/.vim/undo" "$HOME/.vim/swap" "$HOME/.vim/backup"

  cat > "$WORK_DIR/DefaultKeyBinding.dict" <<'KEYBINDINGS'
{
  "\UF729" = moveToBeginningOfLine:;
  "\UF72B" = moveToEndOfLine:;
  "$\UF729" = moveToBeginningOfLineAndModifySelection:;
  "$\UF72B" = moveToEndOfLineAndModifySelection:;
}
KEYBINDINGS
  install_config "$WORK_DIR/DefaultKeyBinding.dict" "$HOME/Library/KeyBindings/DefaultKeyBinding.dict"
}

main() {
  set -Eeuo pipefail
  trap 'on_error "$?" "$LINENO"' ERR
  trap cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  [[ "$OSTYPE" == darwin* ]] || die 'This script requires macOS.'
  [[ "$HOME" == /* && "$HOME" != / && -d "$HOME" ]] || die 'HOME must be an existing user directory.'
  export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
  export ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"
  ZSH_CONFIG_DIR="${ZDOTDIR:-$HOME}"
  local path
  for path in "$ZSH" "$ZSH_CUSTOM"; do
    [[ "$path" == /* && "$path" != / && "$path" != "$HOME" ]] || die "Unsafe installation directory: $path"
  done
  [[ "$ZSH_CONFIG_DIR" == /* && "$ZSH_CONFIG_DIR" != / ]] || die 'ZDOTDIR must be an absolute user directory.'
  for path in zshrc/macos.zshrc p10k/p10k.zsh vim/vimrc inputrc/inputrc aliases.sh functions.sh; do
    [[ -r "$SCRIPT_DIR/$path" ]] || die "Missing repository file: $SCRIPT_DIR/$path"
  done
  for path in "$ZSH_CONFIG_DIR/.zprofile" "$ZSH_CONFIG_DIR/.zshrc" "$HOME/.p10k.zsh" \
    "$HOME/.vimrc" "$HOME/.inputrc" "$HOME/Library/KeyBindings/DefaultKeyBinding.dict"; do
    [[ ! -d "$path" ]] || die "Expected a configuration file, found a directory: $path"
  done
  WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-macos.XXXXXX")
  log "Setting up macOS from $SCRIPT_DIR"
  install_packages
  setup_omz
  configure_shell
  log 'Environment setup finished. Open a new terminal to load the configuration.'
  if [[ -n "$BACKUP_DIR" ]]; then log "Previous files are saved in: $BACKUP_DIR"; fi
  if [[ "${SHELL:-}" != */zsh ]]; then
    log "Optional: to use zsh as your login shell, run chsh -s $(command -v zsh) (the path must be listed in /etc/shells)."
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
