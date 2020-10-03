#!/bin/bash

dotfiles_array=(inputrc vimrc zshrc p10k.zsh)

# create symbolic link
create_link() {
    workdir=$(pwd)
    
    for i in ${!dotfiles_array[@]}; do
        echo "${HOME}/.${dotfiles_array[$i]}"
        if [ -f ${HOME}/.${dotfiles_array[$i]} ]; then
            echo "File .${dotfiles_array[$i]} exits, it will be backup with \".bak\" suffix"
            mv ${HOME}/.${dotfiles_array[$i]} ${HOME}/.${dotfiles_array[$i]}.bak
        fi
        ln -s ${workdir}/${dotfiles_array[$i]} ${HOME}/.${dotfiles_array[$i]}
    done
}

# remove backup files
remove_bak() {
    for i in ${!dotfiles_array[@]}; do
        if [ -f ${HOME}/.${dotfiles_array[$i]}.bak ]; then
            rm ${HOME}/.${dotfiles_array[$i]}.bak
            echo "${HOME}/.${dotfiles_array[$i]}.bak removed"
        fi
    done
    echo "Finished"
}

if [ $# -eq 0 ]; then
    create_link
elif [ $1 = "rmbk" ]; then
    remove_bak
else
    echo "usage: $0 [rmbk]"
fi