# Shared, source-only installer helpers. Compatible with Bash 3.2.
WORK_DIR=""
CONFIG_TEMP=""
CHECKOUT_TEMP=""
BACKUP_DIR=""
BACKUP_PATH=""
SETUP_PLATFORM=""

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
    BACKUP_DIR=$(mktemp -d "$HOME/.dotfiles-backups/${SETUP_PLATFORM}-$(date +%Y%m%d-%H%M%S).XXXXXX")
    log "Backups: $BACKUP_DIR"
  fi
  name=$(basename -- "$target")
  BACKUP_PATH="$BACKUP_DIR/$name"
  # Different custom installation paths can have the same basename.
  if [[ -e "$BACKUP_PATH" || -L "$BACKUP_PATH" ]]; then
    BACKUP_PATH="$(mktemp -d "$BACKUP_DIR/extra.XXXXXX")/$name"
  fi
}

validate_config_target() {
  [[ ! -d "$1" ]] || die "Expected a configuration file, found a directory: $1"
  [[ ! -e "$1" || -f "$1" || -L "$1" ]] || die "Expected a regular configuration file or symlink: $1"
}

install_config() {
  local source="$1" target="$2"
  validate_config_target "$target"
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

tool_available() {
  command -v "$1" >/dev/null 2>&1 || return 1
  "$1" --version >/dev/null 2>&1 || return 1
  if [[ "$1" == zsh ]]; then
    zsh -fc 'autoload -Uz is-at-least; is-at-least 5.0.8 "$ZSH_VERSION"' || return 1
  fi
}

checkout_complete() {
  local directory="$1" marker
  shift
  for marker in "$@"; do
    [[ -f "$directory/$marker" && -s "$directory/$marker" ]] || return 1
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
  GIT_TERMINAL_PROMPT=0 git clone --depth=1 "$url" "$staged"
  checkout_complete "$staged" "$@" || die "Downloaded checkout is incomplete: $url"
  if [[ "$preserve_custom" == yes && -d "$target/custom" ]]; then
    # Overlay user plugins, themes and configuration onto the fresh framework.
    mkdir -p "$staged/custom"
    cp -pPR "$target/custom/." "$staged/custom/"
  fi

  # Only normalize the newly staged copy; never follow links into user directories.
  find "$staged" \( -type d -o -type f \) -exec chmod go-w {} +

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

prepare_setup() {
  SETUP_PLATFORM="$1"
  trap 'on_error "$?" "$LINENO"' ERR
  trap cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  umask 022
  [[ "$HOME" == /* && "$HOME" != / && -d "$HOME" ]] || die 'HOME must be an existing user directory.'
  export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
  export ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"
  ZSH_CONFIG_DIR="${ZDOTDIR:-$HOME}"
  local path resolved_target resolved_home
  resolved_home=$(cd -- "$HOME" && pwd -P)
  for path in "$ZSH" "$ZSH_CUSTOM"; do
    [[ "$path" == /* ]] || die "Installation directories must be absolute: $path"
    case "$path/" in
      */./*|*/../*) die "Installation directories must not contain . or .. components: $path" ;;
    esac
    if [[ -d "$path" ]]; then
      resolved_target=$(cd -- "$path" && pwd -P)
      if [[ "$resolved_target" == / || "$resolved_home/" == "$resolved_target/"* ||
            "$SCRIPT_DIR/" == "$resolved_target/"* ]]; then
        die "Installation directory would replace HOME or the repository: $path"
      fi
    fi
  done
  [[ "$ZSH_CONFIG_DIR" == /* && "$ZSH_CONFIG_DIR" != / ]] || die 'ZDOTDIR must be an absolute user directory.'
  for path in "zshrc/$SETUP_PLATFORM.zshrc" p10k/p10k.zsh vim/vimrc inputrc/inputrc aliases.sh functions.sh; do
    [[ -f "$SCRIPT_DIR/$path" && -r "$SCRIPT_DIR/$path" ]] || die "Missing repository file: $SCRIPT_DIR/$path"
  done
  for path in "$ZSH_CONFIG_DIR/.zshrc" "$HOME/.p10k.zsh" \
    "$HOME/.vimrc" "$HOME/.inputrc"; do
    validate_config_target "$path"
  done
  WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-$SETUP_PLATFORM.XXXXXX")
}

write_zshrc() {
  {
    printf '# Generated by dotfiles/%s.sh; keep this repository at the following path.\n' "$SETUP_PLATFORM"
    printf 'export DOTFILES_DIR=%q\n' "$SCRIPT_DIR"
    printf 'export ZSH=%q\n' "$ZSH"
    printf 'export ZSH_CUSTOM=%q\n' "$ZSH_CUSTOM"
    if [[ "$SETUP_PLATFORM" == debian && -n "${DOTFILES_PROXY_MODE:-}" ]]; then
      printf 'export DOTFILES_PROXY_MODE=%q\n' "$DOTFILES_PROXY_MODE"
    fi
    # Interactive, non-login shells do not read .zprofile.
    if [[ -n "${BREW_BIN:-}" ]]; then
      printf 'eval "$(%q shellenv zsh)"\n' "$BREW_BIN"
    fi
    cat "$SCRIPT_DIR/zshrc/$SETUP_PLATFORM.zshrc"
  } > "$WORK_DIR/zshrc"
  zsh -n "$WORK_DIR/zshrc"
}

install_user_configs() {
  install_config "$WORK_DIR/zshrc" "$ZSH_CONFIG_DIR/.zshrc"
  install_config "$SCRIPT_DIR/p10k/p10k.zsh" "$HOME/.p10k.zsh"
  install_config "$SCRIPT_DIR/vim/vimrc" "$HOME/.vimrc"
  install_config "$SCRIPT_DIR/inputrc/inputrc" "$HOME/.inputrc"
  mkdir -p "$HOME/.vim/undo" "$HOME/.vim/swap" "$HOME/.vim/backup"
}
