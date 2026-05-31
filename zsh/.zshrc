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
# (N) null_glob qualifier: expands to nothing (no error) when no node is installed
[[ -z "${_nvm_node_bin:-}" ]] && _nvm_node_bin="$(print -rl -- "$NVM_DIR"/versions/node/*/bin(N) | sort -V | tail -1)"
[[ -n "$_nvm_node_bin" ]] && export PATH="$_nvm_node_bin:$PATH"
unset _nvm_ver _nvm_node_bin
# Strip relative paths and empty entries from inherited PATH
path=("${(@)path:#(|./*|[^/]*)}")
if [[ -d "/opt/homebrew/opt/go@1.25/bin" ]]; then
  path=("/opt/homebrew/opt/go@1.25/bin" "${(@)path:#/opt/homebrew/opt/go@1.25/bin}")
fi
export PATH="$HOME/.composer/vendor/bin:$HOME/.local/bin:$HOME/.antigravity/antigravity/bin:$HOME/.bun/bin:$HOME/go/bin:$PATH"

# WSL screenshot paste bridge: Win+Shift+S -> paste a WSL-readable image path.
if [[ "${WSL_SCREENSHOT_CLI_AUTOSTART:-1}" != "0" \
      && ( -n "${WSL_DISTRO_NAME:-}" || -r /proc/sys/fs/binfmt_misc/WSLInterop ) ]] \
      && command -v wsl-screenshot-cli >/dev/null 2>&1; then
  { wsl-screenshot-cli start --daemon --quiet --interval "${WSL_SCREENSHOT_CLI_INTERVAL_MS:-500}" >/dev/null 2>&1 } &!
fi

