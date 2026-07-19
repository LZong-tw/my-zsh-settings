#!/usr/bin/env zsh
set -eo pipefail

# Locks the plain `claude` wrapper to the direct company-gateway design:
# native Anthropic wire to ANTHROPIC_BASE_URL_DEFAULT with the litellm token
# resolved command-scoped, never the local CCR gateway. Only airclaude uses CCR.

repo_root="${0:A:h:h}"
source_file="${CLAUDE_SOURCE:-$repo_root/zsh/.zshrc}"
tmpdir="$(command mktemp -d)"
trap 'command rm -rf "$tmpdir"' EXIT

command mkdir -p "$tmpdir/bin" "$tmpdir/claude-home/.claude"

cat > "$tmpdir/bin/claude" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$CLAUDE_TEST_TMP/claude.args"
env > "$CLAUDE_TEST_TMP/claude.env"
EOF
command chmod +x "$tmpdir/bin/claude"

# Stands in for ~/.claude/api-key-helper.sh (op read of the litellm key).
cat > "$tmpdir/claude-home/.claude/api-key-helper.sh" <<'EOF'
#!/bin/sh
printf 'company-litellm-token'
EOF
command chmod +x "$tmpdir/claude-home/.claude/api-key-helper.sh"

export CLAUDE_TEST_TMP="$tmpdir"
export HOME="$tmpdir/claude-home"
export PATH="$tmpdir/bin:$PATH"
export ANTHROPIC_BASE_URL_DEFAULT="https://llm-gateway.example-company.internal"
export ANTHROPIC_BASE_URL="$ANTHROPIC_BASE_URL_DEFAULT"
export ANTHROPIC_AUTH_TOKEN_OP_REF="op://Test/CLI/anthropic_auth_token"

# Stale CCR-gateway env that must NOT reach plain claude.
export ANTHROPIC_API_KEY="stale-gateway-key"
export ANTHROPIC_API_BASE_URL="http://127.0.0.1:3456"
export CLAUDE_AGENT_API_BASE_URL="http://127.0.0.1:3456"
export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY="1"

# Load only the claude() function out of the full .zshrc.
eval "$(command sed -n '/^claude() {/,/^}/p' "$source_file")"
typeset -f claude >/dev/null || { print "claude() not found in $source_file" >&2; exit 1; }

claude --model sonnet

# Auth: the company litellm token from the helper reaches ANTHROPIC_AUTH_TOKEN.
if ! command grep -qx 'ANTHROPIC_AUTH_TOKEN=company-litellm-token' "$tmpdir/claude.env"; then
  print "claude did not resolve the company litellm token" >&2
  exit 1
fi

# Base URL: the company gateway, never the local CCR gateway.
if ! command grep -qx "ANTHROPIC_BASE_URL=$ANTHROPIC_BASE_URL_DEFAULT" "$tmpdir/claude.env"; then
  print "claude did not point ANTHROPIC_BASE_URL at the company gateway" >&2
  exit 1
fi
if command grep -q '127.0.0.1:3456' "$tmpdir/claude.env"; then
  print "claude leaked the local CCR gateway into its env" >&2
  exit 1
fi

# Stale CCR-gateway env must be stripped.
for name in ANTHROPIC_API_KEY ANTHROPIC_API_BASE_URL CLAUDE_AGENT_API_BASE_URL CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY; do
  if command grep -q "^${name}=" "$tmpdir/claude.env"; then
    print "claude did not strip ${name}" >&2
    exit 1
  fi
done

# User arguments forwarded.
if ! command grep -qx -- '--model' "$tmpdir/claude.args" \
  || ! command grep -qx -- 'sonnet' "$tmpdir/claude.args"; then
  print "claude dropped user arguments" >&2
  exit 1
fi

print "ok"
