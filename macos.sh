#!/bin/bash
# Compatible with the Bash 3.2 shipped by macOS.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/lib/setup.sh"
BREW_BIN=""

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

configure_shell() {
  local profile="$ZSH_CONFIG_DIR/.zprofile" brew_line
  write_zshrc

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
  install_user_configs

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
  CONFIGURE_ONLY=no
  local argument
  for argument in "$@"; do
    case "$argument" in
      --configure-only) CONFIGURE_ONLY=yes ;;
      -h|--help) log 'Usage: ./macos.sh [--configure-only]'; return ;;
      *) die "Unknown argument: $argument (see --help)" ;;
    esac
  done
  [[ "$OSTYPE" == darwin* ]] || die 'This script requires macOS.'
  prepare_setup macos
  validate_config_target "$ZSH_CONFIG_DIR/.zprofile"
  validate_config_target "$HOME/Library/KeyBindings/DefaultKeyBinding.dict"
  log "Setting up macOS from $SCRIPT_DIR"
  if [[ "$CONFIGURE_ONLY" == yes ]]; then
    tool_available zsh || die 'Install zsh first, or run ./install.sh.'
    find_homebrew || true
  else
    install_packages
    setup_omz
  fi
  configure_shell
  log 'Environment setup finished. Open a new terminal to load the configuration.'
  if [[ -n "$BACKUP_DIR" ]]; then log "Previous files are saved in: $BACKUP_DIR"; fi
  if [[ "${SHELL:-}" != */zsh ]]; then
    log "Optional: to use zsh as your login shell, run chsh -s $(command -v zsh) (the path must be listed in /etc/shells)."
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