# API secrets: resolve on demand via 1Password secret references.
# Claude uses ~/.claude/settings.json apiKeyHelper, so with-secrets intentionally
# excludes ANTHROPIC_AUTH_TOKEN to avoid leaking Claude provider state into tools.
# Shell startup stays fast and plaintext secrets only exist in child processes launched through `with-secrets`.
_secret_envs=(GITLAB_PERSONAL_ACCESS_TOKEN PAGERDUTY_API_KEY PAGERDUTY_USER_API_KEY)
_secret_ref_vars=(
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

    env \
        -u ANTHROPIC_AUTH_TOKEN \
        -u ANTHROPIC_AUTH_TOKEN_OP_REF \
        -u ANTHROPIC_AUTH_TOKEN_OP_REF_DEFAULT \
        -u ANTHROPIC_AUTH_TOKEN_OP_REF_JBRIDGE \
        -u ANTHROPIC_AUTH_TOKEN_OP_REF_AZURE \
        -u ANTHROPIC_AUTH_TOKEN_OP_REF_ALT1 \
        "${_env_args[@]}" command op run -- "$@"
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
alias history="history 0"
TIMEFMT=$'\nreal\t%E\nuser\t%U\nsys\t%S\ncpu\t%P'

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
# Kali defaults: a=b style filename expansion, numeric-aware glob sort
setopt magicequalsubst numericglobsort
# Hide the end-of-line '%' marker (Kali default)
PROMPT_EOL_MARK=""

# --- Theme support (from lib/theme-and-appearance.zsh) ---
autoload -U colors && colors
setopt prompt_subst

# --- Color support (Kali-inspired, guarded for portability) ---
if (( $+commands[dircolors] )); then
  if [[ -r "$HOME/.dircolors" ]]; then
    eval "$(dircolors -b "$HOME/.dircolors")"
  else
    eval "$(dircolors -b)"
  fi
  export LS_COLORS="${LS_COLORS}:ow=30;44:"
fi
export LESS_TERMCAP_mb=$'\E[1;31m'
export LESS_TERMCAP_md=$'\E[1;36m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;33m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_us=$'\E[1;32m'
export LESS_TERMCAP_ue=$'\E[0m'

# --- Key bindings (from lib/key-bindings.zsh) ---
bindkey -e
bindkey '^U' backward-kill-line
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
bindkey '^[[5~' beginning-of-buffer-or-history
bindkey '^[[6~' end-of-buffer-or-history
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
_completion_refresh_delay=120
_completion_refresh_lock="${ZSH_COMPDUMP}.refresh.lock"
# Add plugin completion directories to fpath (only when present)
[[ -d "$HOME/.oh-my-zsh/plugins/extract" ]] && fpath=("$HOME/.oh-my-zsh/plugins/extract" $fpath)

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

_refresh_completions_in_background() {
  add-zsh-hook -d precmd _refresh_completions_in_background
  _completion_refresh_needed || return 0

  local _tmp_dump="${ZSH_COMPDUMP}.${$}.${RANDOM}.tmp"
  (
    sleep "$_completion_refresh_delay" || exit
    if command mkdir "$_completion_refresh_lock" 2>/dev/null; then
      trap 'rmdir "$_completion_refresh_lock"; rm -f "$_tmp_dump" "$_tmp_dump.zwc"' EXIT INT TERM HUP
      autoload -Uz compinit
      if compinit -i -d "$_tmp_dump"; then
        command mv -f "$_tmp_dump" "$ZSH_COMPDUMP"
        _mark_completion_refresh
      fi
    fi
  ) >/dev/null 2>&1 &!
}

autoload -Uz compinit
if [[ -s "$ZSH_COMPDUMP" ]]; then
  compinit -C -d "$ZSH_COMPDUMP"
  _completion_refresh_needed && add-zsh-hook precmd _refresh_completions_in_background
else
  compinit -i -d "$ZSH_COMPDUMP"
  _mark_completion_refresh
fi

rebuild-completions() {
  rm -f "$ZSH_COMPDUMP" "$ZSH_COMPDUMP.zwc" "$_completion_refresh_stamp"
  rmdir "$_completion_refresh_lock" 2>/dev/null
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
# Source the first readable candidate; skip silently if none exists.
# Keeps this config portable across an oh-my-zsh layout (Mac/dev boxes) and
# distro packages such as Kali/Debian's /usr/share/* without erroring on startup.
_zsh_source_first() {
  local _f
  for _f in "$@"; do
    if [[ -r "$_f" ]]; then
      source "$_f"
      return 0
    fi
  done
  return 1
}

# Powerlevel10k theme (prompt appearance). Candidates cover oh-my-zsh custom,
# Debian/Kali packages, and Homebrew (Apple Silicon + Intel). _zsh_p10k_loaded
# gates the Kali prompt fallback in section 14.
if _zsh_source_first \
  "$_omz/custom/themes/powerlevel10k/powerlevel10k.zsh-theme" \
  "/usr/share/powerlevel10k/powerlevel10k.zsh-theme" \
  "/usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme" \
  "/opt/homebrew/share/powerlevel10k/powerlevel10k.zsh-theme" \
  "/usr/local/share/powerlevel10k/powerlevel10k.zsh-theme"; then
  _zsh_p10k_loaded=1
fi

# zoxide (smart cd) — only when the binary is installed
(( $+commands[zoxide] )) && source <(command zoxide init zsh)

# oh-my-zsh helper plugins (optional; present only when oh-my-zsh is installed)
_zsh_source_first "$_omz/plugins/extract/extract.plugin.zsh"
_zsh_source_first "$_omz/plugins/sudo/sudo.plugin.zsh"
_zsh_source_first "$_omz/plugins/colored-man-pages/colored-man-pages.plugin.zsh"

# autosuggestions — prefer oh-my-zsh custom, fall back to distro/Homebrew package
if _zsh_source_first \
  "$_omz/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  "/usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh"; then
  # Kali default suggestion color (subtle grey).
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#999'
fi

# syntax-highlighting must be last
if _zsh_source_first \
  "$_omz/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "/usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"; then
  # Kali's syntax-highlighting color theme, ported verbatim from Kali's default
  # /etc/skel/.zshrc so highlighting matches the Kali look on any machine.
  ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern)
  ZSH_HIGHLIGHT_STYLES[default]=none
  ZSH_HIGHLIGHT_STYLES[unknown-token]=underline
  ZSH_HIGHLIGHT_STYLES[reserved-word]=fg=cyan,bold
  ZSH_HIGHLIGHT_STYLES[suffix-alias]=fg=green,underline
  ZSH_HIGHLIGHT_STYLES[global-alias]=fg=green,bold
  ZSH_HIGHLIGHT_STYLES[precommand]=fg=green,underline
  ZSH_HIGHLIGHT_STYLES[commandseparator]=fg=blue,bold
  ZSH_HIGHLIGHT_STYLES[autodirectory]=fg=green,underline
  ZSH_HIGHLIGHT_STYLES[path]=bold
  ZSH_HIGHLIGHT_STYLES[path_pathseparator]=
  ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]=
  ZSH_HIGHLIGHT_STYLES[globbing]=fg=blue,bold
  ZSH_HIGHLIGHT_STYLES[history-expansion]=fg=blue,bold
  ZSH_HIGHLIGHT_STYLES[command-substitution]=none
  ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]=fg=magenta,bold
  ZSH_HIGHLIGHT_STYLES[process-substitution]=none
  ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]=fg=magenta,bold
  ZSH_HIGHLIGHT_STYLES[single-hyphen-option]=fg=green
  ZSH_HIGHLIGHT_STYLES[double-hyphen-option]=fg=green
  ZSH_HIGHLIGHT_STYLES[back-quoted-argument]=none
  ZSH_HIGHLIGHT_STYLES[back-quoted-argument-delimiter]=fg=blue,bold
  ZSH_HIGHLIGHT_STYLES[single-quoted-argument]=fg=yellow
  ZSH_HIGHLIGHT_STYLES[double-quoted-argument]=fg=yellow
  ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]=fg=yellow
  ZSH_HIGHLIGHT_STYLES[rc-quote]=fg=magenta
  ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]=fg=magenta,bold
  ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]=fg=magenta,bold
  ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]=fg=magenta,bold
  ZSH_HIGHLIGHT_STYLES[assign]=none
  ZSH_HIGHLIGHT_STYLES[redirection]=fg=blue,bold
  ZSH_HIGHLIGHT_STYLES[comment]=fg=black,bold
  ZSH_HIGHLIGHT_STYLES[named-fd]=none
  ZSH_HIGHLIGHT_STYLES[numeric-fd]=none
  ZSH_HIGHLIGHT_STYLES[arg0]=fg=cyan
  ZSH_HIGHLIGHT_STYLES[bracket-error]=fg=red,bold
  ZSH_HIGHLIGHT_STYLES[bracket-level-1]=fg=blue,bold
  ZSH_HIGHLIGHT_STYLES[bracket-level-2]=fg=green,bold
  ZSH_HIGHLIGHT_STYLES[bracket-level-3]=fg=magenta,bold
  ZSH_HIGHLIGHT_STYLES[bracket-level-4]=fg=yellow,bold
  ZSH_HIGHLIGHT_STYLES[bracket-level-5]=fg=cyan,bold
  ZSH_HIGHLIGHT_STYLES[cursor-matchingbracket]=standout
