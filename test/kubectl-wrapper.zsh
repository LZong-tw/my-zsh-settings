#!/usr/bin/env zsh
set -euo pipefail

repo_root="${0:A:h:h}"

zsh -fc '
  source "$1" >/dev/null 2>&1
  if (( $+functions[kubectl] )); then
    print -u2 "kubectl wrapper should not load in non-interactive shells"
    exit 1
  fi
' zsh "$repo_root/zsh/.zshrc"

zsh -ic '
  source "$1" >/dev/null 2>&1
  (( $+functions[kubectl] )) || {
    print -u2 "kubectl wrapper should load in interactive shells"
    exit 1
  }
' zsh "$repo_root/zsh/.zshrc"
