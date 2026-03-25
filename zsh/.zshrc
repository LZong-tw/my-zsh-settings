# ===========================================
# 0. GLOBAL FLAGS & CLAUDE CODE INTEGRATION
# ===========================================
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# Claude Code Agent 模式下直接進入極速模式
if [[ -n "$CLAUDE_CODE_AGENT_ID" ]]; then
    PROMPT='%~ $ '
    return
fi

# ===========================================
# 1. TMUX & ITERM2 CONTROL MODE (-CC) DETECTION
# ===========================================
if [[ "$TERM" == "screen" || "$TERM" == "tmux" || -n "$TMUX" ]]; then
    export ITERMS_SHELL_INTEGRATION_SKIPPED=1
fi

# ===========================================
# 2. POWERLEVEL10K INSTANT PROMPT
# ===========================================
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
# ===========================================
# 3. CORE ZSH / OMZ SETTINGS
# ===========================================
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# 效能關鍵：停用所有權限檢查與自動更新
DISABLE_AUTO_UPDATE="true"
ZSH_DISABLE_COMPFIX="true"

# 極簡化 Plugins 列表
plugins=(z extract sudo colored-man-pages zsh-autosuggestions zsh-syntax-highlighting)

# ===========================================
# 4. THE IMMORTAL COMPLETION CACHE (ULTRA STABLE)
# ===========================================
# 1. 預先加入插件路徑到 fpath (compinit 才能抓到)
for plugin ($plugins); do
  [[ -d "$ZSH_CUSTOM/plugins/$plugin" ]] && fpath=("$ZSH_CUSTOM/plugins/$plugin" $fpath)
  [[ -d "$ZSH/plugins/$plugin" ]] && fpath=("$ZSH/plugins/$plugin" $fpath)
done

# 2. 手動計算 Dump 路徑
SHORT_HOST="${HOST/.*/}"
export ZSH_COMPDUMP="${ZDOTDIR:-$HOME}/.zcompdump-${SHORT_HOST}-${ZSH_VERSION}"

