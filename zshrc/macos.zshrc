# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
export EDITOR=vim
dotpath="${HOME}/.dotfiles"

ZSH_THEME="powerlevel10k/powerlevel10k"
[[ ! -f $HOME/.p10k.zsh ]] || source $HOME/.p10k.zsh

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
source $ZSH/oh-my-zsh.sh

# Aliases and functions
source ${dotpath}/aliases.sh
source ${dotpath}/functions.sh

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

# nodejs relavant
# NVM_NODEJS_ORG_MIRROR=http://npm.taobao.org/mirrors/node
# export NVM_DIR="$HOME/.nvm"
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
# [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# proxy git if wsl
if uname -r | grep -qF microsoft; then
    proxy_git
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# clear terminal scrollback
function clear-scrollback {
  clear && printf '\e[3J'
  zle && zle .reset-prompt && zle -R
}
zle -N clear-scrollback
bindkey '^L' clear-scrollback
