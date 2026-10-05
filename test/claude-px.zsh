#!/usr/bin/env zsh
set -eo pipefail

# Locks claude-px to `pxpipe warp -- claude` with no provider override in the
# env (a set ANTHROPIC_BASE_URL turns off /remote-control), and to refusing to
# launch when the pxpipe proxy is down instead of starting a dead session.

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

# Proxy reachability is whatever CURL_TEST_EXIT says.
cat > "$tmpdir/bin/curl" <<'EOF'
#!/bin/sh
exit "${CURL_TEST_EXIT:-0}"
EOF

# The registry has a newer pxpipe than the installed 1.0.0.
cat > "$tmpdir/bin/npm" <<'EOF'
#!/bin/sh
[ "$1" = view ] && { echo 1.1.0; exit 0; }
printf '%s\n' "$@" > "$CLAUDE_TEST_TMP/npm.args"
EOF
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

eval "$(command sed -n '/^claude-px() {/,/^}/p' "$source_file")"
typeset -f claude-px >/dev/null || { print "claude-px() not found in $source_file" >&2; exit 1; }

claude-px remote-control --name demo

# Background upgrade into the prefix pxpipe was installed under.
for _ in {1..50}; do [[ -e "$tmpdir/npm.args" ]] && break; sleep 0.1; done
expected_npm=(i -g --prefix "$tmpdir" pxpipe-proxy@latest --no-audit --no-fund)
if [[ ! -e "$tmpdir/npm.args" || "$(< "$tmpdir/npm.args")" != "${(F)expected_npm}" ]]; then
  print "claude-px did not upgrade pxpipe in its own prefix" >&2
  exit 1
fi

expected=(warp -- claude remote-control --name demo)
if [[ "$(< "$tmpdir/pxpipe.args")" != "${(F)expected}" ]]; then
  print "claude-px did not run: pxpipe ${expected[*]}" >&2
  print "got: $(< "$tmpdir/pxpipe.args")" >&2
  exit 1
fi

for name in ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_API_BASE_URL CLAUDE_AGENT_API_BASE_URL; do
  if command grep -q "^${name}=" "$tmpdir/pxpipe.env"; then
    print "claude-px leaked ${name} into warp" >&2
    exit 1
  fi
done

# Proxy down: fail fast, never launch warp.
command rm -f "$tmpdir/pxpipe.args"
if CURL_TEST_EXIT=7 claude-px -p hi 2>/dev/null; then
  print "claude-px succeeded with the proxy down" >&2
  exit 1
fi
if [[ -e "$tmpdir/pxpipe.args" ]]; then
  print "claude-px launched warp with the proxy down" >&2
  exit 1
fi

print "ok"
