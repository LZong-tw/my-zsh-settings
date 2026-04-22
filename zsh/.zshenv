
alias assume=". assume"
[[ -r "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
[[ -r "${ZDOTDIR:-$HOME}/.zshenv.local" ]] && . "${ZDOTDIR:-$HOME}/.zshenv.local"
