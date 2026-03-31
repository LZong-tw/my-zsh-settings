[[ -r "${ZDOTDIR:-$HOME}/.zsh.startup-profiler.zsh" ]] && source "${ZDOTDIR:-$HOME}/.zsh.startup-profiler.zsh"
(( $+functions[zsh_startup_profile_mark] )) || zsh_startup_profile_mark() { :; }

# Login-shell bootstrap only. Keep this file focused on environment setup.

# Kiro CLI hooks are only needed inside Kiro's own terminal.
if [[ "${TERM_PROGRAM:-}" == "kiro" ]]; then
    [[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zprofile.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zprofile.pre.zsh"
    zsh_startup_profile_mark kiro-pre
fi

# Homebrew lives in a fixed prefix on Apple Silicon Macs, so avoid spawning
# `brew shellenv` on every login shell.
if [[ -d "/opt/homebrew" ]]; then
    export HOMEBREW_PREFIX="/opt/homebrew"
    export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
    export HOMEBREW_REPOSITORY="/opt/homebrew"
    fpath=("/opt/homebrew/share/zsh/site-functions" $fpath)
    path=("/opt/homebrew/bin" "/opt/homebrew/sbin" $path)
    [[ -n "${MANPATH-}" ]] && export MANPATH=":${MANPATH#:}"
    export INFOPATH="/opt/homebrew/share/info:${INFOPATH:-}"
    zsh_startup_profile_mark brew-shellenv
fi

# Kiro CLI post block. Keep at the bottom of this file.
if [[ "${TERM_PROGRAM:-}" == "kiro" ]]; then
    [[ -f "${HOME}/Library/Application Support/kiro-cli/shell/zprofile.post.zsh" ]] && builtin source "${HOME}/Library/Application Support/kiro-cli/shell/zprofile.post.zsh"
    zsh_startup_profile_mark kiro-post
fi
