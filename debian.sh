#!/bin/bash

EnvVersion="Debian derivative"

start() {
  clear
    
  echo    "  YOU ARE SETTING UP debian-like Environment"
  echo ""
  echo "==========================================================="
  echo ""
  echo "* The setup will begin in 5 seconds... "
  sleep 5
  echo "Times up! Here we start!"
  cd $HOME
}

install_linux_packages() {
  echo "==========================================================="
  echo "* Install following packages:"
  echo "-----------------------------------------------------------"
  
  sudo apt-get update
  sudo apt-get install -y python3 python3-dev python3-pip python3-setuptools
  # sudo apt-get install -y ruby
  sudo apt-get install -y build-essential libssl-dev libffi-dev
  sudo apt-get install -y zsh curl wget git tree unzip tmux net-tools
  sudo apt-get install -y screenfetch global htop feh
  sudo apt-get install -y shellcheck ripgrep fd-find jq
  sudo apt-get install -y qemu-user gdb gdb-multiarch
  
  sudo ln -s /usr/bin/fdfind /usr/bin/fd
  python3 -m pip install -i https://pypi.tuna.tsinghua.edu.cn/simple pip -U
  python3 -m pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
  sudo python3 -m pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
  # gem sources --add https://mirrors.tuna.tsinghua.edu.cn/rubygems/ --remove https://rubygems.org
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

  fzf_tag=$(curl https://api.github.com/repos/junegunn/fzf/releases/latest | jq -r ".tag_name")
  wget https://github.com/junegunn/fzf/releases/download/${fzf_tag}/fzf-${fzf_tag}-linux_amd64.tar.gz
  tar xf fzf-${fzf_tag}-linux_amd64.tar.gz
  sudo mv fzf /usr/loca/bin/
  rm fzf-${fzf_tag}-linux_amd64.tar.gz
}

install_sec_tools() {
  echo "-----------------------------------------------------------"
  echo "* Installing sec tools:"
  echo ""
  echo "  - pwntools"
  echo "  - pwndbg"
  echo "  - LibcSearcher"
  echo "  - one_gadget"
  echo "-----------------------------------------------------------"

  if [! -d ${HOME}/src ]; then
      mkdir ${HOME}/src
  fi
  cd ${HOME}/src

  # pwntools
  python3 -m pip install --upgrade pwntools

  # pwndbg
  git clone https://github.com/pwndbg/pwndbg
  cd pwndbg
  ./setup.sh
  cd ..

  # LibcSearcher
  git clone https://github.com/lieanu/LibcSearcher.git
  cd LibcSearcher
  sudo python3 setup.py develop
  rm libc-database -rf
  git clone https://github.com/niklasb/libc-database.git
  sed -i 's|http://archive.ubuntu.com/ubuntu/pool/main/g/glibc/|https://mirrors.tuna.tsinghua.edu.cn/ubuntu/pool/main/g/glibc/|g' libc-database/get
  sed -i 's|get_all_debian ubuntu-eglibc http://archive.ubuntu.com/ubuntu/pool/main/e/eglibc/|# &|g' libc-database/get
  sed -i 's|get_all_debian ubuntu-security-eglibc http://security.ubuntu.com/ubuntu/pool/main/e/eglibc/|# &|g' libc-database/get
  sed -i 's|get_all_debian ubuntu-security-glibc http://security.ubuntu.com/ubuntu/pool/main/g/glibc/|# &|g' libc-database/get
  sed -i 's|get_all_debian ubuntu-old-eglibc http://old-releases.ubuntu.com/ubuntu/pool/main/e/eglibc/|# &|g' libc-database/get
  sed -i 's|get_all_debian ubuntu-old-glibc http://old-releases.ubuntu.com/ubuntu/pool/main/g/glibc/|# &|g' libc-database/get
  ./libc-database/get ubuntu
  cd ..

  # one_gadget
  sudo gem install one_gadget
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

# Copy from SukkaW/zsh-proxy: https://github.com/SukkaW/zsh-proxy
check_ip() {
    echo "==========================================================="
    echo "Check what your IP is"
    echo "-----------------------------------------------------------"
    echo -n "IPv4: "
    curl -s -k https://api-ipv4.ip.sb/ip
    echo "-----------------------------------------------------------"
    echo -n "IPv6: "
    curl -s -k http://api-ipv6.ip.sb/ip

    if command -v python3 >/dev/null; then
        echo ""
        echo "-----------------------------------------------------------"
        echo "Info: "
        curl -s -k https://api.ip.sb/geoip | python3 -m json.tool
        echo ""
    fi
}

finish() {
    echo "==========================================================="
    echo "> Do not forget run those things:"
    echo ""
    echo "- chsh -s /usr/bin/zsh"
    echo "==========================================================="
}

start
install_linux_packages
clone_repo
setup_omz
# install_sec_tools
zshrc
vimrc
mkdir_for_vim
p10k
inputrc
finish