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