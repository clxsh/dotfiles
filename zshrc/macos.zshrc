DISABLE_AUTO_UPDATE="true"
DISABLE_MAGIC_FUNCTIONS="true"
DISABLE_COMPFIX="true"
DISABLE_LS_COLORS=true

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
export EDITOR=vim
dotpath="${DOTFILES_DIR:-${HOME}/mysrc/dotfiles}"

ZSH_THEME="powerlevel10k/powerlevel10k"

DISABLE_MAGIC_FUNCTIONS="true"
COMPLETION_WAITING_DOTS="true"
DISABLE_UNTRACKED_FILES_DIRTY="true"
HISTFILE=~/.histfile
HIST_STAMPS="yyyy-mm-dd"
plugins=(
    git
    fzf-tab
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-z
    )
source "$ZSH/oh-my-zsh.sh"
[[ -r "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"

# Aliases and functions
source "${dotpath}/aliases.sh"
source "${dotpath}/functions.sh"
# Use macOS's built-in ls; GNU --color is not supported by BSD ls.
alias ls='ls -G'

# Vi mode
bindkey -v

# Zsh syntax highlighting
# https://github.com/zsh-users/zsh-syntax-highlighting
# source ~/src/dotfiles/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# user local bin
if [ -d "$HOME/.local/bin" ]; then
    PATH="$HOME/.local/bin:$PATH"
fi
if [ -d "$HOME/bin" ] ; then
    export PATH="$HOME/bin:$PATH"
fi

# compilers cs213
if [ -d /usr/class/cs143/cool/bin ]; then
    PATH=/usr/class/cs143/cool/bin:$PATH
fi

# zsh-autosuggestions bindkey
bindkey '^j' autosuggest-execute

# Node.js (fnm)
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd --shell zsh)"
fi
# NODE_PATH=/Users/liuchao/.local/share/fnm/node-versions/v22.17.1/installation/bin
# if [ -d "$NODE_PATH" ]; then
#   export PATH="$NODE_PATH:$PATH"
# fi

# clear terminal scrollback
function clear-scrollback {
  clear && printf '\e[3J'
  zle && zle .reset-prompt && zle -R
}
zle -N clear-scrollback
bindkey '^L' clear-scrollback

# export PATH=$PATH:/Users/liuchao/sdk/go1.24.3/bin
export PATH=$PATH:/Users/liuchao/sdk/go1.25.8/bin
# export PATH=$PATH:/Users/liuchao/sdk/go1.23.9/bin
# export PATH=$PATH:/Users/liuchao/sdk/go1.19.13/bin/
# export PATH=$PATH:/Users/liuchao/sdk/go1.20.14/bin/

# Added by CatPaw
export PATH="/Users/liuchao/.catpawai/bin:$PATH"

# bun completions
[ -s "/Users/liuchao/.bun/_bun" ] && source "/Users/liuchao/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export PATH="/Users/liuchao/go/bin:$PATH"

# export CONSUL_HTTP_HOST=2605:340:cd50:f0c:e75f:1ad9:1297:f7f7
# export CONSUL_HTTP_PORT=2280
# export BYTEDOG_TCC_PSM=data.system.ste_bytedog
# export RUNTIME_IDC_NAME=boe
# export BYTED_HOST_IPV6=::1
# export MY_HOST_IPV6=::1

export ARK_ENDPOINT_ID="ep-20260206102824-c7xmf"

export no_proxy=localhost,127.0.0.1,::1,.local,.byted.org,.bytedance.com,.bytedance.net,.feishu.cn,.feishu.com
export NO_PROXY=$no_proxy

# kimi-code
export PATH="/Users/liuchao/.kimi-code/bin:$PATH"

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/liuchao/.lmstudio/bin"
# End of LM Studio CLI section



# Added by Antigravity CLI installer
export PATH="/Users/liuchao/.local/bin:$PATH"


# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
fpath=(~/.grok/completions/zsh $fpath)
autoload -Uz compinit && compinit -C
# <<< grok installer <<<
