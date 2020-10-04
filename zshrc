export ZSH="/home/liu/.oh-my-zsh"
export EDITOR=vim

ZSH_THEME="powerlevel10k/powerlevel10k"
[[ ! -f $HOME/.p10k.zsh ]] || source $HOME/.p10k.zsh

DISABLE_MAGIC_FUNCTIONS="true"
COMPLETION_WAITING_DOTS="true"
DISABLE_UNTRACKED_FILES_DIRTY="true"
HISTFILE=~/.histfile
HIST_STAMPS="yyyy-mm-dd"
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    autojump
    )
source $ZSH/oh-my-zsh.sh

# Aliases and functions
source ~/src/dotfiles/aliases.sh
source ~/src/dotfiles/functions.sh

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
