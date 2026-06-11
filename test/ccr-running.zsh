#!/usr/bin/env zsh
set -eo pipefail

repo_root="${0:A:h:h}"
tmp_zdotdir="$(command mktemp -d)"
trap 'command rm -rf "$tmp_zdotdir"' EXIT

export CLAUDE_CODE_AGENT_ID=""
export ZDOTDIR="$tmp_zdotdir"
source "$repo_root/zsh/.zshrc"

export CCR_HEALTH_URL="http://127.0.0.1:65534/health"

if ! command ccr status | command grep -q "Status: Not Running"; then
  print "skip: CCR is already running"
  exit 0
fi

if _ccr_running; then
  print "_ccr_running returned true for a stopped CCR service" >&2
  exit 1
fi

print "ok"
