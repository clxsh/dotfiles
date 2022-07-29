#!/bin/bash

if [[ "$OSTYPE" != "darwin"* ]]; then
  echo "No macOS detected!"
  exit 1
fi

start() {
  clear

  echo    "  YOU ARE SETTING UP macOS Environment"
  echo ""
  echo -n "* The setup will begin in 5 seconds... "

  sleep 5

  echo -n "Times up! Here we start!"
  echo ""

  cd $HOME
}

# xcode command tool will be installed during homebrew installation
install_homebrew() {
  echo "==========================================================="
  echo "                     Install Homebrew                      "
  echo "-----------------------------------------------------------"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
}

install_packages() {
  # Only install required packages for setting up enviroments
  # Later we will call brew bundle
  __pkg_to_be_installed=(
    curl
    fnm
    git
    jq
    wget
    zsh
  )

  echo "==========================================================="
  echo "* Install following packages:"
  echo ""

  for __pkg in ${__pkg_to_be_installed[@]}; do
    echo "  - ${__pkg}"
  done

  echo "-----------------------------------------------------------"

  brew update

  for __pkg in ${__pkg_to_be_installed[@]}; do
    brew install ${__pkg} || true
  done
}

clone_repo() {
  echo "-----------------------------------------------------------"
  echo "* Cloning clxsh/dotfiles Repo from GitHub.com"
  echo "-----------------------------------------------------------"

  git clone https://github.com/clxsh/dotfiles.git .dotfiles

  cd ./.dotfiles
  rm -rf .git
}

setup_omz() {
  echo "==========================================================="
  echo "                      Shells Enviroment"
  echo "-----------------------------------------------------------"
  echo "* Installing Oh-My-Zsh..."
  echo "-----------------------------------------------------------"

  curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh | bash

  echo "-----------------------------------------------------------"
  echo "* Installing ZSH Custom Plugins & Themes:"
  echo ""
  echo "  - zsh-autosuggestions"
  echo "  - zsh-syntax-highlighting"
  echo "  - fzf-tab"
  echo "  - zsh-z"
  echo "  - powerlevel10k zsh theme"
  echo "-----------------------------------------------------------"

  git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
  git clone https://github.com/Aloxaf/fzf-tab ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fzf-tab
  git clone https://github.com/agkozak/zsh-z ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-z

  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
}

zshrc() {
  echo "==========================================================="
  echo "                  Import env zshrc                         "
  echo "-----------------------------------------------------------"

  cat $HOME/.dotfiles/zshrc/macos.zshrc > $HOME/.zshrc
  cat $HOME/.dotfiles/p10k/p10k.zsh > $HOME/.p10k.zsh
}

vimrc() {
  echo "==========================================================="
  echo "                  Import env vimrc                         "
  echo "-----------------------------------------------------------"

  cat $HOME/.dotfiles/vim/vimrc > $HOME/.vimrc
}

mkdir_for_vim() {
  mkdir -p $HOME/.vim/undo
  mkdir -p $HOME/.vim/swap
  mkdir -p $HOME/.vim/backup
}

p10k() {
  echo "==========================================================="
  echo "                  Import env p10k                         "
  echo "-----------------------------------------------------------"

  cat $HOME/.dotfiles/p10k/p10k.zsh > $HOME/.p10k.zsh
}

inputrc() {
  echo "==========================================================="
  echo "                  Import env inputrc                       "
  echo "-----------------------------------------------------------"

  cat $HOME/.dotfiles/inputrc/inputrc > $HOME/.inputrc 
}

fix_home_end_keybinding() {
  mkdir -p $HOME/Library/KeyBindings/
  echo "{
    \"\UF729\"  = moveToBeginningOfLine:; // home
    \"\UF72B\"  = moveToEndOfLine:; // end
    \"$\UF729\" = moveToBeginningOfLineAndModifySelection:; // shift-home
    \"$\UF72B\" = moveToEndOfLineAndModifySelection:; // shift-end
  }" > $HOME/Library/KeyBindings/DefaultKeyBinding.dict
}

finish() {
  echo "==========================================================="
  echo -n "* Clean up..."

  cd $HOME
  rm -rf $HOME/dotfiles

  echo "Done!"
  echo ""
  echo "> Enviroment Setup finished!"
  echo "> Do not forget run those things:"
  echo ""
  echo "- chsh -s /usr/bin/zsh"
  echo "- git-config"
  echo "==========================================================="

  cd $HOME
}

start
install_homebrew
install_packages
clone_repo
setup_omz
zshrc
vimrc
mkdir_for_vim
p10k
inputrc
fix_home_end_keybinding
finish