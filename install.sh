#!/bin/bash

EnvVersion="Ubuntu"

start () {
    clear
    #
    proxyip=$(ip route | grep default | awk '{print $3}')     # work for wsl2 and vmware NAT mode
    proxyip="${proxyip%?}1"                                   # replace the last char to '1' for vmware
    #
    # proxyip="localhost"                                       # for wsl1
    export ALL_PROXY="http://${proxyip}:7890"
    export all_proxy="http://${proxyip}:7890"
    echo "Set proxy: ${ALL_PROXY}"
    check_ip
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
    sudo apt-get install -y ruby
    sudo apt-get install -y build-essential libssl-dev libffi-dev
    sudo apt-get install -y zsh curl wget git tree unzip tmux net-tools
    sudo apt-get install -y screenfetch autojump global htop feh
    sudo apt-get install -y shellcheck ripgrep fd-find
    # sudo apt-get install -y qemu-user gdb gdb-multiarch

    sudo ln -s /usr/bin/fdfind /usr/bin/fd
    python3 -m pip install -i https://pypi.tuna.tsinghua.edu.cn/simple pip -U
    python3 -m pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
    sudo python3 -m pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
    gem sources --add https://mirrors.tuna.tsinghua.edu.cn/rubygems/ --remove https://rubygems.org
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
    echo "-----------------------------------------------------------"

    # zsh-autosuggestions
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    # zsh-syntax-highlighting
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
    # autojump
    git clone git://github.com/wting/autojump.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/autojump
    cd ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/autojump
    ./install.py
    # powerlevel10k
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
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

mkdir_for_vim() {
    mkdir -p $HOME/.vim/undo
    mkdir -p $HOME/.vim/swap
    mkdir -p $HOME/.vim/backup
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
setup_omz
# install_sec_tools
mkdir_for_vim
finish