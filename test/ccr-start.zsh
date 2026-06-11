#!/usr/bin/env zsh
set -eo pipefail

repo_root="${0:A:h:h}"
original_path="$PATH"
tmpdir="$(command mktemp -d)"
trap 'command rm -rf "$tmpdir"' EXIT

command mkdir -p "$tmpdir/bin" "$tmpdir/home" "$tmpdir/zdotdir"

cat > "$tmpdir/bin/op" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$AIRKIT_TEST_TMP/op.args"
if [ "$1" = "read" ]; then
  printf 'test-token'
  exit 0
fi
exit 42
EOF

cat > "$tmpdir/bin/ccr" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$AIRKIT_TEST_TMP/ccr.args"
printf '%s\n' "$ANTHROPIC_AUTH_TOKEN" > "$AIRKIT_TEST_TMP/ccr.token"
exit 0
EOF

command chmod +x "$tmpdir/bin/op" "$tmpdir/bin/ccr"

export AIRKIT_TEST_TMP="$tmpdir"
export CLAUDE_CODE_AGENT_ID=""
export HOME="$tmpdir/home"
export ZDOTDIR="$tmpdir/zdotdir"
export PATH="$tmpdir/bin:$original_path"
export CCR_ANTHROPIC_AUTH_TOKEN_OP_REF="op://Test/API/token"

set +e
source "$repo_root/zsh/.zshrc"
set -e

if ! typeset -f ccr-start >/dev/null; then
  print "ccr-start was not loaded" >&2
  exit 1
fi

ccr-start

if [[ "$(< "$tmpdir/op.args")" != $'read\nop://Test/API/token\n--no-newline' ]]; then
  print "ccr-start did not read the token via op read" >&2
  exit 1
fi

if [[ "$(< "$tmpdir/ccr.args")" != "restart" ]]; then
  print "ccr-start did not invoke ccr restart" >&2
  exit 1
fi

if [[ "$(< "$tmpdir/ccr.token")" != "test-token" ]]; then
  print "ccr-start did not pass the resolved token to ccr" >&2
  exit 1
fi

print "ok"
