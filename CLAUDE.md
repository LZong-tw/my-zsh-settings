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
4. For multiple Anthropic keys, keep each key in 1Password and add wrapper functions such as `claude-alt1` in `~/.zshrc.local`; when keys come from different platforms, switch or unset `ANTHROPIC_BASE_URL` with the key.
5. For Azure AI Foundry Claude deployments, use `CLAUDE_CODE_USE_FOUNDRY=1` and `ANTHROPIC_FOUNDRY_BASE_URL`; in Claude Code 2.1.119 the value should include the `/anthropic` prefix, for example `https://my-resource.services.ai.azure.com/anthropic`, because Claude Code appends `/v1/messages`.

Example `~/.claude/settings.local.json`:

```json
{
  "apiKeyHelper": "/Users/<you>/.claude/api-key-helper.sh",
  "env": {
    "CLAUDE_CODE_API_KEY_HELPER_TTL_MS": "14400000"
  }
}
```

## tmux -CC workflow
- Start iTerm2 control mode with `tmuxcc`
- Run `claude` inside the tmux session
- Do not add `--tmux` when you are already inside `tmuxcc`
- If you want Claude to manage panes itself, run `claude --tmux` outside tmux -CC

The shared `.zshrc` already allows iTerm2 shell integration to work inside `tmux -CC` when `tmuxcc` sets `ITERM_ENABLE_SHELL_INTEGRATION_WITH_TMUX=1`.
