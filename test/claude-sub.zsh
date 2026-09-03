#!/usr/bin/env zsh
set -eo pipefail

repo_root="${0:A:h:h}"
source_file="${CLAUDE_SUB_SOURCE:-$repo_root/zsh/.zshrc.local.example}"
tmpdir="$(command mktemp -d)"
trap 'command rm -rf "$tmpdir"' EXIT

command mkdir -p "$tmpdir/bin" "$tmpdir/claude-config" "$tmpdir/audit-plugin/.claude-plugin"
command touch "$tmpdir/audit-plugin/.claude-plugin/plugin.json"

cat > "$tmpdir/bin/claude" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$CLAUDE_SUB_TEST_TMP/claude.args"
env > "$CLAUDE_SUB_TEST_TMP/claude.env"
EOF

cat > "$tmpdir/bin/op" <<'EOF'
#!/bin/sh
printf 'test-oauth-token'
EOF

cat > "$tmpdir/bin/airkit" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$CLAUDE_SUB_TEST_TMP/airkit.args"
env > "$CLAUDE_SUB_TEST_TMP/airkit.env"
if [ "${AIRKIT_SHIELD_TEST_FAIL:-0}" = "1" ]; then
  exit 42
fi
if [ "$1" != "shield" ] || [ "$2" != "launch" ] || [ "$3" != "--lane" ] \
  || [ "$4" != "subscription" ]; then
  exit 64
fi
shift 4
if [ "$1" = "--target" ]; then
  [ "$2" = "http://127.0.0.1:8801" ] || exit 64
  shift 2
fi
[ "$1" = "--" ] || exit 64
shift
ANTHROPIC_API_BASE_URL="http://127.0.0.1:8811" \
  ANTHROPIC_BASE_URL="http://127.0.0.1:8811" \
  ANTHROPIC_CUSTOM_HEADERS="x-airkit-shield: fixture-capability" \
  exec "$@"
EOF

command chmod +x "$tmpdir/bin/airkit" "$tmpdir/bin/claude" "$tmpdir/bin/op"

export CLAUDE_SUB_TEST_TMP="$tmpdir"
export PATH="$tmpdir/bin:$PATH"
export OP_BIN="$tmpdir/bin/op"
export CLAUDE_CONFIG_DIR="$tmpdir/claude-config"
export CLAUDE_SUB_OAUTH_TOKEN_OP_REF="op://Test/Claude/oauth"
export AIRKIT_AUDIT_PLUGIN_DIR="$tmpdir/audit-plugin"

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

if [[ -e "$tmpdir/airkit.args" ]]; then
  print "claude-sub routed the default feature-off path through Shield" >&2
  exit 1
fi

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

if ! command grep -qx -- '--plugin-dir' "$tmpdir/claude.args" \
  || ! command grep -qx -- "$AIRKIT_AUDIT_PLUGIN_DIR" "$tmpdir/claude.args"; then
  print "claude-sub did not attach the audit plugin" >&2
  exit 1
fi

if ! command grep -qx 'AIRKIT_AUDIT_ENABLED=1' "$tmpdir/claude.env"; then
  print "claude-sub did not enable audit-only hooks" >&2
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

command rm -f "$tmpdir/claude.args" "$tmpdir/claude.env" "$tmpdir/airkit.args" "$tmpdir/airkit.env"
airkit() {
  env > "$CLAUDE_SUB_TEST_TMP/airkit-shadow.env"
  command claude "$@"
}
set +e
AIRKIT_SHIELD_SUBSCRIPTION=1 AIRKIT_SHIELD_TEST_FAIL=1 claude-sub --model sonnet
shield_failure_status=$?
set -e

if [[ $shield_failure_status -ne 42 ]]; then
  print "claude-sub did not bypass a shadowing airkit function to return the Shield launch failure" >&2
  exit 1
fi
if [[ -e "$tmpdir/airkit-shadow.env" ]]; then
  print "claude-sub passed subscription OAuth through a shadowing airkit function" >&2
  exit 1
fi
if [[ -e "$tmpdir/claude.args" || -e "$tmpdir/claude.env" ]]; then
  print "claude-sub spawned Claude after Shield launch failed" >&2
  exit 1
fi

AIRKIT_SHIELD_SUBSCRIPTION=1 AIRKIT_SHIELD_TEST_FAIL=0 claude-sub -p 'shielded prompt'

