# dotfiles

- install.sh 安装必备软件
- configure.sh 建立dotfiles软连接
- macos.sh 配置 macOS：在完整仓库内运行 `./macos.sh`，支持重复执行。

macOS 脚本复用能正常运行的 curl、Git、zsh（至少 5.0.8）、fnm、jq、wget 和
fzf，仅通过 Homebrew 安装缺失或不可用的工具，不主动批量升级软件。
配置内容有变化时，先备份至 `~/.dotfiles-backups/macos-时间戳.随机后缀/`；
内容相同则跳过。配置软链接会备份其内容，并替换链接本身，不修改链接目标。
不完整的 Oh My Zsh 或插件目录会在下载成功后备份、修复，并保留框架的 custom 内容。
已有的完整插件不会被更新或重置，现有 `~/.dotfiles` 和 Git 历史也不会被删除。

配置中的 aliases 和 functions 直接读取运行脚本的仓库，请保留仓库目录；
移动仓库后重新运行脚本即可更新路径。脚本不会自动切换登录 shell 或安装 Node.js 版本。
可在 macOS 上执行 `python3 -m unittest discover -s tests -v` 运行离线回归测试；
测试使用临时用户目录和模拟的 brew/git，不安装软件、不修改真实用户配置。

</br>

使用[ohmyzsh](https://github.com/ohmyzsh/ohmyzsh)

插件：[zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)

主题：[powerlevel10k](https://github.com/romkatv/powerlevel10k)

![](https://raw.githubusercontent.com/clxsh/pics/master/imgwindows%20terminal.png)

</br>

Refer [anishathalye/dotfiles](https://github.com/anishathalye/dotfiles)  [SukkaW/dotfiles](https://github.com/SukkaW/dotfiles)  [lengthmin/dotfiles](https://github.com/lengthmin/dotfiles)
