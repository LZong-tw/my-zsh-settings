# Claude Code and tmux -CC

This repo keeps Claude-related shell behavior in `zsh/.zshrc`, but leaves credentials and machine-specific wiring in local files.

## What belongs in git
- `zsh/.zshrc`
- `zsh/.zshrc.local.example`
- `examples/claude-api-key-helper.sh.example`
- docs such as this file

## What stays local
- `~/.zshrc.local`
- `~/.claude/settings.local.json` or `~/.claude/settings.json`
- `~/.claude/api-key-helper.sh`
- any raw tokens, 1Password item paths, or company-only endpoints you do not want in git

## Recommended local setup
1. Copy `zsh/.zshrc.local.example` to `~/.zshrc.local` and fill in your real values.
2. Copy `examples/claude-api-key-helper.sh.example` to `~/.claude/api-key-helper.sh` and `chmod 755` it.
3. Add an `apiKeyHelper` entry to your Claude Code local settings.
4. For multiple Anthropic keys, keep each key in 1Password and add wrapper functions such as `claude-jbridge` with a short alias like `claude-jb` in `~/.zshrc.local`; when keys come from different platforms, switch or unset `ANTHROPIC_BASE_URL` with the key.
5. Pin `ANTHROPIC_DEFAULT_OPUS_MODEL` and `ANTHROPIC_DEFAULT_SONNET_MODEL` inside provider wrappers to the model ids accepted by Claude Code. For JBridge, keep aliases such as `claude-opus-4-7[1m]` in the wrapper when `/model claude-... [1m]` works, even if raw `/api/v1/messages` rejects that literal model id.
6. For personal subscriptions, use `claude-sub` and `codex-sub` wrappers. `claude-sub` excludes user settings (so an API-key helper cannot override Claude.ai OAuth), clears provider env, and disables Claude subprocess env scrub so Git/SSH tools can still see `SSH_AUTH_SOCK`; run `claude-sub auth login` yourself if the subscription path is not logged in. For `claude-sub -p`, generate a token with `claude-sub setup-token` and store it in 1Password at `CLAUDE_SUB_OAUTH_TOKEN_OP_REF`. After changing the function, exit any running Claude process and reload `~/.zshrc.local`; existing shells retain the old function in memory. `codex-sub` sets `CODEX_HOME=${CODEX_SUB_HOME:-$HOME/.codex-sub}` so it has its own auth/config/session state and does not touch `~/.codex`.
7. Optional Headroom compression: after `uv tool install 'headroom-ai[all]'`, uncomment the `hr-*` block in `~/.zshrc.local` (template in `zsh/.zshrc.local.example`) to route the CLIs through a pure local `headroom proxy` per upstream. Never use `headroom wrap` (it durably rewrites `~/.codex/config.toml` and `~/AGENTS.md`); the wrappers use plain `headroom proxy` + per-process base URLs instead. Type `hr-help` for usage. Heavily cached sessions legitimately show `compressed=0` with `cache_saved>0`.

Example `~/.claude/settings.local.json`:

```json
{
  "apiKeyHelper": "/Users/<you>/.claude/api-key-helper.sh",
  "env": {
    "CLAUDE_CODE_API_KEY_HELPER_TTL_MS": "14400000"
  }
}
```

## Subscription print mode
`claude-sub` interactive sessions and `claude-sub -p` do not use the same auth path.

- `claude-sub auth status` can show `authMethod: claude.ai` and `subscriptionType: max` because interactive Claude Code can read the Claude.ai OAuth/keychain login.
- `claude-sub -p` is non-interactive and does not reliably read that OAuth/keychain path. Claude Code's scripted path expects `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN`.
- For a personal subscription, prefer `CLAUDE_CODE_OAUTH_TOKEN`; generate it with `claude-sub setup-token` and store it in 1Password at `CLAUDE_SUB_OAUTH_TOKEN_OP_REF`.
- The wrapper reads that token only when `-p` or `--print` is present, so normal interactive `claude-sub` sessions still use the regular Claude.ai login.

## tmux -CC workflow
- Start iTerm2 control mode with `tmuxcc`
- Run `claude` inside the tmux session
- Do not add `--tmux` when you are already inside `tmuxcc`
- If you want Claude to manage panes itself, run `claude --tmux` outside tmux -CC

The shared `.zshrc` already allows iTerm2 shell integration to work inside `tmux -CC` when `tmuxcc` sets `ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX=1`.
