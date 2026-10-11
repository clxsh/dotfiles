# Create a directory and cd into it
mcd() {
    mkdir "${1}" && cd "${1}"
}

# proxy git
proxy_git() {
    proxyip=$(ip route | grep default | awk '{print $3}')     # work for wsl and vmware NAT mode
    proxyip=${proxyip%?}"1"                                   # replace the last char to '1' for vmware 
    proxyaddr="socks5://${proxyip}:7890"
    git config --global https.proxy ${proxyaddr}
    git config --global http.proxy ${proxyaddr}
    if ! grep -qF "Host github.com" ~/.ssh/config; then
        echo "Host github.com" >> ~/.ssh/config
        echo "    User git" >> ~/.ssh/config
        echo "    ProxyCommand nc -X 5 -x ${proxyip}:7890 %h %p" >> ~/.ssh/config
    else
        lino=$(($(awk '/Host github.com/{print NR}' ~/.ssh/config)+2))
        sed -i "${lino}c\    ProxyCommand nc -X 5 -x ${proxyip}:7890 %h %p" ~/.ssh/config
    fi
}

porth() {
    orthrus-cli demand ${1} -p -t 24
}

orth() {
    orthrus-cli demand ${1} -t 24
}

boebe() {
    export CONSUL_HTTP_HOST=2605:340:cd50:f0c:e75f:1ad9:1297:f7f7
    export CONSUL_HTTP_PORT=2280
    export BYTEDOG_TCC_PSM=data.system.ste_bytedog
    export RUNTIME_IDC_NAME=boe
    export BYTED_HOST_IPV6=::1
    export MY_HOST_IPV6=::1
}

cproxy() {
    export http_proxy=http://127.0.0.1:7897
    export https_proxy=http://127.0.0.1:7897
    export all_proxy=socks5://127.0.0.1:7898
    
    export HTTP_PROXY=$http_proxy
    export HTTPS_PROXY=$https_proxy
    export ALL_PROXY=$all_proxy
    
    export no_proxy=localhost,127.0.0.1,::1,.local,.byted.org,.bytedance.com,.bytedance.net,.feishu.cn,.feishu.com
    export NO_PROXY=$no_proxy
    export TZ="America/Los_Angeles"
    export LANG="en_US.UTF-8"
    export LC_ALL="en_US.UTF-8"
    export LANGUAGE="en_US"
}