fi

unset -f _zsh_source_first
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
  alias l="eza --icons --git"
  alias ll="eza -l --icons --git"
  alias la="eza -la --icons --git"
else
  if command ls --color=auto . >/dev/null 2>&1; then
    alias ls="ls --color=auto"
  fi
  alias l="ls -CF"
  alias ll="ls -lh"
  alias la="ls -lAh"
fi
if (( $+commands[diff] )) && command diff --color=auto /dev/null /dev/null >/dev/null 2>&1; then
  alias diff="diff --color=auto"
fi
(( $+commands[ip] )) && alias ip="ip --color=auto"

alias reload="exec zsh"
tmuxcc() { ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX=1 command tmux -CC "$@"; }

# AWS & Kubectl (Lazy Load: first Tab OR first run triggers completion load)
p10k_kubecontext_lazy_prompt() {
  local _cache="${P10K_KUBECONTEXT_CACHE_FILE:-${XDG_CACHE_HOME:-$HOME/.cache}/p10k-kubecontext}"
  local _ctx
  [[ -r "$_cache" ]] || return 0
  IFS= read -r _ctx < "$_cache" || return 0
  [[ -n "$_ctx" ]] || return 0
  print -r -- "$_ctx"
}

p10k_kubecontext_lazy_refresh() {
  emulate -L zsh
  (( $+commands[kubectl] )) || return 127

  local _cache="${P10K_KUBECONTEXT_CACHE_FILE:-${XDG_CACHE_HOME:-$HOME/.cache}/p10k-kubecontext}"
  local _dir="${_cache:h}"
  local _ctx
  [[ -d "$_dir" ]] || command mkdir -p "$_dir" 2>/dev/null || return 1
  _ctx="$(command kubectl config current-context 2>/dev/null)" || {
    command rm -f "$_cache" 2>/dev/null
    return 1
  }
  [[ -n "$_ctx" ]] || {
    command rm -f "$_cache" 2>/dev/null
    return 1
  }
  print -r -- "$_ctx" >| "$_cache"
}

