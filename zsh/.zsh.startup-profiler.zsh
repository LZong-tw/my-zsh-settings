[[ -n "${ZSH_STARTUP_PROFILING:-}" ]] || return 0

zmodload zsh/datetime 2>/dev/null || return 0
if [[ "${ZSH_STARTUP_PROFILE_ZPROF:-1}" != 0 ]]; then
    zmodload zsh/zprof 2>/dev/null
fi

typeset -g _zsh_startup_profile_t0="${_zsh_startup_profile_t0:-${EPOCHREALTIME:-0}}"
typeset -ga _zsh_startup_profile_marks
typeset -g ZSH_STARTUP_PROFILE_THRESHOLD="${ZSH_STARTUP_PROFILE_THRESHOLD:-2.0}"
typeset -g ZSH_STARTUP_PROFILE_LOG_PATH="${ZSH_STARTUP_PROFILE_LOG_PATH:-${XDG_CACHE_HOME:-$HOME/.cache}/zsh-slow-start.log}"

zsh_startup_profile_mark() {
    [[ -n "${_zsh_startup_profile_t0:-}" ]] || return 0
    _zsh_startup_profile_marks+=("$1:${EPOCHREALTIME:-0}")
}

zsh_startup_profile_dump_if_slow() {
    [[ -n "${_zsh_startup_profile_t0:-}" ]] || return 0

    local _end=${EPOCHREALTIME:-0}
    local -F 6 _prev _cur _delta _total _threshold
    _prev=$_zsh_startup_profile_t0
    _threshold=${ZSH_STARTUP_PROFILE_THRESHOLD:-2.0}
    _total=$((_end - _zsh_startup_profile_t0))
    (( _total >= _threshold )) || return 0

    local _log_path="${ZSH_STARTUP_PROFILE_LOG_PATH:-${XDG_CACHE_HOME:-$HOME/.cache}/zsh-slow-start.log}"
    local _log_dir="${_log_path:h}"
    [[ -d "$_log_dir" ]] || mkdir -p "$_log_dir" 2>/dev/null || return 0

    {
        printf '=== %s term=%s tmux=%s total=%.3fs pwd=%s ===\n' \
            "$(date '+%Y-%m-%dT%H:%M:%S%z')" \
            "${TERM_PROGRAM:-${TERM:-unknown}}" \
            "${TMUX:+1}" \
            "$_total" \
            "$PWD"
        local _mark _name
        for _mark in "${_zsh_startup_profile_marks[@]}"; do
            _name=${_mark%%:*}
            _cur=${_mark#*:}
            _delta=$((_cur - _prev))
            printf '  %7.3fs  %s\n' "$_delta" "$_name"
            _prev=$_cur
        done
        printf '  %7.3fs  finish\n' "$((_end - _prev))"
        if [[ "${ZSH_STARTUP_PROFILE_ZPROF:-1}" != 0 ]] && (( $+builtins[zprof] )); then
            printf '\n-- zprof --\n'
            zprof
        fi
        printf '\n'
    } >>| "$_log_path"
}