expected_shield_args=(
  shield
  launch
  --lane
  subscription
  --
  "$tmpdir/bin/claude"
  --plugin-dir
  "$AIRKIT_AUDIT_PLUGIN_DIR"
  -p
  'shielded prompt'
)
if [[ "$(<"$tmpdir/airkit.args")" != "${(F)expected_shield_args}" ]]; then
  print "claude-sub did not preserve the Shield launch argv boundary" >&2
  exit 1
fi

if ! command grep -qx 'CLAUDE_CODE_OAUTH_TOKEN=test-oauth-token' "$tmpdir/claude.env"; then
  print "shielded claude-sub print mode did not preserve subscription OAuth" >&2
  exit 1
fi
for name in ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY CLAUDE_AGENT_API_BASE_URL; do
  if command grep -q "^${name}=" "$tmpdir/airkit.env" \
    || command grep -q "^${name}=" "$tmpdir/claude.env"; then
    print "shielded claude-sub leaked ${name}" >&2
    exit 1
  fi
done
for name in ANTHROPIC_BASE_URL ANTHROPIC_API_BASE_URL ANTHROPIC_CUSTOM_HEADERS; do
  if command grep -q "^${name}=" "$tmpdir/airkit.env"; then
    print "claude-sub leaked inherited ${name} before AirKit Shield injection" >&2
    exit 1
  fi
done
if ! command grep -qx 'ANTHROPIC_BASE_URL=http://127.0.0.1:8811' "$tmpdir/claude.env" \
  || ! command grep -qx 'ANTHROPIC_API_BASE_URL=http://127.0.0.1:8811' "$tmpdir/claude.env" \
  || ! command grep -qx 'ANTHROPIC_CUSTOM_HEADERS=x-airkit-shield: fixture-capability' "$tmpdir/claude.env"; then
  print "shielded claude-sub did not preserve AirKit's child-only Shield transport" >&2
  exit 1
fi

# hr-claude-sub ships commented out; define it from the template block.
eval "$(command sed -n '/^# hr-claude-sub()/,/^# }/p' "$source_file" | command sed 's/^# \{0,1\}//')"
if ! typeset -f hr-claude-sub >/dev/null; then
  print "hr-claude-sub block not found in the example" >&2
  exit 1
fi
_HR_PORT_SUB=8801
_hr_proxy() {
  print "$*" >> "$CLAUDE_SUB_TEST_TMP/hr-proxy.args"
  return 0
}
export AIRKIT_SHIELD_CONTROL_CAPABILITY="stale-control-capability"
export AIRKIT_SHIELD_APPROVAL_CAPABILITY="stale-approval-capability"
export AIRKIT_SHIELD_APPROVAL_SOCKET="/tmp/stale-approval.sock"
export AIRKIT_SHIELD_CAPABILITY="stale-request-capability"

command rm -f "$tmpdir/airkit.args" "$tmpdir/airkit.env" "$tmpdir/claude.args" "$tmpdir/claude.env"
hr-claude-sub --model sonnet

if [[ -e "$tmpdir/airkit.args" || -e "$tmpdir/airkit.env" ]]; then
  print "hr-claude-sub claimed Shield coverage while bypassing it" >&2
  exit 1
fi

if command grep -q -- '^--setting' "$tmpdir/claude.args"; then
  print "hr-claude-sub restricted setting sources or injected --settings" >&2
  exit 1
fi

for name in ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_API_BASE_URL CLAUDE_AGENT_API_BASE_URL AIRKIT_SHIELD_CONTROL_CAPABILITY AIRKIT_SHIELD_APPROVAL_CAPABILITY AIRKIT_SHIELD_APPROVAL_SOCKET AIRKIT_SHIELD_CAPABILITY; do
  if command grep -q "^${name}=" "$tmpdir/claude.env"; then
    print "hr-claude-sub leaked ${name}" >&2
    exit 1
  fi
done

if ! command grep -qx "ANTHROPIC_BASE_URL=http://127.0.0.1:$_HR_PORT_SUB" "$tmpdir/claude.env"; then
  print "hr-claude-sub did not route ANTHROPIC_BASE_URL through the local proxy" >&2
  exit 1
fi

if command grep -q '^ANTHROPIC_CUSTOM_HEADERS=' "$tmpdir/claude.env"; then
  print "hr-claude-sub retained a Shield capability header on its bypass route" >&2
  exit 1
fi