p10k_kubecontext_lazy_refresh_async() {
  emulate -L zsh
  [[ -z "${P10K_KUBECONTEXT_LAZY_DISABLE:-}" ]] || return 0
  (( $+commands[kubectl] )) || return 0

  local _cache="${P10K_KUBECONTEXT_CACHE_FILE:-${XDG_CACHE_HOME:-$HOME/.cache}/p10k-kubecontext}"
  local _lock="${_cache}.lock"
  if command mkdir "$_lock" 2>/dev/null; then
    (
      trap 'command rmdir "$_lock" 2>/dev/null' EXIT INT TERM HUP
      p10k_kubecontext_lazy_refresh >/dev/null 2>&1
    ) &!
  fi
}

_refresh_kubecontext_after_command() {
  local _status=${1:-0}
  (( $+functions[p10k_kubecontext_lazy_refresh_async] )) && p10k_kubecontext_lazy_refresh_async
  return "$_status"
}

_kubectl_completion_loaded=0
_load_kubectl_completion() {
  (( _kubectl_completion_loaded )) && return 0
  (( $+commands[kubectl] )) || return 127
  source <(command kubectl completion zsh)
  _kubectl_completion_loaded=1
}

_kubectl_lazy_complete() {
  (( _kubectl_completion_loaded )) || _load_kubectl_completion || return 1

  local _comp="${_comps[kubectl]-}"
  [[ -n "$_comp" && "$_comp" != "_kubectl_lazy_complete" ]] || return 1
  eval "$_comp"
}

kubectl() {
  _load_kubectl_completion
  command kubectl "$@"
  local _status=$?
  _refresh_kubecontext_after_command "$_status"
}
compdef _kubectl_lazy_complete kubectl

if (( $+commands[kubectx] )); then
  kubectx() {
    command kubectx "$@"
    local _status=$?
    _refresh_kubecontext_after_command "$_status"
  }
fi
if (( $+commands[kubens] )); then
  kubens() {
    command kubens "$@"
    local _status=$?
    _refresh_kubecontext_after_command "$_status"
  }
fi

aws() {
  _load_aws_completion >/dev/null 2>&1 || true
  command aws "$@"
}

_aws_completion_loaded=0
_load_aws_completion() {
  (( _aws_completion_loaded )) && return 0

  local _aws_completer
  _aws_completer=$(whence -p aws_completer) || return 127

  autoload -U +X bashcompinit && bashcompinit
  complete -C "$_aws_completer" aws
  _aws_completion_loaded=1
}

_aws_lazy_complete() {
  _load_aws_completion || return 1

  local _comp="${_comps[aws]-}"
  [[ -n "$_comp" && "$_comp" != "_aws_lazy_complete" ]] || return 1
  eval "$_comp"
}
compdef _aws_lazy_complete aws

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

_aws_effective_profile() {
    emulate -L zsh
    if [[ -n "${AWS_PROFILE:-}" ]]; then
        print -r -- "$AWS_PROFILE"
    elif [[ -n "${AWS_DEFAULT_PROFILE:-}" ]]; then
        print -r -- "$AWS_DEFAULT_PROFILE"
    else
        print -r -- "default"
    fi
}

