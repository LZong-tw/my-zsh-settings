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

# CCR routing env as the AirKit snippet exports it for plain `claude`.
export ANTHROPIC_AUTH_TOKEN="wrong-provider-token"
export ANTHROPIC_API_KEY="wrong-provider-key"
export ANTHROPIC_BASE_URL="http://127.0.0.1:1"
export ANTHROPIC_API_BASE_URL="http://127.0.0.1:1"
export CLAUDE_AGENT_API_BASE_URL="http://127.0.0.1:1"

routing_vars=(
  ANTHROPIC_AUTH_TOKEN
  ANTHROPIC_API_KEY
  ANTHROPIC_BASE_URL
  ANTHROPIC_API_BASE_URL
  CLAUDE_AGENT_API_BASE_URL
)

source "$source_file"

claude-sub --model sonnet

# Full user scope must load: no --setting-sources and no --settings override.
if command grep -q -- '^--setting' "$tmpdir/claude.args"; then
  print "claude-sub restricted setting sources or injected --settings" >&2
  exit 1
fi

if ! command grep -qx -- '--model' "$tmpdir/claude.args" \
  || ! command grep -qx -- 'sonnet' "$tmpdir/claude.args"; then
  print "claude-sub dropped user arguments" >&2
  exit 1
fi

for name in $routing_vars; do
  if command grep -q "^${name}=" "$tmpdir/claude.env"; then
    print "claude-sub leaked ${name}" >&2
    exit 1
  fi
done

if ! command grep -qx "CLAUDE_CONFIG_DIR=$tmpdir/claude-config" "$tmpdir/claude.env"; then
  print "claude-sub changed CLAUDE_CONFIG_DIR instead of sharing sessions" >&2
  exit 1
fi

# Interactive mode must rely on keychain OAuth, not a token injection.
if command grep -q '^CLAUDE_CODE_OAUTH_TOKEN=' "$tmpdir/claude.env"; then
  print "claude-sub interactive mode injected CLAUDE_CODE_OAUTH_TOKEN" >&2
  exit 1
fi

# Subprocess env scrub must stay disabled so Git/SSH tools keep SSH_AUTH_SOCK.
if ! command grep -qx 'CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=0' "$tmpdir/claude.env"; then
  print "claude-sub dropped CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=0" >&2
  exit 1
fi

claude-sub -p 'test prompt'

if ! command grep -qx 'CLAUDE_CODE_OAUTH_TOKEN=test-oauth-token' "$tmpdir/claude.env"; then
  print "claude-sub print mode did not inject the subscription OAuth token" >&2
  exit 1
fi

for name in $routing_vars; do
  if command grep -q "^${name}=" "$tmpdir/claude.env"; then
    print "claude-sub -p leaked ${name}" >&2
    exit 1
  fi
done

# hr-claude-sub ships commented out; define it from the template block.
eval "$(command sed -n '/^# hr-claude-sub()/,/^# }/p' "$source_file" | command sed 's/^# \{0,1\}//')"
if ! typeset -f hr-claude-sub >/dev/null; then
  print "hr-claude-sub block not found in the example" >&2
  exit 1
fi
_HR_PORT_SUB=8801
_hr_proxy() { return 0; }

hr-claude-sub --model sonnet

if command grep -q -- '^--setting' "$tmpdir/claude.args"; then
  print "hr-claude-sub restricted setting sources or injected --settings" >&2
  exit 1
fi

for name in ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_API_BASE_URL CLAUDE_AGENT_API_BASE_URL; do
  if command grep -q "^${name}=" "$tmpdir/claude.env"; then
    print "hr-claude-sub leaked ${name}" >&2
    exit 1
  fi
done

if ! command grep -qx "ANTHROPIC_BASE_URL=http://127.0.0.1:$_HR_PORT_SUB" "$tmpdir/claude.env"; then
  print "hr-claude-sub did not route ANTHROPIC_BASE_URL through the local proxy" >&2
  exit 1
fi

if ! command grep -qx "CLAUDE_CONFIG_DIR=$tmpdir/claude-config" "$tmpdir/claude.env"; then
  print "hr-claude-sub changed CLAUDE_CONFIG_DIR instead of sharing sessions" >&2
  exit 1
fi

print "ok"
