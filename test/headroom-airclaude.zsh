#!/usr/bin/env zsh
set -eo pipefail

repo_root="${0:A:h:h}"
source_file="${AIRKIT_LOCAL_SOURCE:-$repo_root/zsh/.zshrc.local.example}"
tmpdir="$(command mktemp -d)"
trap 'command rm -rf "$tmpdir"' EXIT

command mkdir -p "$tmpdir/bin"
cat > "$tmpdir/bin/airclaude" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" > "$HEADROOM_AIRCLAUDE_TEST_TMP/airclaude.args"
env > "$HEADROOM_AIRCLAUDE_TEST_TMP/airclaude.env"
EOF
cat > "$tmpdir/bin/ccr" <<'EOF'
#!/bin/sh
exit 0
EOF
command chmod +x "$tmpdir/bin/airclaude" "$tmpdir/bin/ccr"

export HEADROOM_AIRCLAUDE_TEST_TMP="$tmpdir"
export PATH="$tmpdir/bin:$PATH"
export ANTHROPIC_AUTH_TOKEN="wrong-provider-token"
export ANTHROPIC_API_KEY="wrong-provider-key"
export ANTHROPIC_BASE_URL="http://127.0.0.1:1"
export ANTHROPIC_API_BASE_URL="http://127.0.0.1:1"
export CLAUDE_AGENT_API_BASE_URL="http://127.0.0.1:1"
export ANTHROPIC_CUSTOM_HEADERS="x-airkit-shield: stale-capability"
export AIRKIT_SHIELD_BYPASS_REASON="stale-bypass"

eval "$(command sed -n '/^# hr-claude-web()/,/^# }/p' "$source_file" | command sed 's/^# \{0,1\}//')"
eval "$(command sed -n '/^# hr-airclaude()/,/^# }/p' "$source_file" | command sed 's/^# \{0,1\}//')"
typeset -f hr-claude-web >/dev/null || { print "hr-claude-web block not found" >&2; exit 1; }
typeset -f hr-airclaude >/dev/null || { print "hr-airclaude block not found" >&2; exit 1; }

_HR_PORT_WEB=8803
_HR_PORT_AIR=8804
_hr_require() { return 0; }
_hr_proxy() { return 0; }

assert_no_direct_route_or_credential() {
  local name
  for name in ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_BASE_URL ANTHROPIC_API_BASE_URL CLAUDE_AGENT_API_BASE_URL ANTHROPIC_CUSTOM_HEADERS AIRKIT_SHIELD_BYPASS_REASON; do
    if command grep -q "^${name}=" "$tmpdir/airclaude.env"; then
      print "Headroom AirClaude wrapper leaked ${name}" >&2
      exit 1
    fi
  done
}

hr-claude-web --model sonnet
expected_web_args=(--profile oneportal-lowcost --mode web -- --model sonnet)
if [[ "$(<"$tmpdir/airclaude.args")" != "${(F)expected_web_args}" ]]; then
  print "hr-claude-web did not preserve the managed AirClaude launch argv" >&2
  exit 1
fi
if ! command grep -qx "AIRCLAUDE_ANTHROPIC_PROVIDER_BASE_URL=http://127.0.0.1:$_HR_PORT_WEB/v1/messages" "$tmpdir/airclaude.env"; then
  print "hr-claude-web did not preserve its Headroom provider override" >&2
  exit 1
fi
assert_no_direct_route_or_credential

command rm -f "$tmpdir/airclaude.args" "$tmpdir/airclaude.env"
hr-airclaude --model opus
expected_air_args=(--model opus)
if [[ "$(<"$tmpdir/airclaude.args")" != "${(F)expected_air_args}" ]]; then
  print "hr-airclaude did not preserve the managed AirClaude launch argv" >&2
  exit 1
fi
if ! command grep -qx "AIRCLAUDE_PROVIDER_BASE_URL=http://127.0.0.1:$_HR_PORT_AIR/v1/chat/completions" "$tmpdir/airclaude.env"; then
  print "hr-airclaude did not preserve its Headroom provider override" >&2
  exit 1
fi
assert_no_direct_route_or_credential

print "ok"
