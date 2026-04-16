# ===========================================
# 0. GLOBAL FLAGS
# ===========================================
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
typeset -U path PATH fpath FPATH
[[ -r "${ZDOTDIR:-$HOME}/.zsh.startup-profiler.zsh" ]] && source "${ZDOTDIR:-$HOME}/.zsh.startup-profiler.zsh"
(( $+functions[zsh_startup_profile_mark] )) || zsh_startup_profile_mark() { :; }
(( $+functions[zsh_startup_profile_dump_if_slow] )) || zsh_startup_profile_dump_if_slow() { :; }
_zsh_dotdir="${ZDOTDIR:-$HOME}"
_zsh_local_override="${_zsh_dotdir}/.zshrc.local"
_zsh_p10k_file="${_zsh_dotdir}/.p10k.zsh"

_zsh_startup_mark() { zsh_startup_profile_mark "$@"; }
_zsh_startup_dump_if_slow() { zsh_startup_profile_dump_if_slow; }

# ===========================================
# 1. ENVIRONMENT (needed by ALL modes, including agents)
# ===========================================
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export PAGER='less'
export LESS='-R'
export DOCKER_HOST="unix:///var/run/docker.sock"
# Put machine- or org-specific exports in ~/.zshrc.local.

# PATH
export NVM_DIR="$HOME/.nvm"
# Eagerly add NVM default node bin to PATH (so subprocesses like npx work)
if [[ -s "$NVM_DIR/alias/default" ]]; then
  _nvm_ver=$(< "$NVM_DIR/alias/default")
  _nvm_node_bin="$NVM_DIR/versions/node/v${_nvm_ver#v}/bin"
  [[ -d "$_nvm_node_bin" ]] || _nvm_node_bin=""
fi
[[ -z "${_nvm_node_bin:-}" ]] && _nvm_node_bin="$(ls -d "$NVM_DIR/versions/node/"*/bin 2>/dev/null | sort -V | tail -1)"
[[ -n "$_nvm_node_bin" ]] && export PATH="$_nvm_node_bin:$PATH"
unset _nvm_ver _nvm_node_bin
# Strip relative paths and empty entries from inherited PATH
path=("${(@)path:#(|./*|[^/]*)}")
export PATH="$HOME/.composer/vendor/bin:$HOME/.local/bin:$HOME/.antigravity/antigravity/bin:$HOME/.bun/bin:$HOME/go/bin:$PATH"

# API secrets: resolve on demand via 1Password secret references.
# Shell startup stays fast and plaintext secrets only exist in child processes launched through `with-secrets`.
_secret_envs=(ANTHROPIC_AUTH_TOKEN GITLAB_PERSONAL_ACCESS_TOKEN PAGERDUTY_API_KEY PAGERDUTY_USER_API_KEY)
_secret_ref_vars=(
    ANTHROPIC_AUTH_TOKEN_OP_REF
    GITLAB_PERSONAL_ACCESS_TOKEN_OP_REF
    PAGERDUTY_API_KEY_OP_REF
    PAGERDUTY_USER_API_KEY_OP_REF
)