_aws_env_creds_state() {
    emulate -L zsh
    if [[ -n "${AWS_ACCESS_KEY_ID:-}" || -n "${AWS_SECRET_ACCESS_KEY:-}" || -n "${AWS_SESSION_TOKEN:-}" ]]; then
        print -r -- "present"
    else
        print -r -- "absent"
    fi
}

_aws_config_get() {
    emulate -L zsh
    local _profile=$1
    local _key=$2
    local _value

    _value=$(command aws configure get "profile.${_profile}.${_key}" 2>/dev/null)
    print -r -- "${_value:-<unset>}"
}

awswho() {
    emulate -L zsh
    local _want_sts=0

    case "${1:-}" in
        --sts)
            _want_sts=1
            shift
            ;;
        "" ) ;;
        * )
            echo "Usage: awswho [--sts]" >&2
            return 1
            ;;
    esac

    [[ $# -eq 0 ]] || { echo "Usage: awswho [--sts]" >&2; return 1; }
    (( $+commands[aws] )) || { echo "aws not found" >&2; return 127; }

    local _profile _env_creds _source _region _role_arn _source_profile _credential_process
    _profile=$(_aws_effective_profile)
    _env_creds=$(_aws_env_creds_state)
    _source="profile:${_profile}"
    [[ "$_env_creds" == "present" ]] && _source="env-credentials"

    _region="${AWS_REGION:-${AWS_DEFAULT_REGION:-$(_aws_config_get "$_profile" region)}}"
    _role_arn=$(_aws_config_get "$_profile" role_arn)
    _source_profile=$(_aws_config_get "$_profile" source_profile)
    _credential_process=$(_aws_config_get "$_profile" credential_process)

    print -r -- "source: ${_source}"
    print -r -- "AWS_PROFILE: ${AWS_PROFILE:-<unset>}"
    print -r -- "AWS_DEFAULT_PROFILE: ${AWS_DEFAULT_PROFILE:-<unset>}"
    print -r -- "env_session: ${_env_creds}"
    print -r -- "region: ${_region:-<unset>}"
    print -r -- "role_arn: ${_role_arn}"
    print -r -- "source_profile: ${_source_profile}"
    print -r -- "credential_process: ${_credential_process}"
    print -r -- "session_expiration: ${AWS_SESSION_EXPIRATION:-${AWS_CREDENTIAL_EXPIRATION:-<unset>}}"
    print -r -- "granted_command: ${GRANTED_COMMAND:-<unset>}"

    if (( _want_sts )); then
        local _sts_json _account _arn _user_id
        _sts_json=$(command aws sts get-caller-identity --no-cli-pager --output json 2>&1) || {
            print -r -- "sts: error"
            print -r -- "$_sts_json"
            return 1
        }

        if (( $+commands[jq] )); then
            _account=$(jq -r '.Account' <<< "$_sts_json")
            _arn=$(jq -r '.Arn' <<< "$_sts_json")
            _user_id=$(jq -r '.UserId' <<< "$_sts_json")
            print -r -- "sts_account: ${_account}"
            print -r -- "sts_arn: ${_arn}"
            print -r -- "sts_user_id: ${_user_id}"
        else
            print -r -- "sts: ${_sts_json}"
        fi
    fi
}

kubewho() {
    emulate -L zsh
    local _want_sts=0
    local _context=""

    while (( $# )); do
        case "$1" in
            --sts)
                _want_sts=1
                ;;
            -h|--help)
                echo "Usage: kubewho [--sts] [context]" >&2
                return 0
                ;;
            *)
                [[ -z "$_context" ]] || { echo "Usage: kubewho [--sts] [context]" >&2; return 1; }
                _context="$1"
                ;;
        esac
        shift
    done

    (( $+commands[kubectl] )) || { echo "kubectl not found" >&2; return 127; }
    (( $+commands[jq] )) || { echo "kubewho requires jq" >&2; return 127; }

    [[ -n "$_context" ]] || _context=$(command kubectl config current-context 2>/dev/null)
    [[ -n "$_context" ]] || { echo "No current kube context" >&2; return 1; }

    local _config_json _cluster _user _server _exec_command _exec_profile _exec_default_profile _unset_vars
    local _shell_profile _shell_env_creds _identity_source _isolated_env
    _config_json=$(command kubectl config view --raw -o json 2>/dev/null) || {
        echo "Failed to read kubeconfig" >&2
        return 1
    }

    _cluster=$(jq -r --arg ctx "$_context" '.contexts[] | select(.name == $ctx) | .context.cluster' <<< "$_config_json")
    _user=$(jq -r --arg ctx "$_context" '.contexts[] | select(.name == $ctx) | .context.user' <<< "$_config_json")
    [[ -n "$_cluster" && -n "$_user" ]] || { echo "Context not found: $_context" >&2; return 1; }

    _server=$(jq -r --arg cluster "$_cluster" '.clusters[] | select(.name == $cluster) | .cluster.server // "<unset>"' <<< "$_config_json")
    _exec_command=$(jq -r --arg user "$_user" '.users[] | select(.name == $user) | .user.exec.command // "<none>"' <<< "$_config_json")
    _exec_profile=$(jq -r --arg user "$_user" '.users[] | select(.name == $user) | ((.user.exec.args // []) | map(select(startswith("AWS_PROFILE="))) | .[0] // "" | sub("^AWS_PROFILE="; ""))' <<< "$_config_json")
    _exec_default_profile=$(jq -r --arg user "$_user" '.users[] | select(.name == $user) | ((.user.exec.args // []) | map(select(startswith("AWS_DEFAULT_PROFILE="))) | .[0] // "" | sub("^AWS_DEFAULT_PROFILE="; ""))' <<< "$_config_json")
    _unset_vars=$(jq -r --arg user "$_user" '
        .users[] | select(.name == $user) |
        (.user.exec.args // []) as $args |
        if ($args | length) > 1 then
            [
                range(0; ($args | length) - 1)
                | select($args[.] == "-u")
                | $args[.+1]
            ] | join(",")
        else
            ""
        end
    ' <<< "$_config_json")

    _shell_profile=$(_aws_effective_profile)
    _shell_env_creds=$(_aws_env_creds_state)
    _isolated_env="no"
    [[ "$_unset_vars" == *AWS_ACCESS_KEY_ID* && "$_unset_vars" == *AWS_SECRET_ACCESS_KEY* && "$_unset_vars" == *AWS_SESSION_TOKEN* ]] && _isolated_env="yes"

    if [[ -n "$_exec_profile" ]]; then
        _identity_source="kubeconfig profile:${_exec_profile}"
    elif [[ "$_shell_env_creds" == "present" ]]; then
        _identity_source="ambient shell env credentials"
    else
        _identity_source="ambient shell profile:${_shell_profile}"
    fi

    print -r -- "context: ${_context}"
    print -r -- "cluster: ${_cluster}"
    print -r -- "server: ${_server}"
    print -r -- "user: ${_user}"
    print -r -- "exec_command: ${_exec_command}"
    print -r -- "exec_profile: ${_exec_profile:-<unset>}"
    print -r -- "exec_default_profile: ${_exec_default_profile:-<unset>}"
    print -r -- "exec_unset_env: ${_unset_vars:-<none>}"
    print -r -- "exec_env_isolated: ${_isolated_env}"
    print -r -- "shell_profile: ${_shell_profile}"
    print -r -- "shell_env_session: ${_shell_env_creds}"
    print -r -- "identity_source: ${_identity_source}"

    if (( _want_sts )); then
        local -a _cmd
        local _var
        local _sts_json _account _arn _user_id

        case "$_exec_command" in
            env|aws) ;;
            *)
                echo "kubewho --sts only supports aws/env exec commands" >&2
                return 1
                ;;
        esac

        _cmd=(env)
        for _var in "${(@s:,:)_unset_vars}"; do
            [[ -n "$_var" ]] && _cmd+=(-u "$_var")
        done
        [[ -n "$_exec_profile" ]] && _cmd+=("AWS_PROFILE=${_exec_profile}")
        [[ -n "$_exec_default_profile" ]] && _cmd+=("AWS_DEFAULT_PROFILE=${_exec_default_profile}")
        _cmd+=(aws sts get-caller-identity --no-cli-pager --output json)

        _sts_json=$("${_cmd[@]}" 2>&1) || {
            print -r -- "sts: error"
            print -r -- "$_sts_json"
            return 1
        }

        _account=$(jq -r '.Account' <<< "$_sts_json")
        _arn=$(jq -r '.Arn' <<< "$_sts_json")
        _user_id=$(jq -r '.UserId' <<< "$_sts_json")
        print -r -- "sts_account: ${_account}"
        print -r -- "sts_arn: ${_arn}"
        print -r -- "sts_user_id: ${_user_id}"
    fi
}

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
_ccr_health() {
    command curl -fsS -m 1 "${CCR_HEALTH_URL:-http://127.0.0.1:${CCR_PORT:-3456}/health}" >/dev/null 2>&1
}

