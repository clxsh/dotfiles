# Enable Powerlevel10k instant prompt near the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
export ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"
export EDITOR=vim
# Installers set DOTFILES_DIR; direct sourcing/symlinking also resolves this checkout.
dotpath="${DOTFILES_DIR:-${${(%):-%x}:A:h:h}}"

[[ ! -d "$HOME/.local/bin" ]] || path=("$HOME/.local/bin" $path)
[[ ! -d "$HOME/bin" ]] || path=("$HOME/bin" $path)
typeset -U path

DISABLE_MAGIC_FUNCTIONS="true"
COMPLETION_WAITING_DOTS="true"
DISABLE_UNTRACKED_FILES_DIRTY="true"
HISTFILE="${ZDOTDIR:-$HOME}/.histfile"
HIST_STAMPS="yyyy-mm-dd"
zstyle ':omz:update' mode disabled

# Missing optional plugins should not produce warnings at every shell startup.
plugins=()
for plugin in git fzf-tab zsh-autosuggestions zsh-syntax-highlighting zsh-z; do
  if [[ "$plugin" == fzf-tab ]] && ! command -v fzf >/dev/null 2>&1; then
    continue
  fi
  if [[ -r "$ZSH_CUSTOM/plugins/$plugin/$plugin.plugin.zsh" ||
        -r "$ZSH/plugins/$plugin/$plugin.plugin.zsh" ]]; then
    plugins+=("$plugin")
  fi
done
unset plugin
ZSH_THEME=""
if [[ -r "$ZSH_CUSTOM/themes/powerlevel10k/powerlevel10k.zsh-theme" ||
      -r "$ZSH/themes/powerlevel10k/powerlevel10k.zsh-theme" ]]; then
  ZSH_THEME="powerlevel10k/powerlevel10k"
fi
[[ -r "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"
[[ -r "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"

[[ -r "${dotpath}/aliases.sh" ]] && source "${dotpath}/aliases.sh"
[[ -r "${dotpath}/functions.sh" ]] && source "${dotpath}/functions.sh"
# Linux defaults to keeping the inherited environment, including when calling cproxy.
export DOTFILES_PROXY_MODE="${DOTFILES_PROXY_MODE:-inherit}"
if (( $+functions[cproxy] )); then
  case "$DOTFILES_PROXY_MODE" in
    tun|off|manual) cproxy "$DOTFILES_PROXY_MODE" ;;
  esac
fi

bindkey -v
if (( $+widgets[autosuggest-execute] )); then
  bindkey '^j' autosuggest-execute
fi
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

function clear-scrollback {
  clear && printf '\e[3J'
  zle && zle .reset-prompt && zle -R
}
zle -N clear-scrollback
bindkey '^L' clear-scrollback
