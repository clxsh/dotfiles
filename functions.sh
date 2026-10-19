# Create a directory and cd into it
mcd() {
    mkdir "${1}" && cd "${1}"
}

# Compatibility helper: Git HTTP(S) uses these environment variables.
# Never guess a gateway or persist changes to Git/SSH configuration.
proxy_git() {
    cproxy "$@"
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

# Explicit proxy selection. With no mode configured, preserve the Mac cproxy defaults.
cproxy() {
    local mode="${1:-${DOTFILES_PROXY_MODE:-manual}}"
    case "$mode" in
        tun|off)
            unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY ftp_proxy FTP_PROXY
            ;;
        manual|on)
            export http_proxy="${DOTFILES_HTTP_PROXY-http://127.0.0.1:7897}"
            export https_proxy="${DOTFILES_HTTPS_PROXY-$http_proxy}"
            export all_proxy="${DOTFILES_ALL_PROXY-${DOTFILES_HTTP_PROXY-socks5://127.0.0.1:7898}}"
            export HTTP_PROXY="$http_proxy" HTTPS_PROXY="$https_proxy" ALL_PROXY="$all_proxy"
            export no_proxy="${DOTFILES_NO_PROXY-${no_proxy-${NO_PROXY-localhost,127.0.0.1,::1,.local,.byted.org,.bytedance.com,.bytedance.net,.feishu.cn,.feishu.com}}}"
            export NO_PROXY="$no_proxy"
            mode=manual
            ;;
        inherit) ;;
        *) printf 'Usage: cproxy [manual|tun|off|inherit]\n' >&2; return 2 ;;
    esac
    export DOTFILES_PROXY_MODE="$mode"
}
