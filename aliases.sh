# Use colors in coreutils utilities output
alias ls='ls --color=auto'
alias grep='grep --color'

# ls aliases
alias ll='ls -lah'
alias la='ls -A'
alias l='ls'

# Aliases to protect against overwriting
alias cp='cp -i'
alias mv='mv -i'

# cd to git root directory
alias cdgr='cd "$(git rev-parse --show-toplevel)"'

# apt relevant
alias aptupg='sudo apt upgrade -y'
alias aptup='sudo apt update && sudo apt upgrade -y'
alias apti='sudo apt install'
alias apts='sudo apt search'