with-secrets() {
    [[ $# -gt 0 ]] || { echo "Usage: with-secrets <command> [args...]"; return 1; }

    local _i _env _current _ref_var _ref_value
    local -a _env_args
    (( ${#_secret_envs} == ${#_secret_ref_vars} )) || {
        echo "Secret config mismatch: _secret_envs and _secret_ref_vars differ in length." >&2
        return 1
    }

    for (( _i = 1; _i <= ${#_secret_envs}; ++_i )); do
        _env=${_secret_envs[$_i]}
        _current="${(P)_env}"
        _ref_var=${_secret_ref_vars[$_i]}
        _ref_value="${(P)_ref_var}"
        if [[ -n "$_current" ]]; then
            _env_args+=("${_env}=${_current}")
        elif [[ -n "$_ref_value" ]]; then
            _env_args+=("${_env}=${_ref_value}")
        else
            echo "Missing secret reference for ${_env}. Set ${_ref_var} in ~/.zshrc.local or export ${_env} before running with-secrets." >&2
            return 1
        fi
    done

    env "${_env_args[@]}" command op run -- "$@"
}

load-secrets() {
    echo "Secrets are resolved on demand."
    echo "Use: with-secrets <command> [args...]"
}

refresh-secrets() {
    load-secrets
}
_zsh_startup_mark env

# ===========================================
# 2. AGENT FAST-PATH (skip interactive UI)
# ===========================================
if [[ -n "$CLAUDE_CODE_AGENT_ID" ]]; then
    PROMPT='%~ $ '
    _zsh_startup_mark agent-fast-path
    _zsh_startup_dump_if_slow
    return
fi

# ===================================================================
# BELOW THIS LINE: INTERACTIVE MODE ONLY
# ===================================================================

# ===========================================
# 3. TMUX & ITERM2 CONTROL MODE (-CC) DETECTION
# ===========================================
if [[ "$TERM" == "screen" || "$TERM" == "tmux" || -n "$TMUX" ]]; then
    if [[ -n "${ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX:-}" ]]; then
        unset ITERMS_SHELL_INTEGRATION_SKIPPED
    else
        export ITERMS_SHELL_INTEGRATION_SKIPPED=1
    fi
fi

# ===========================================
# 4. POWERLEVEL10K INSTANT PROMPT
# ===========================================
# Disabled: this preamble occasionally stalls for several seconds after the terminal
# has been idle, while the rest of the shell now initializes quickly enough without it.
_zsh_startup_mark instant-prompt

# ===========================================
# 5. CORE ZSH SETTINGS (no OMZ framework)
# ===========================================

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
function _set_terminal_title_preexec {
    local _t="${1//\%/%%}"
    _t="${_t//[$'\a\e\n\r']}"
    printf "\e]2;%s\a" "$_t"
    local _w="${1[(w)1]}"
    _w="${_w//[$'\a\e\n\r']}"
    printf "\e]1;%s\a" "$_w"
}
add-zsh-hook precmd _set_terminal_title_precmd
add-zsh-hook preexec _set_terminal_title_preexec
# OSC 7: 讓 terminal 知道 CWD（新分頁開在同目錄）
function _set_terminal_cwd {
    local _pwd="${PWD}"
    _pwd="${_pwd//[$'\a\e\n\r']}"
    _pwd="${_pwd//'%'/%25}"
    _pwd="${_pwd//' '/%20}"
    _pwd="${_pwd//'#'/%23}"
    _pwd="${_pwd//'?'/%3F}"
    printf "\e]7;file://%s%s\a" "$HOST" "$_pwd"
}
add-zsh-hook precmd _set_terminal_cwd

# ===========================================
# 6. COMPLETION
# ===========================================
zmodload -i zsh/complist
WORDCHARS=''
if [[ "$OSTYPE" = darwin* ]]; then
  SHORT_HOST=$(scutil --get LocalHostName 2>/dev/null) || SHORT_HOST="${HOST/.*/}"
else
  SHORT_HOST="${HOST/.*/}"
fi
export ZSH_COMPDUMP="${ZDOTDIR:-$HOME}/.zcompdump-${SHORT_HOST}-${ZSH_VERSION}"
_completion_refresh_stamp="${ZSH_COMPDUMP}.refresh"
_completion_refresh_interval=86400
# Add plugin completion directories to fpath
fpath=(
  $HOME/.oh-my-zsh/plugins/extract
  $fpath
)

_now_epoch() {
  if (( ${+EPOCHSECONDS} )); then
    print -r -- "$EPOCHSECONDS"
  else
    date +%s
  fi
}

_mark_completion_refresh() {
  print -r -- "$(_now_epoch)" >| "$_completion_refresh_stamp"
}

_completion_refresh_needed() {
  [[ ! -s "$ZSH_COMPDUMP" ]] && return 0
  [[ -r "$_completion_refresh_stamp" ]] || return 0

  local _stamp_epoch _now
  _stamp_epoch=$(<"$_completion_refresh_stamp")
  [[ "$_stamp_epoch" == <-> ]] || return 0
  _now=$(_now_epoch)
  (( _now - _stamp_epoch >= _completion_refresh_interval ))
}

_refresh_completions_if_needed() {
  _completion_refresh_needed || return 0
  compinit -i -d "$ZSH_COMPDUMP"
  _mark_completion_refresh
}

autoload -Uz compinit
if [[ -s "$ZSH_COMPDUMP" ]]; then
  compinit -C -d "$ZSH_COMPDUMP"
  _refresh_completions_if_needed
else
  compinit -i -d "$ZSH_COMPDUMP"
  _mark_completion_refresh
fi

rebuild-completions() {
  rm -f "$ZSH_COMPDUMP" "$ZSH_COMPDUMP.zwc" "$_completion_refresh_stamp"
  autoload -Uz compinit
  compinit -i -d "$ZSH_COMPDUMP"
  _mark_completion_refresh
}
_zsh_startup_mark completion
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
# 7. PLUGINS (direct source, no framework)
# ===========================================
_omz="$HOME/.oh-my-zsh"
source "$_omz/custom/themes/powerlevel10k/powerlevel10k.zsh-theme"
source <(command zoxide init zsh)
source "$_omz/plugins/extract/extract.plugin.zsh"
source "$_omz/plugins/sudo/sudo.plugin.zsh"
source "$_omz/plugins/colored-man-pages/colored-man-pages.plugin.zsh"
source "$_omz/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
# syntax-highlighting must be last
source "$_omz/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
unset _omz
_zsh_startup_mark plugins

# ===========================================
# 8. ALIASES
# ===========================================
# Git
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
alias gs='git status'
alias glog='git log --oneline --graph -20'

# Docker & Compose
alias d='docker'
alias dco='docker compose'
alias dcb='docker compose build'
alias ddn='docker compose down'
alias dex='docker exec -it'
alias dlogs='docker compose logs -f'
alias dps='docker compose ps'
alias dup='docker compose up -d'
alias dc='docker compose'
alias docker=podman

# Composer & Laravel
alias c='composer'
alias ci='composer install'
alias cu='composer update'
alias cda='composer dump-autoload -o'
alias art='php artisan'
alias pa='php artisan'
alias mfs='php artisan migrate:fresh --seed'

# Grep defaults: color + exclude common dirs
alias grep="grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox,.venv,venv,node_modules,vendor}"
alias egrep="grep -E"
alias fgrep="grep -F"

# Network & SSH
alias niceboat='ssh niceboat.kkinternal-dev.com'
alias voyager='ssh voyager.kkinternal.com'
alias luna='cd ~/projects/luna/application'
alias myip="curl http://ipecho.net/plain; echo"
alias ports="lsof -PiTCP -sTCP:LISTEN"
alias ports_full="netstat -an -p tcp"
killport() { lsof -ti:"$1" | xargs kill -9; }

# ls / eza
if (( $+commands[eza] )); then
  alias ls="eza --icons --git"
  alias ll="eza -l --icons --git"
  alias la="eza -la --icons --git"
else
  alias ll="ls -lh"
  alias la="ls -lAh"
fi

alias reload="exec zsh"
tmuxcc() { ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX=1 command tmux -CC "$@"; }

# AWS & Kubectl (Lazy Load: first Tab OR first run triggers completion load)
kubectl() {
  unfunction kubectl
  source <(command kubectl completion zsh)
  kubectl "$@"
}
compdef '_dispatch kubectl kubectl' kubectl

aws() {
  unfunction aws
  autoload -U +X bashcompinit && bashcompinit
  complete -C '/usr/local/bin/aws_completer' aws
  command aws "$@"
}
compdef '_dispatch aws aws' aws

# ===========================================
# 9. POWERFUL FUNCTIONS
# ===========================================
mysqlstat() { mysql -e "SHOW GLOBAL STATUS LIKE 'Threads%'; SHOW GLOBAL STATUS LIKE 'Queries'; SHOW GLOBAL STATUS LIKE 'Slow_queries';"; }
mysqlproc() { mysql -e "SHOW FULL PROCESSLIST;"; }
mysqlinnodb() { mysql -e "SHOW ENGINE INNODB STATUS\G"; }
mysqlexplain() { [ -z "$1" ] && { echo "Usage: mysqlexplain '<SQL query>'"; return 1; }; mysql -e "EXPLAIN ANALYZE $1"; }
laraclear() {
    php artisan cache:clear &&
    php artisan config:clear &&
    php artisan route:clear &&
    php artisan view:clear &&
    composer dump-autoload -o &&
    echo "All caches cleared & Autoload dumped."
}
ec2ls() { aws ec2 describe-instances --query "Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,PrivateIpAddress,Tags[?Key=='Name'].Value|[0]]" --output table; }
testconn() { [ -z "$1" ] && { echo "Usage: testconn <host> [port]"; return 1; }; local port=${2:-80}; nc -zv "$1" "$port" 2>&1; }
grepall() { grep -rn --color=auto --exclude-dir={.git,node_modules,vendor,.idea,storage,cache,bootstrap/cache} "$@" . ; }

# take: mkdir+cd / git clone+cd / download+extract+cd
mkcd() { [[ $# -eq 0 ]] && { echo "Usage: mkcd <dir>"; return 1; }; mkdir -p "$@" && cd "${@:$#}" }
takeurl() {
    local d=$(mktemp); curl -L "$1" > "$d"
    tar xf "$d"
    local _dir=$(tar tf "$d" | grep -m1 '/$' | head -1 | sed 's|/.*||')
    rm "$d"
    [[ -n "$_dir" && -d "$_dir" ]] && cd "$_dir"
}
takezip() {
    local d=$(mktemp); curl -L "$1" > "$d"
    unzip "$d" -d ./
    local _dir=$(unzip -l "$d" | awk 'NR>3 && /\/$/ {sub(/\/.*/, "", $4); print $4; exit}')
    rm "$d"
    [[ -n "$_dir" && -d "$_dir" ]] && cd "$_dir"
}
takegit() { local _url="${1%%/}"; git clone "$_url" && cd "$(basename "${_url%%.git}")" }
take() {
    if [[ $1 =~ ^https?.*\.(tar\.(gz|bz2|xz)|tgz)$ ]]; then takeurl "$1"
    elif [[ $1 =~ ^https?.*\.zip$ ]]; then takezip "$1"
    elif [[ $1 =~ ^([A-Za-z0-9]+@|https?|git|ssh|ftps?|rsync).*\.git/?$ ]]; then takegit "$1"
    else mkcd "$@"; fi
}
zsh_stats() { fc -l 1 | awk '{CMD[$2]++;count++} END {for(a in CMD) print CMD[a],CMD[a]*100/count"%",a}' | grep -v './' | sort -nr | head -20 | column -c3 -s' ' -t | nl }

# ===========================================
# 10. NVM LAZY LOAD (interactive wrappers)
# ===========================================
# NVM_DIR and PATH already set in section 1.
# Default Node.js and its global CLIs are already on PATH above.
# Only lazy-load `nvm` itself, which is a shell function provided by nvm.sh.
_nvm_lazy_cmds=(nvm)
_load_nvm() {
    unset -f $_nvm_lazy_cmds 2>/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
}
for _cmd in $_nvm_lazy_cmds; do
    eval "${_cmd}() { _load_nvm; ${_cmd} \"\$@\"; }"
done
unset _cmd

claude() {
    local _bin
    _bin=$(whence -p claude) || { echo "claude not found" >&2; return 127; }
    # Claude auth is handled natively via ~/.claude/settings.json apiKeyHelper.
    # Clear inherited auth-token env so parent processes can't override the helper.
    env -u ANTHROPIC_AUTH_TOKEN "$_bin" "$@"
}

devops() {
    local _bin
    _bin=$(whence -p devops) || { echo "devops not found" >&2; return 127; }
    with-secrets "$_bin" "$@"
}

# ===========================================
# 11. CLAUDE CODE ROUTER
# ===========================================
cclaude() {
    if ! ccr status &>/dev/null; then
        nohup ccr start > /dev/null 2>&1 &
        disown; sleep 1
    fi
    (source <(command ccr activate) && claude "$@")
}
_zsh_startup_mark functions

# ===========================================
# 12. LOCAL OVERRIDES
# ===========================================
[[ -r "$_zsh_local_override" ]] && source "$_zsh_local_override"
_zsh_startup_mark local-overrides

# ===========================================
# 13. BACKGROUND TASKS
# ===========================================
if [[ -z "$ITERMS_SHELL_INTEGRATION_SKIPPED" ]]; then
    [[ -e "${HOME}/.iterm2_shell_integration.zsh" ]] && source "${HOME}/.iterm2_shell_integration.zsh"
fi

zcompile_if_needed() {
  local file=$1
  if [[ -f "$file" && (! -f "$file.zwc" || "$file" -nt "$file.zwc") ]]; then
    rm -f "$file.zwc"
    zcompile "$file" >/dev/null 2>&1
  fi
}
zcompile_if_needed "${_zsh_dotdir}/.zshrc"
zcompile_if_needed "$_zsh_p10k_file"
_zsh_startup_mark background

# ===========================================
# 14. FINISH
# ===========================================
[[ ! -f "$_zsh_p10k_file" ]] || source "$_zsh_p10k_file"
if [[ "$TERM_PROGRAM" == "kiro" ]]; then
    [[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh" ]] && . "${HOME}/Library/Application Support/kiro-cli/shell/zshrc.post.zsh"
    _kiro_shell_integration="/Applications/Kiro.app/Contents/Resources/app/out/vs/workbench/contrib/terminal/common/scripts/shellIntegration-rc.zsh"
    if [[ -r "$_kiro_shell_integration" ]]; then
        . "$_kiro_shell_integration"
    elif (( $+commands[kiro] )); then
        . "$(kiro --locate-shell-integration-path zsh)"
    fi
    unset _kiro_shell_integration
fi
_zsh_startup_mark finish-hooks

PNPM_HOME="${PNPM_HOME:-$HOME/Library/pnpm}"
if [[ -d "$PNPM_HOME" ]]; then
  case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *) export PATH="$PNPM_HOME:$PATH" ;;
  esac
fi

# Google Cloud SDK: keep binaries on PATH, but lazy-load shell completion on first use.
_gcloud_sdk_root="${GCLOUD_SDK_ROOT:-$HOME/google-cloud-sdk}"
if [[ -d "$_gcloud_sdk_root/bin" ]]; then
  case ":$PATH:" in
    *":$_gcloud_sdk_root/bin:"*) ;;
    *) export PATH="$_gcloud_sdk_root/bin:$PATH" ;;
  esac

  _load_gcloud_sdk_completion() {
    unset -f gcloud bq gsutil 2>/dev/null
    local _completion="${GCLOUD_SDK_ROOT:-$HOME/google-cloud-sdk}/completion.zsh.inc"
    [[ -f "$_completion" ]] && . "$_completion"
  }

  gcloud() { _load_gcloud_sdk_completion; command gcloud "$@"; }
  bq() { _load_gcloud_sdk_completion; command bq "$@"; }
  gsutil() { _load_gcloud_sdk_completion; command gsutil "$@"; }
fi
unset _gcloud_sdk_root
_zsh_startup_mark finish
_zsh_startup_dump_if_slow
