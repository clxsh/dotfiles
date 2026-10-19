# dotfiles

## Debian / Ubuntu

先将完整仓库放在准备长期保留的位置，再以需要配置 shell 的用户运行。命令不依赖当前目录；不要用 `sudo ./install.sh` 给普通用户安装。

```sh
git clone https://github.com/clxsh/dotfiles.git ~/src/dotfiles
cd ~/src/dotfiles
# 普通用户且需要安装系统包时，先取得 sudo 凭证；安装器自身不交互询问密码。
sudo -v
./install.sh
# 也可以直接运行 ./debian.sh
```

默认只补齐 Git、zsh（至少 5.0.8）、curl、fzf 和 CA 证书，然后安装 Oh My Zsh、Powerlevel10k、fzf-tab、zsh-autosuggestions、zsh-syntax-highlighting、zsh-z。fzf 由 apt 安装本机架构的包，支持 Ubuntu/Debian 的 arm64 与 amd64，不下载写死架构的 release 二进制。已有可用工具和完整插件会复用；不执行系统升级，也不自动切换登录 shell。

```sh
./debian.sh --skip-packages                  # 依赖已齐全；不使用 apt 或 sudo
./debian.sh --with-dev                       # 编译工具、Python venv/pipx、vim、tmux、jq、rg、fd
./debian.sh --with-security                  # 仅显式安装 gdb、gdb-multiarch、qemu-user
./debian.sh --skip-packages --proxy-mode tun  # TUN 已负责路由的环境
./configure.sh                              # 与平台安装器共用配置流程，不安装包或下载插件
./configure.sh --proxy-mode tun             # Linux：只更新配置并保存代理模式
```

root 可直接运行，无需 sudo；安装目标始终是当前进程的 `HOME`。普通用户只有缺包时才需要 `sudo -n`；缺少权限、下载失败或工具仍不可用时会报错停止。`--skip-packages` 不会绕过缺失依赖检查。请确保发行版 apt 源提供所需包（Ubuntu 的 fzf 位于 universe）。

Python 项目请使用 `python3 -m venv .venv`，独立 Python 命令行工具可用 `pipx`。安装器不会升级系统 pip、修改 pip 源或使用 `--break-system-packages`；pwntools、pwndbg、LibcSearcher 等专业工具按各自文档单独安装。

Debian 的 `fdfind` 仅在需要时链接为 `~/.local/bin/fd`，不会改 `/usr/bin` 或覆盖已有 `fd`。

## macOS

```sh
./macos.sh
# ./install.sh 在 macOS 上也会转到这个入口
```

复用可用的 curl、Git、zsh、fnm、jq、wget 和 fzf，通过 Homebrew 安装缺失工具，不主动批量升级软件。不自动安装 Node.js 版本或切换登录 shell。macOS 和 Linux 都在 Oh My Zsh 初始化后加载一次可读的 `~/.p10k.zsh`。

## 配置位置、重复执行和备份

所有入口按脚本所在仓库定位源文件；不重新 clone dotfiles，不删除 `.git`，不覆盖另一份 `~/.dotfiles`。生成的 `.zshrc` 记录当前仓库路径 `DOTFILES_DIR`，aliases 和 functions 继续从该路径读取，移动仓库后需重新运行安装器或 `configure.sh`。

支持 `ZDOTDIR`、`ZSH`、`ZSH_CUSTOM` 自定义绝对路径（包括空格）。框架路径不能包含独立的 `.` / `..` 分量，也不能指向 HOME、当前仓库或它们的祖先；配置目标若是目录、FIFO 等特殊文件，会在安装前拒绝。Powerlevel10k 配置仍放在 `$HOME/.p10k.zsh`。Linux 直接 source 或软链接 `zshrc/debian.zshrc` 时也能定位仓库，旧的 `zshrc/zshrc` 只作为兼容入口。

```sh
ZDOTDIR="$HOME/shell config" ZSH="$HOME/shell framework" \
  ZSH_CUSTOM="$HOME/shell plugins" ./debian.sh --skip-packages
```

配置内容不变时跳过。需要替换的原文件会备份到 `~/.dotfiles-backups/debian-时间戳.随机后缀/` 或 `macos-…/`，然后以临时文件原子替换；不会自动合并手工修改。已有软链接会备份其内容并替换链接本身，不修改链接目标；失效软链接会保留链接备份。`configure.sh` 等价于 `./install.sh --configure-only`，保留平台配置步骤（包括 macOS 的 Homebrew 初始化和键盘配置）；不会删除备份。