if ! command grep -qx "CLAUDE_CONFIG_DIR=$tmpdir/claude-config" "$tmpdir/claude.env"; then
  print "hr-claude-sub changed CLAUDE_CONFIG_DIR instead of sharing sessions" >&2
  exit 1
fi

if ! command grep -qx 'AIRKIT_SHIELD_BYPASS_REASON=zsh_direct_subscription' "$tmpdir/claude.env"; then
  print "hr-claude-sub did not declare its Shield bypass disposition" >&2
  exit 1
fi

command rm -f "$tmpdir/airkit.args" "$tmpdir/airkit.env" "$tmpdir/claude.args" "$tmpdir/claude.env" "$tmpdir/hr-proxy.args"
AIRKIT_SHIELD_SUBSCRIPTION=1 hr-claude-sub --model sonnet

expected_headroom_shield_args=(
  shield
  launch
  --lane
  subscription
  --target
  "http://127.0.0.1:$_HR_PORT_SUB"
  --
  "$tmpdir/bin/claude"
  --plugin-dir
  "$AIRKIT_AUDIT_PLUGIN_DIR"
  --model
  sonnet
)
if [[ "$(<"$tmpdir/airkit.args")" != "${(F)expected_headroom_shield_args}" ]]; then
  print "shielded hr-claude-sub did not preserve the Headroom destination lease argv boundary" >&2
  exit 1
fi

if [[ "$(<"$tmpdir/hr-proxy.args")" != "$_HR_PORT_SUB   cache 1" ]]; then
  print "shielded hr-claude-sub did not start the subscription Headroom proxy" >&2
  exit 1
fi

for name in ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_BASE_URL ANTHROPIC_API_BASE_URL ANTHROPIC_CUSTOM_HEADERS CLAUDE_AGENT_API_BASE_URL AIRKIT_SHIELD_BYPASS_REASON AIRKIT_SHIELD_CONTROL_CAPABILITY AIRKIT_SHIELD_APPROVAL_CAPABILITY AIRKIT_SHIELD_APPROVAL_SOCKET AIRKIT_SHIELD_CAPABILITY; do
  if command grep -q "^${name}=" "$tmpdir/airkit.env"; then
    print "shielded hr-claude-sub leaked ${name} into the Shield launcher" >&2
    exit 1
  fi
done

if command grep -q "^ANTHROPIC_BASE_URL=http://127.0.0.1:$_HR_PORT_SUB$" "$tmpdir/claude.env"; then
  print "shielded hr-claude-sub leaked the Headroom destination into the Claude child" >&2
  exit 1
fi
for name in ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY CLAUDE_AGENT_API_BASE_URL AIRKIT_SHIELD_BYPASS_REASON AIRKIT_SHIELD_CONTROL_CAPABILITY AIRKIT_SHIELD_APPROVAL_CAPABILITY AIRKIT_SHIELD_APPROVAL_SOCKET AIRKIT_SHIELD_CAPABILITY; do
  if command grep -q "^${name}=" "$tmpdir/claude.env"; then
    print "shielded hr-claude-sub leaked ${name} into the Claude child" >&2
    exit 1
  fi
done
if ! command grep -qx 'ANTHROPIC_BASE_URL=http://127.0.0.1:8811' "$tmpdir/claude.env" \
  || ! command grep -qx 'ANTHROPIC_API_BASE_URL=http://127.0.0.1:8811' "$tmpdir/claude.env" \
  || ! command grep -qx 'ANTHROPIC_CUSTOM_HEADERS=x-airkit-shield: fixture-capability' "$tmpdir/claude.env"; then
  print "shielded hr-claude-sub did not preserve AirKit's child-only Shield transport" >&2
  exit 1
fi
if command grep -q -- '--target\|127\.0\.0\.1:8801' "$tmpdir/claude.args"; then
  print "shielded hr-claude-sub leaked the destination lease into the Claude argv" >&2
  exit 1
fi

command rm -f "$tmpdir/airkit.args" "$tmpdir/airkit.env" "$tmpdir/claude.args" "$tmpdir/claude.env"
set +e
AIRKIT_SHIELD_SUBSCRIPTION=1 AIRKIT_SHIELD_TEST_FAIL=1 hr-claude-sub --model sonnet
headroom_shield_failure_status=$?
set -e
if [[ $headroom_shield_failure_status -ne 42 || -e "$tmpdir/claude.args" || -e "$tmpdir/claude.env" ]]; then
  print "shielded hr-claude-sub did not fail closed before starting Claude" >&2
  exit 1
fi

print "ok"
