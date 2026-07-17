#!/bin/sh
# Apply the repo's claude-sub / hr-claude-sub rewrite to the live shell config
# and drop the obsolete apiKeyHelper from Claude settings. Backup-first.
#
# Usage:
#   sh scripts/apply-claude-sub.sh            # apply
#   DRY_RUN=1 sh scripts/apply-claude-sub.sh  # show what would change, write nothing
#
# What it does:
# 1. Replaces the claude-sub() function in ~/.zshrc.local with the version
#    from zsh/.zshrc.local.example (loads full user scope; unsets the AirKit
#    snippet's CCR routing env instead of excluding user settings).
# 2. Replaces the active hr-claude-sub() function the same way, using the
#    uncommented template from the example (skipped when not present).
# 3. Removes the "apiKeyHelper" key from ~/.claude/settings.json — it is the
#    pre-CCR relic; the company line reads its token from the sourced snippet
#    and the subscription uses keychain OAuth, so the helper only produces
#    noisy failures and auth-precedence surprises.
# Every touched file gets a timestamped backup next to it first.
set -eu

REPO="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 - "$REPO" <<'PY'
import difflib, json, os, re, shutil, sys, time

repo = sys.argv[1]
dry = os.environ.get("DRY_RUN") == "1"
ts = time.strftime("%Y%m%dT%H%M%S")
example_path = os.path.join(repo, "zsh", ".zshrc.local.example")
live_path = os.path.expanduser("~/.zshrc.local")
settings_path = os.path.expanduser("~/.claude/settings.json")

def fail(msg):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)

def extract_function(lines, header_re, stop_re, strip_comment=False):
    start = next((i for i, l in enumerate(lines) if re.match(header_re, l)), None)
    if start is None:
        return None, None, None
    end = next((i for i in range(start + 1, len(lines)) if re.match(stop_re, lines[i])), None)
    if end is None:
        fail(f"unterminated block starting at line {start + 1}")
    block = lines[start:end + 1]
    if strip_comment:
        block = [re.sub(r"^# ?", "", l) for l in block]
    return start, end, block

example = open(example_path).read().splitlines(keepends=False)
live = open(live_path).read().splitlines(keepends=False)
original_live = list(live)

_, _, new_claude_sub = extract_function(example, r"^claude-sub\(\) \{", r"^\}")
if not new_claude_sub:
    fail("claude-sub() not found in the repo example")
_, _, new_hr = extract_function(example, r"^# hr-claude-sub\(\) \{", r"^# \}", strip_comment=True)

changes = []

s, e, _ = extract_function(live, r"^claude-sub\(\) \{", r"^\}")
if s is None:
    fail("claude-sub() not found in ~/.zshrc.local")
live[s:e + 1] = new_claude_sub
changes.append(f"claude-sub() replaced (lines {s + 1}-{e + 1})")

s, e, _ = extract_function(live, r"^hr-claude-sub\(\) \{", r"^\}")
if s is not None:
    if not new_hr:
        fail("live hr-claude-sub() exists but the example has no template for it")
    live[s:e + 1] = new_hr
    changes.append(f"hr-claude-sub() replaced (lines {s + 1}-{e + 1})")
else:
    changes.append("hr-claude-sub() not active in ~/.zshrc.local; skipped")

leftover = [i + 1 for i, l in enumerate(live) if "--setting-sources" in l and not l.lstrip().startswith("#")]
if leftover:
    fail(f"--setting-sources still present after replacement at lines {leftover}; aborting")

settings = json.load(open(settings_path))
if "apiKeyHelper" in settings:
    removed = settings.pop("apiKeyHelper")
    changes.append(f"settings.json: removed apiKeyHelper ({removed})")
else:
    changes.append("settings.json: apiKeyHelper already absent")

diff = list(difflib.unified_diff(original_live, live, "zshrc.local (before)", "zshrc.local (after)", lineterm=""))
print("\n".join(changes))
print(f"\n--- ~/.zshrc.local diff: {sum(1 for l in diff if l.startswith('-') and not l.startswith('---'))} removed, "
      f"{sum(1 for l in diff if l.startswith('+') and not l.startswith('+++'))} added lines")
for line in diff[:80]:
    print(line)
if len(diff) > 80:
    print(f"... ({len(diff) - 80} more diff lines)")

if dry:
    print("\nDRY_RUN=1 — nothing written.")
    sys.exit(0)

shutil.copy2(live_path, f"{live_path}.pre-claude-sub-{ts}")
shutil.copy2(settings_path, f"{settings_path}.pre-claude-sub-{ts}")
with open(live_path, "w") as f:
    f.write("\n".join(live) + "\n")
with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write("\n")

print(f"\nBackups: {live_path}.pre-claude-sub-{ts}")
print(f"         {settings_path}.pre-claude-sub-{ts}")
print("\nNext steps:")
print("  source ~/.zshrc.local")
print("  source ~/.config/ai-runtime-kit/shell/oneportal-lowcost.zsh")
print("  # exit any Claude processes started before this change; they keep the old function in memory")
PY