不完整插件会先下载到暂存目录，校验成功后才备份、替换旧目录；框架的 custom 内容会保留，旧 Git 历史也留在备份中。已完整的框架和插件不更新、不重置。安装器以 `umask 022` 创建目录，并仅移除新暂存副本的组/其他用户写权限；不递归改 HOME 或共享 `.ssh`。已有目录本身的权限问题仍需按 `compaudit` 输出单独处理，不通过禁用安全检查隐藏问题。

恢复时从安装日志给出的备份目录取回对应文件/目录即可。备份不会被自动清理。

## 代理

开 shell 不再猜测网关或调用 `proxy_git` 改写 Git/SSH。`cproxy` 和兼容名 `proxy_git` 只调整当前 shell 的代理环境变量，不修改时区、locale、`~/.gitconfig` 或 `~/.ssh/config`。

```sh
cproxy tun      # TUN/系统路由：清除 HTTP(S)/ALL/FTP_PROXY 的大小写环境变量
cproxy off      # 同样清除代理变量
cproxy manual   # 显式启用代理
cproxy inherit # 保留当前环境变量，后续调用也不强制覆盖
```

`cproxy` 无参数时遵循 `DOTFILES_PROXY_MODE`。Linux 配置默认设为 inherit；Mac 未设置模式时保留已有用法，使用 HTTP `127.0.0.1:7897`、SOCKS `127.0.0.1:7898`。端点和绕过列表可通过 `DOTFILES_HTTP_PROXY`、`DOTFILES_HTTPS_PROXY`、`DOTFILES_ALL_PROXY`、`DOTFILES_NO_PROXY` 自定义。只设置 HTTP 端点时，HTTPS 和 ALL_PROXY 默认使用该端点；显式空值可关闭对应设置，已有 NO_PROXY 会保留。`proxy_git` 不再管理 SSH 代理；Git 本身已有的持久代理配置也不会被自动清除。

Linux 安装器的 `--proxy-mode` 会写入生成的 `.zshrc`，后续不带该参数重新安装或仅配置时保留已选模式；显式参数或环境变量可覆盖它。模式同样用于本次下载和 apt，sudo 仅保留所需代理变量。TUN/off 在启动时清除继承的代理变量；manual 明确启用配置的端点；默认 inherit 保留环境。`c` 别名会先调用 `cproxy` 再运行 Claude；TUN 环境请明确选择 tun，以清除可能继承的旧代理变量。

```sh
# TUN 环境推荐用安装参数固定模式：
./debian.sh --proxy-mode tun

# 端点不会写入生成配置；要跨终端保留，请把下面的 export 放入自己的 ~/.zshenv：
export DOTFILES_PROXY_MODE=manual
export DOTFILES_HTTP_PROXY=http://proxy.example:8080
export DOTFILES_ALL_PROXY=socks5h://proxy.example:1080
cproxy
```

Mac 上需要 TUN 时可执行 `cproxy tun`，或在自己的 shell 环境设置 `DOTFILES_PROXY_MODE=tun`；默认的显式 `cproxy` 使用方式保持兼容。

## 验证

```sh
python3 -B -m unittest discover -s tests -v
```

离线测试使用临时 HOME、模拟包管理器与 Git，不安装软件、不修改真实用户配置。Linux/代理测试需要本机有 zsh；macOS 回归测试仅在 macOS 执行。

真实 Linux 验证必须使用全新、可丢弃的容器，仅只读挂载仓库，不挂载个人 HOME/SSH、Docker socket 或其他运行服务的数据：

```sh
docker run --rm -e DOTFILES_TEST_CONTAINER=1 \
  -v "$PWD:/source:ro" --entrypoint /bin/bash \
  ubuntu:26.04 /source/tests/linux_smoke.sh
```

集成测试会在该容器内实际安装包、下载插件，验证 root/普通用户、重复安装、备份、主题/插件、`compaudit` 和 TUN 启动；需要 apt/GitHub 网络访问，失败不会影响宿主机配置。

使用 [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh) 和 [Powerlevel10k](https://github.com/romkatv/powerlevel10k)。

参考：[anishathalye/dotfiles](https://github.com/anishathalye/dotfiles)、[SukkaW/dotfiles](https://github.com/SukkaW/dotfiles)、[lengthmin/dotfiles](https://github.com/lengthmin/dotfiles)。
