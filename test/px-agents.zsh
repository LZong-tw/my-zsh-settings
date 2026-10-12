#!/usr/bin/env zsh
set -eo pipefail

# Locks omp-px / agy-px / grok-px / cursor-px to the same warp contract as
# claude-px: no provider override in the env, refuse to launch when the proxy
# is down, and refuse before warp when the agent binary is missing.

repo_root="${0:A:h:h}"
source_file="${CLAUDE_SOURCE:-$repo_root/zsh/.zshrc}"
tmpdir="$(command mktemp -d)"
trap 'command rm -rf "$tmpdir"' EXIT

command mkdir -p "$tmpdir/bin"

cat > "$tmpdir/bin/pxpipe" <<'EOF'
#!/bin/sh
[ "$1" = --version ] && { echo 1.0.0; exit 0; }
printf '%s\n' "$@" > "$CLAUDE_TEST_TMP/pxpipe.args"
env > "$CLAUDE_TEST_TMP/pxpipe.env"
EOF

cat > "$tmpdir/bin/curl" <<'EOF'
#!/bin/sh
exit "${CURL_TEST_EXIT:-0}"
EOF

cat > "$tmpdir/bin/npm" <<'EOF'
#!/bin/sh
[ "$1" = view ] && { echo 1.1.0; exit 0; }
printf '%s\n' "$@" > "$CLAUDE_TEST_TMP/npm.args"
EOF

for _cmd in grok cursor-agent; do
  cat > "$tmpdir/bin/$_cmd" <<'EOF'
#!/bin/sh
echo should-not-run >&2
exit 99
EOF
  command chmod +x "$tmpdir/bin/$_cmd"
done
command chmod +x "$tmpdir/bin/pxpipe" "$tmpdir/bin/curl" "$tmpdir/bin/npm"

export CLAUDE_TEST_TMP="$tmpdir"
export HOME="$tmpdir"
export PATH="$tmpdir/bin:$PATH"
rehash

export ANTHROPIC_BASE_URL="http://127.0.0.1:47821"
export ANTHROPIC_AUTH_TOKEN="company-litellm-token"
export ANTHROPIC_API_KEY="stale-gateway-key"
export ANTHROPIC_API_BASE_URL="http://127.0.0.1:3456"
export CLAUDE_AGENT_API_BASE_URL="http://127.0.0.1:3456"

eval "$(command sed -n '/^_pxpipe_warp() {/,/^cursor-px()/p' "$source_file")"
typeset -f _pxpipe_warp grok-px cursor-px omp-px agy-px >/dev/null \
  || { print "px agent functions not found in $source_file" >&2; exit 1; }

grok-px --version

for _ in {1..50}; do [[ -e "$tmpdir/npm.args" ]] && break; sleep 0.1; done
expected_npm=(i -g --prefix "$tmpdir" pxpipe-proxy@latest --no-audit --no-fund)
if [[ ! -e "$tmpdir/npm.args" || "$(< "$tmpdir/npm.args")" != "${(F)expected_npm}" ]]; then
  print "grok-px did not upgrade pxpipe in its own prefix" >&2
  exit 1
fi

expected=(warp -- grok --version)
if [[ "$(< "$tmpdir/pxpipe.args")" != "${(F)expected}" ]]; then
  print "grok-px did not run: pxpipe ${expected[*]}" >&2
  print "got: $(< "$tmpdir/pxpipe.args")" >&2
  exit 1
fi

for name in ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_API_BASE_URL CLAUDE_AGENT_API_BASE_URL; do
  if command grep -q "^${name}=" "$tmpdir/pxpipe.env"; then
    print "grok-px leaked ${name} into warp" >&2
    exit 1
  fi
done

command rm -f "$tmpdir/pxpipe.args"
cursor-px -p 'hi there'
expected=(warp -- cursor-agent -p 'hi there')
if [[ "$(< "$tmpdir/pxpipe.args")" != "${(F)expected}" ]]; then
  print "cursor-px did not run: pxpipe ${expected[*]}" >&2
  print "got: $(< "$tmpdir/pxpipe.args")" >&2
  exit 1
fi

command rm -f "$tmpdir/pxpipe.args" "$tmpdir/npm.args"
if omp-px 2>/dev/null; then
  print "omp-px succeeded without an omp binary" >&2
  exit 1
fi
if [[ -e "$tmpdir/pxpipe.args" || -e "$tmpdir/npm.args" ]]; then
  print "omp-px launched warp or npm without an omp binary" >&2
  exit 1
fi

command rm -f "$tmpdir/pxpipe.args"
if CURL_TEST_EXIT=7 grok-px -p hi 2>/dev/null; then
  print "grok-px succeeded with the proxy down" >&2
  exit 1
fi
if [[ -e "$tmpdir/pxpipe.args" ]]; then
  print "grok-px launched warp with the proxy down" >&2
  exit 1
fi

print "ok"