_ccr_running() {
    command ccr status >/dev/null 2>&1 || _ccr_health
}

ccr-start() {
    local _bin _op_bin _token_ref
    _bin=$(whence -p ccr) || { echo "ccr not found" >&2; return 127; }

    if [[ -n "${ANTHROPIC_AUTH_TOKEN:-}" && "$ANTHROPIC_AUTH_TOKEN" != op://* ]]; then
        "$_bin" start "$@"
        return
    fi

    _token_ref="${CCR_ANTHROPIC_AUTH_TOKEN_OP_REF:-${ANTHROPIC_AUTH_TOKEN_OP_REF_DEFAULT:-${ANTHROPIC_AUTH_TOKEN_OP_REF:-}}}"
    if [[ -z "$_token_ref" ]]; then
        echo "Missing CCR_ANTHROPIC_AUTH_TOKEN_OP_REF or ANTHROPIC_AUTH_TOKEN_OP_REF_DEFAULT for ccr-start." >&2
        return 1
    fi

    _op_bin=${OP_BIN:-}
    if [[ -z "$_op_bin" ]]; then
        _op_bin=$(command -v op 2>/dev/null) || { echo "op not found; cannot resolve $_token_ref" >&2; return 127; }
    elif [[ ! -x "$_op_bin" ]]; then
        echo "op not executable: $_op_bin" >&2
        return 127
    fi

    env \
        -u ANTHROPIC_AUTH_TOKEN_OP_REF \
        -u ANTHROPIC_AUTH_TOKEN_OP_REF_DEFAULT \
        -u ANTHROPIC_AUTH_TOKEN_OP_REF_JBRIDGE \
        -u ANTHROPIC_AUTH_TOKEN_OP_REF_AZURE \
        -u ANTHROPIC_AUTH_TOKEN_OP_REF_ALT1 \
        ANTHROPIC_AUTH_TOKEN="$_token_ref" \
        "$_op_bin" run -- "$_bin" start "$@"
}

cclaude() {
    local _try
    if ! _ccr_running; then
        ccr-start > /dev/null 2>&1 &
        disown
        for _try in {1..20}; do
            _ccr_running && break
            sleep 0.25
        done
    fi
    if ! _ccr_running; then
        echo "ccr is not running; run ccr-start to see the startup error." >&2
        return 1
    fi
    (source <(command ccr activate) && command claude --settings '{"apiKeyHelper":""}' "$@")
}
_zsh_startup_mark functions

# Debian/Kali command-not-found helper, when present.
[[ -r /etc/zsh_command_not_found ]] && source /etc/zsh_command_not_found
_zsh_startup_mark command-not-found

# ===========================================
# 12. LOCAL OVERRIDES
# ===========================================
[[ -r "$_zsh_local_override" ]] && source "$_zsh_local_override"
_zsh_startup_mark local-overrides

# ===========================================
# 13. BACKGROUND TASKS
# ===========================================
_should_load_iterm2_shell_integration() {
  [[ -z "${ITERMS_SHELL_INTEGRATION_SKIPPED:-}" ]] || return 1
  [[ -r "${HOME}/.iterm2_shell_integration.zsh" ]] || return 1
  [[ "${TERM_PROGRAM:-}" == "iTerm.app" || -n "${ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX:-}" ]]
}
if _should_load_iterm2_shell_integration; then
  source "${HOME}/.iterm2_shell_integration.zsh"
fi
unset -f _should_load_iterm2_shell_integration

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
# Prompt: Powerlevel10k when available, otherwise Kali's native two-line prompt.
if [[ -n "${_zsh_p10k_loaded:-}" ]]; then
    [[ ! -f "$_zsh_p10k_file" ]] || source "$_zsh_p10k_file"
else
    # --- Kali prompt fallback (ported from Kali's default .zshrc) ---
    # Active only when Powerlevel10k could not be loaded, so the look stays
    # close to stock Kali. p10k remains the preferred prompt when present.
    [[ -n "${debian_chroot:-}" ]] || { [[ -r /etc/debian_chroot ]] && debian_chroot=$(</etc/debian_chroot); }
    PROMPT_ALTERNATIVE="${PROMPT_ALTERNATIVE:-twoline}"
    NEWLINE_BEFORE_PROMPT="${NEWLINE_BEFORE_PROMPT:-yes}"
    VIRTUAL_ENV_DISABLE_PROMPT=1

    configure_prompt() {
        local prompt_symbol=㉿
        case "$PROMPT_ALTERNATIVE" in
            twoline)
                PROMPT=$'%F{%(#.blue.green)}┌──${debian_chroot:+($debian_chroot)─}${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))─}(%B%F{%(#.red.blue)}%n'$prompt_symbol$'%m%b%F{%(#.blue.green)})-[%B%F{reset}%(6~.%-1~/…/%4~.%5~)%b%F{%(#.blue.green)}]\n└─%B%(#.%F{red}#.%F{blue}$)%b%F{reset} '
                ;;
            oneline)
                PROMPT=$'${debian_chroot:+($debian_chroot)}${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))}%B%F{%(#.red.blue)}%n@%m%b%F{reset}:%B%F{%(#.blue.green)}%~%b%F{reset}%(#.#.$) '
                RPROMPT=
                ;;
            backtrack)
                PROMPT=$'${debian_chroot:+($debian_chroot)}${VIRTUAL_ENV:+($(basename $VIRTUAL_ENV))}%B%F{red}%n@%m%b%F{reset}:%B%F{blue}%~%b%F{reset}%(#.#.$) '
                RPROMPT=
                ;;
        esac
    }
    configure_prompt

    # Ctrl+P toggles between the two-line and one-line Kali prompt.
    toggle_oneline_prompt() {
        if [[ "$PROMPT_ALTERNATIVE" = oneline ]]; then
            PROMPT_ALTERNATIVE=twoline
        else
            PROMPT_ALTERNATIVE=oneline
        fi
        configure_prompt
        zle reset-prompt
    }
    zle -N toggle_oneline_prompt
    bindkey ^P toggle_oneline_prompt

    # Blank line before each prompt except the first (Kali behaviour).
    _kali_newline_before_prompt() {
        if [[ "$NEWLINE_BEFORE_PROMPT" = yes ]]; then
            if [[ -z "${_NEW_LINE_BEFORE_PROMPT:-}" ]]; then
                _NEW_LINE_BEFORE_PROMPT=1
            else
                print ""
            fi
        fi
    }
    add-zsh-hook precmd _kali_newline_before_prompt
fi
unset _zsh_p10k_loaded
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
  path=("${(@)path:#$_gcloud_sdk_root/bin}" "$_gcloud_sdk_root/bin")

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

_zsh_startup_dump_after_first_prompt() {
  add-zsh-hook -d precmd _zsh_startup_dump_after_first_prompt
  _zsh_startup_mark first-prompt
  _zsh_startup_dump_if_slow
}
add-zsh-hook precmd _zsh_startup_dump_after_first_prompt
export KKBOX_SKILLS_DIR=~/projects/kkbox-skills
