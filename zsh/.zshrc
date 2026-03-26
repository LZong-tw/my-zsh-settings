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
# 3. CORE ZSH SETTINGS (no OMZ framework)
# ===========================================
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# --- History (from lib/history.zsh) ---
HISTFILE="${HISTFILE:-$HOME/.zsh_history}"
HISTSIZE=50000
SAVEHIST=10000
setopt extended_history       # 記錄時間戳
setopt hist_expire_dups_first # 滿了先刪重複
setopt hist_ignore_dups       # 連續重複不記
setopt hist_ignore_space      # 空格開頭不記（隱私指令）
setopt hist_verify            # !歷史展開後先確認再執行
setopt share_history          # 多 terminal 即時共享歷史

# --- Directories (from lib/directories.zsh) ---
setopt auto_cd auto_pushd pushd_ignore_dups pushdminus
alias ...='../..'
alias ....='../../..'
alias .....='../../../..'
alias 1='cd -1' 2='cd -2' 3='cd -3' 4='cd -4' 5='cd -5'
alias 6='cd -6' 7='cd -7' 8='cd -8' 9='cd -9'
alias md='mkdir -p'

# --- Misc (from lib/misc.zsh) ---
autoload -Uz url-quote-magic bracketed-paste-magic
zle -N self-insert url-quote-magic
zle -N bracketed-paste bracketed-paste-magic
setopt multios long_list_jobs interactivecomments
export PAGER='less'
export LESS='-R'

# --- Theme support (from lib/theme-and-appearance.zsh) ---
autoload -U colors && colors
setopt prompt_subst

# --- Key bindings (from lib/key-bindings.zsh) ---
bindkey -e
# Up/Down: prefix-aware history search (打 git 再按↑ 只搜 git 開頭)
autoload -U up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
# Home / End
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[1~' beginning-of-line
bindkey '^[[4~' end-of-line
# Ctrl+Left/Right: 跳字
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
# Delete / Ctrl+Delete
bindkey '^[[3~' delete-char
bindkey '^[[3;5~' kill-word
# Shift+Tab: 反向補全
bindkey '^[[Z' reverse-menu-complete
# Ctrl+R: 歷史搜尋
bindkey '^r' history-incremental-search-backward
# Space: 不展開歷史
bindkey ' ' magic-space
# Ctrl-X Ctrl-E: 用編輯器編輯指令
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# --- Terminal title (from lib/termsupport.zsh) ---
autoload -Uz add-zsh-hook
function _set_terminal_title_precmd { print -Pn "\e]2;%~\a"; print -Pn "\e]1;%1~\a" }
function _set_terminal_title_preexec { printf "\e]2;%s\a" "${1//\%/%%}"; printf "\e]1;%s\a" "${1[(w)1]}" }
add-zsh-hook precmd _set_terminal_title_precmd
add-zsh-hook preexec _set_terminal_title_preexec
# OSC 7: 讓 terminal 知道 CWD（新分頁開在同目錄）
function _set_terminal_cwd { printf "\e]7;file://%s%s\a" "$HOST" "${PWD// /%20}" }
add-zsh-hook precmd _set_terminal_cwd

# ===========================================
# 4. COMPLETION
# ===========================================
zmodload -i zsh/complist
WORDCHARS=''
if [[ "$OSTYPE" = darwin* ]]; then
  SHORT_HOST=$(scutil --get LocalHostName 2>/dev/null) || SHORT_HOST="${HOST/.*/}"
else
  SHORT_HOST="${HOST/.*/}"
fi
export ZSH_COMPDUMP="${ZDOTDIR:-$HOME}/.zcompdump-${SHORT_HOST}-${ZSH_VERSION}"
autoload -Uz compinit
if [[ -n "$ZSH_COMPDUMP"(#qN.m-1) ]]; then
  compinit -C -d "$ZSH_COMPDUMP"
else
  compinit -i -d "$ZSH_COMPDUMP"
fi
# Options
unsetopt menu_complete flowcontrol
setopt auto_menu complete_in_word always_to_end
# Styles
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' use-cache yes
zstyle ':completion:*' cache-path "${ZSH_COMPDUMP:h}/.zcompcache"
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#) ([0-9a-z-]#)*=01;34=0=01'

# ===========================================
# 4.5. PLUGINS (direct source, no framework)
# ===========================================
_omz="$HOME/.oh-my-zsh"
source "$_omz/custom/themes/powerlevel10k/powerlevel10k.zsh-theme"
source "$_omz/plugins/z/z.plugin.zsh"
source "$_omz/plugins/extract/extract.plugin.zsh"
source "$_omz/plugins/sudo/sudo.plugin.zsh"
source "$_omz/plugins/colored-man-pages/colored-man-pages.plugin.zsh"
source "$_omz/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
# syntax-highlighting must be last
source "$_omz/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
unset _omz
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

# Grep defaults: color + exclude common dirs
alias grep="grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox,.venv,venv,node_modules,vendor}"
alias egrep="grep -E"
alias fgrep="grep -F"

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
else
  alias ll="ls -lh"
  alias la="ls -lAh"
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

# take: mkdir+cd / git clone+cd / download+extract+cd
mkcd() { mkdir -p "$@" && cd "${@:$#}" }
takeurl() { local d=$(mktemp); curl -L "$1" > "$d"; tar xf "$d"; cd "$(tar tf "$d" | head -1)"; rm "$d" }
takezip() { local d=$(mktemp); curl -L "$1" > "$d"; unzip "$d" -d ./; cd "$(unzip -l "$d" | awk 'NR==4{print $4}' | sed 's/\/.*//')"; rm "$d" }
takegit() { git clone "$1" && cd "$(basename "${1%%.git}")" }
take() {
    if [[ $1 =~ ^https?.*\.(tar\.(gz|bz2|xz)|tgz)$ ]]; then takeurl "$1"
    elif [[ $1 =~ ^https?.*\.zip$ ]]; then takezip "$1"
    elif [[ $1 =~ ^([A-Za-z0-9]+@|https?|git|ssh|ftps?|rsync).*\.git/?$ ]]; then takegit "$1"
    else mkcd "$@"; fi
}
zsh_stats() { fc -l 1 | awk '{CMD[$2]++;count++} END {for(a in CMD) print CMD[a],CMD[a]*100/count"%",a}' | grep -v './' | sort -nr | head -20 | column -c3 -s' ' -t | nl }

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
