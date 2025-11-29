# ===========================================
# POWERLEVEL10K INSTANT PROMPT
# ===========================================
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ===========================================
# CORE CONFIGURATION
# ===========================================
export ZSH="$HOME/.oh-my-zsh"

# Theme: Powerlevel10k
ZSH_THEME="powerlevel10k/powerlevel10k"

# Language Settings
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# History Settings
HISTSIZE=100000
SAVEHIST=100000
HISTFILE=~/.zsh_history
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS

# ===========================================
# PLUGINS
# ===========================================
# Ensure these plugins are installed in your .oh-my-zsh/custom/plugins directory
plugins=(
  git
  z
  extract
  sudo
  laravel
  composer
  docker
  docker-compose
  colored-man-pages
  aws
  kubectl
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

# ===========================================
# PATH SETTINGS
# ===========================================
export PATH="$HOME/.composer/vendor/bin:./vendor/bin:$HOME/.local/bin:$PATH"
export PATH="/Users/untionglim/.antigravity/antigravity/bin:$PATH"

# ===========================================
# MODERN CLI REPLACEMENTS
# ===========================================
if command -v bat > /dev/null; then
  alias cat="bat"
fi

if command -v eza > /dev/null; then
  alias ls="eza --icons --git"
  alias ll="eza -l --icons --git"
  alias la="eza -la --icons --git"
else
  alias ll='ls -alFh'
  alias la='ls -A'
fi

# ===========================================
# CUSTOM ALIASES
# ===========================================

# --- System & Network ---
alias zshconfig="nano ~/.zshrc"
alias reload="source ~/.zshrc"
alias myip="curl http://ipecho.net/plain; echo"
# Quick check for listening ports
alias ports="lsof -PiTCP -sTCP:LISTEN"
# Detailed check (Linux/Compat)
alias ports_full="ss -tulanp"

# --- Git Workflow ---
alias gs='git status'
alias glog='git log --oneline --graph -20'
alias gwip='git add -A && git commit -m "WIP"'

# Usage: gclean (Cleans up merged branches, excluding main/master/develop)
# Fixed: Uses grep -E for extended regex and removed xargs -r (incompatible with macOS)
alias gclean='git branch --merged | grep -vE "main|master|develop" | xargs git branch -d'

# --- PHP / Laravel ---
alias pa="php artisan"
alias pat="php artisan tinker"
alias mfs="php artisan migrate:fresh --seed"
alias pint="./vendor/bin/pint"
alias ci="composer install"
alias cda="composer dump-autoload -o"
alias laralog='tail -f storage/logs/laravel.log'

# --- Docker ---
alias dc='docker compose'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'

# ===========================================
# POWERFUL FUNCTIONS
# ===========================================

# --- MySQL / MariaDB Tools ---

# Usage: mysqlstat
mysqlstat() {
    mysql -e "SHOW GLOBAL STATUS LIKE 'Threads%'; SHOW GLOBAL STATUS LIKE 'Queries'; SHOW GLOBAL STATUS LIKE 'Slow_queries';"
}

# Usage: mysqlproc
mysqlproc() {
    mysql -e "SHOW FULL PROCESSLIST;"
}

# Usage: mysqlinnodb
mysqlinnodb() {
    mysql -e "SHOW ENGINE INNODB STATUS\G"
}

# Usage: mysqlexplain "SELECT * FROM users WHERE id = 1"
mysqlexplain() {
    if [ -z "$1" ]; then
        echo "Usage: mysqlexplain '<SQL query>'"
        return 1
    fi
    mysql -e "EXPLAIN ANALYZE $1"
}

# --- System & Network Utilities ---

# Usage: killport 8080
killport() {
    if [ -z "$1" ]; then
        echo "Usage: killport <port>"
        return 1
    fi
    # Use lsof to find PID
    local pid=$(lsof -ti:$1)
    if [ -n "$pid" ]; then
        kill -9 $pid && echo "Killed process $pid on port $1"
    else
        echo "No process on port $1"
    fi
}

# Usage: testconn google.com 80
testconn() {
    if [ -z "$1" ]; then
        echo "Usage: testconn <host> [port]"
        return 1
    fi
    local port=${2:-80}
    nc -zv "$1" "$port" 2>&1
}

# Usage: rg "search_term"
rg() {
    grep -rn --color=auto \
        --exclude-dir={.git,node_modules,vendor,.idea,storage,cache,bootstrap/cache} \
        "$@" .
}

# --- Laravel Utilities ---

# Usage: laraclear
laraclear() {
    php artisan cache:clear
    php artisan config:clear
    php artisan route:clear
    php artisan view:clear
    composer dump-autoload -o
    echo "All caches cleared & Autoload dumped."
}

# --- AWS Utilities ---

alias awswho='aws sts get-caller-identity'

# Usage: ec2ls
# Fixed: Changed quoting style to avoid backtick syntax errors in zsh
ec2ls() {
    aws ec2 describe-instances \
        --query "Reservations[*].Instances[*].[InstanceId,State.Name,InstanceType,PrivateIpAddress,Tags[?Key=='Name'].Value|[0]]" \
        --output table
}

# ===========================================
# POWERLEVEL10K CONFIGURATION
# ===========================================
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"

