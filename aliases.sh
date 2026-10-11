# Use colors in coreutils utilities output
alias ls='ls --color=auto'
alias grep='grep --color'

# ls aliases
alias ll='ls -lh'
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
alias jssh='ssh -K jump.byted.org -tt ssh'

alias c='cproxy;claude'
# alias kc="ANTHROPIC_BASE_URL=https://ark-cn-beijing.bytedance.net/api/compatible ANTHROPIC_AUTH_TOKEN=REMOVED_SECRET ANTHROPIC_MODEL=ep-20260206102824-c7xmf claude"
alias kc='ANTHROPIC_BASE_URL=https://api.kimi.com/coding/ ANTHROPIC_API_KEY=REMOVED_SECRET ANTHROPIC_MODEL="k3[1m]" ANTHROPIC_DEFAULT_FABLE_MODEL=k3[1m] ANTHROPIC_DEFAULT_OPUS_MODEL=k3[1m] ANTHROPIC_DEFAULT_SONNET_MODEL=k3[1m] ANTHROPIC_DEFAULT_HAIKU_MODEL=k3[1m] CLAUDE_CODE_SUBAGENT_MODEL=k3[1m] CLAUDE_CODE_AUTO_COMPACT_WINDOW="1048576" ENABLE_TOOL_SEARCH=false claude'

alias zc="ANTHROPIC_BASE_URL=https://open.bigmodel.cn/api/anthropic API_TIMEOUT_MS=3000000 CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1 ANTHROPIC_DEFAULT_OPUS_MODEL=GLM-5-Turbo ANTHROPIC_DEFAULT_SONNET_MODEL=GLM-5-Turbo ANTHROPIC_DEFAULT_HAIKU_MODEL=GLM-5-Turbo ANTHROPIC_AUTH_TOKEN=REMOVED_SECRET claude"