# 3. 極速初始化 (不論 OMZ 怎麼想，我們強制用快取)
autoload -Uz compinit
if [[ -n "$ZSH_COMPDUMP"(#qN.m-1) ]]; then
  compinit -C -d "$ZSH_COMPDUMP"
else
  compinit -i -d "$ZSH_COMPDUMP"
fi

# 4. 關鍵：鎖定 compinit，禁止 OMZ 再次執行或清理它
zcompdump_refresh=0
compinit() { : }

# 載入 Oh My Zsh
source $ZSH/oh-my-zsh.sh
alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gcam='git commit -a -m'
alias gcmsg='git commit -m'
alias gco='git checkout'
alias gd='git diff'
alias gl='git pull'
alias gp='git push'
alias gst='git status'

# Docker & Compose
alias d='docker'
alias dco='docker compose'
alias dcb='docker compose build'
alias ddn='docker compose down'
alias dex='docker exec -it'
alias dlogs='docker compose logs -f'
alias dps='docker compose ps'
alias dup='docker compose up -d'

# Composer & Laravel
alias c='composer'
alias ci='composer install'
alias cu='composer update'
alias cda='composer dump-autoload -o'
alias art='php artisan'
alias pa='php artisan'
alias mfs='php artisan migrate:fresh --seed'

# AWS & Kubectl (Lazy Load Completions)
kubectl() {
  unfunction kubectl
  source <(command kubectl completion zsh)
  command kubectl "$@"
}
aws() {
  unfunction aws
  complete -C '/usr/local/bin/aws_zsh_completer' aws
  command aws "$@"
}

# ===========================================
# 5. MODERN TOOLS & ALIASES
# ===========================================
export PATH="$HOME/.composer/vendor/bin:$HOME/.local/bin:$HOME/.antigravity/antigravity/bin:$HOME/.bun/bin:$HOME/go/bin:$PATH"

# API & Tokens (secrets from 1Password, loaded on demand)
export ANTHROPIC_BASE_URL="https://llm-gateway.kkcompany-internal.com"
export GITLAB_API_URL="https://gitlab.kkinternal.com"
_op_secrets_loaded=0
load-secrets() {
    [[ $_op_secrets_loaded -eq 1 ]] && return
    export ANTHROPIC_AUTH_TOKEN=$(op read "op://Employee/CLI API Keys/anthropic_auth_token" --no-newline)
    export GITLAB_PERSONAL_ACCESS_TOKEN=$(op read "op://Employee/CLI API Keys/gitlab_personal_access_token" --no-newline)
    export PAGERDUTY_API_KEY=$(op read "op://Employee/CLI API Keys/pagerduty_api_key" --no-newline)
    export PAGERDUTY_USER_API_KEY=$(op read "op://Employee/CLI API Keys/pagerduty_user_api_key" --no-newline)
    _op_secrets_loaded=1
    echo "Secrets loaded from 1Password."
}
# Auto-load if op session is active (non-blocking check)
op whoami &>/dev/null && load-secrets
export AWS_REGION=ap-northeast-1
export DOCKER_HOST="unix:///var/run/docker.sock"

# Aliases
alias niceboat='ssh niceboat.kkinternal-dev.com'
alias voyager='ssh voyager.kkinternal.com'
alias myip="curl http://ipecho.net/plain; echo"
alias ports="lsof -PiTCP -sTCP:LISTEN"
alias ports_full="ss -tulanp"
alias killport='f(){ lsof -ti:$1 | xargs kill -9; }; f'

if (( $+commands[eza] )); then
  alias ls="eza --icons --git"
  alias ll="eza -l --icons --git"
  alias la="eza -la --icons --git"
fi

alias gs='git status'
alias glog='git log --oneline --graph -20'
alias dc='docker compose'
alias docker=podman
alias reload="exec zsh"

# ===========================================
# POWERFUL FUNCTIONS
# ===========================================
mysqlstat() { mysql -e "SHOW GLOBAL STATUS LIKE 'Threads%'; SHOW GLOBAL STATUS LIKE 'Queries'; SHOW GLOBAL STATUS LIKE 'Slow_queries';"; }
mysqlproc() { mysql -e "SHOW FULL PROCESSLIST;"; }
mysqlinnodb() { mysql -e "SHOW ENGINE INNODB STATUS\G"; }
mysqlexplain() { [ -z "$1" ] && { echo "Usage: mysqlexplain '<SQL query>'"; return 1; }; mysql -e "EXPLAIN ANALYZE $1"; }
laraclear() {
    php artisan cache:clear; php artisan config:clear; php artisan route:clear; php artisan view:clear; composer dump-autoload -o
    echo "All caches cleared & Autoload dumped."
}
ec2ls() { aws ec2 describe-instances --query "Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,PrivateIpAddress,Tags[?Key=='Name'].Value|[0]]" --output table; }
testconn() { [ -z "$1" ] && { echo "Usage: testconn <host> [port]"; return 1; }; local port=${2:-80}; nc -zv "$1" "$port" 2>&1; }
grepall() { grep -rn --color=auto --exclude-dir={.git,node_modules,vendor,.idea,storage,cache,bootstrap/cache} "$@" . ; }

# ===========================================
# 6. NVM LAZY LOAD
# ===========================================
export NVM_DIR="$HOME/.nvm"
_nvm_lazy_cmds=(nvm node npm npx yarn pnpm gemini codex)
_load_nvm() {
    unset -f $_nvm_lazy_cmds 2>/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
}
for _cmd in $_nvm_lazy_cmds; do
    eval "${_cmd}() { _load_nvm; ${_cmd} \"\$@\"; }"
done
unset _cmd

# ===========================================
# 7. CLAUDE CODE ROUTER
# ===========================================
cclaude() {
    if ! ccr status &>/dev/null; then
        nohup ccr start > /dev/null 2>&1 &
        disown; sleep 1
    fi
    (eval "$(ccr activate)" && claude "$@")
}

# ===========================================
# 8. BACKGROUND TASKS
# ===========================================
if [[ -z "$ITERMS_SHELL_INTEGRATION_SKIPPED" ]]; then
    [[ -e "${HOME}/.iterm2_shell_integration.zsh" ]] && source "${HOME}/.iterm2_shell_integration.zsh"
fi

zcompile_if_needed() {
  local file=$1
  [[ -f "$file" && (! -f "$file.zwc" || "$file" -nt "$file.zwc") ]] && zcompile "$file"
}
(
  zcompile_if_needed ~/.zshrc
  zcompile_if_needed ~/.p10k.zsh
) &!

# ===========================================
# 9. FINISH
# ===========================================
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
[[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh" ]] && . "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh"
[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)" || true
