#!/usr/bin/env zsh
set -eo pipefail

repo_root="${0:A:h:h}"
source_file="${CLAUDE_SUB_SOURCE:-$repo_root/zsh/.zshrc.local.example}"
tmpdir="$(command mktemp -d)"
trap 'command rm -rf "$tmpdir"' EXIT

command mkdir -p "$tmpdir/bin" "$tmpdir/claude-config"

cat > "$tmpdir/bin/claude" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$CLAUDE_SUB_TEST_TMP/claude.args"
env > "$CLAUDE_SUB_TEST_TMP/claude.env"
EOF

cat > "$tmpdir/bin/op" <<'EOF'
#!/bin/sh
printf 'test-oauth-token'
EOF

command chmod +x "$tmpdir/bin/claude" "$tmpdir/bin/op"

export CLAUDE_SUB_TEST_TMP="$tmpdir"
export PATH="$tmpdir/bin:$PATH"
export OP_BIN="$tmpdir/bin/op"
export CLAUDE_CONFIG_DIR="$tmpdir/claude-config"
export CLAUDE_SUB_OAUTH_TOKEN_OP_REF="op://Test/Claude/oauth"
export ANTHROPIC_AUTH_TOKEN="wrong-provider-token"
export ANTHROPIC_API_KEY="wrong-provider-key"
export ANTHROPIC_BASE_URL="http://127.0.0.1:1"

source "$source_file"

claude-sub --model sonnet

if ! command grep -qx -- '--setting-sources' "$tmpdir/claude.args" \
  || ! command grep -qx -- 'project,local' "$tmpdir/claude.args"; then
  print "claude-sub did not exclude user settings" >&2
  exit 1
fi

if command grep -q 'apiKeyHelper' "$tmpdir/claude.args"; then
  print "claude-sub passed an apiKeyHelper override" >&2
  exit 1
fi

for name in ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_BASE_URL; do
  if command grep -q "^${name}=" "$tmpdir/claude.env"; then
    print "claude-sub leaked ${name}" >&2
    exit 1
  fi
done

if ! command grep -qx "CLAUDE_CONFIG_DIR=$tmpdir/claude-config" "$tmpdir/claude.env"; then
  print "claude-sub changed CLAUDE_CONFIG_DIR instead of sharing sessions" >&2
  exit 1
fi

claude-sub -p 'test prompt'

if ! command grep -qx 'CLAUDE_CODE_OAUTH_TOKEN=test-oauth-token' "$tmpdir/claude.env"; then
  print "claude-sub print mode did not inject the subscription OAuth token" >&2
  exit 1
fi

print "ok"
