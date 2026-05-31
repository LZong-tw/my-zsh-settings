# zsh Configuration Repository

This repo keeps the shared shell behavior in git and pushes machine- or org-specific values into local override files.

## Goals
- Keep the main zsh behavior version-controlled
- Keep secrets, endpoints, and personal paths out of git
- Make it easy to rebuild the same workflow on a new machine

## Repository layout
- `zsh/.zshenv` — minimal always-loaded zsh bootstrap
- `zsh/.zprofile` — login-shell environment setup
- `zsh/.zshrc` — shared zsh configuration
- `zsh/.p10k.zsh` — Powerlevel10k prompt configuration
- `zsh/.zsh.startup-profiler.zsh` — optional portable startup profiling module
- `zsh/.zshrc.local.example` — template for machine- or org-specific overrides
- `bin/kubectl-eks-token` — AWS EKS token wrapper for `assume`/Granted + `kubectl`
- `install.sh` — backs up managed dotfiles, symlinks the shared config, and seeds `~/.zshrc.local`
- `CLAUDE.md` — Claude Code, 1Password, and tmux -CC notes
- `examples/claude-api-key-helper.sh.example` — sample `apiKeyHelper` script

## What should be committed
- Shared shell behavior across `.zshenv`, `.zprofile`, `.zshrc`, and `.p10k.zsh`
- Aliases, wrappers, tmux helpers, prompt config, completion tuning
- Small helper scripts that should be available from `~/.local/bin`
- Docs and example files

## Kali features carried by this repo
The shared `.zshrc` keeps Powerlevel10k as the preferred prompt, but it now
bundles Kali's interactive defaults directly so they travel with the repo to any
machine (Kali, other Linux, or macOS) — not just when you happen to be on Kali:

- Emacs-style editing plus `Ctrl+U`, `Ctrl+Left/Right`, `Ctrl+Delete`,
  `PageUp/PageDown`, `Shift+Tab`, `Ctrl+R`, and `Ctrl+X Ctrl+E`
- case-insensitive menu completion with cached `compinit`
- duplicate-aware shared history, `history` showing the full list, and a
  readable `time` command format
- GNU color defaults for `ls`, `diff`, `ip`, `less`, and man pages when the
  commands support them
- `ls`, `l`, `ll`, and `la` aliases, preferring `eza` when available
- Kali's full **zsh-syntax-highlighting color theme** (the `ZSH_HIGHLIGHT_STYLES`
  set), applied whenever the highlighter loads
- Kali's subtle grey **autosuggestion color** (`fg=#999`)
- Kali setopts `magicequalsubst`, `numericglobsort`, and `PROMPT_EOL_MARK=""`
- Debian/Kali `command-not-found` integration when `/etc/zsh_command_not_found`
  exists

### Plugin/theme discovery is portable
Powerlevel10k, zsh-autosuggestions, and zsh-syntax-highlighting are sourced from
the first location that exists, in this order: oh-my-zsh custom dirs →
Debian/Kali `/usr/share/*` packages → Homebrew (`/opt/homebrew` and
`/usr/local`). A machine without oh-my-zsh uses its distro/Homebrew packages
instead of erroring on startup.

### Prompt: p10k with a Kali fallback
When Powerlevel10k is available it owns the prompt (via `zsh/.p10k.zsh`). When it
is **not** found, `.zshrc` falls back to Kali's native two-line `㉿` prompt,
including the `Ctrl+P` one-line/two-line toggle and the blank-line-before-prompt
behaviour. Either way you keep a usable, Kali-flavored prompt.

### Prompt colors: use ansi256 indices, never `#hex`
The p10k prompt palette is tuned to match the
[ccstatusline](https://github.com/sirmalloc/ccstatusline) `nord-aurora` theme at
`colorLevel 2`, so every `*_FOREGROUND`/`*_BACKGROUND` value in `zsh/.p10k.zsh`
is an **ansi256 index**, not a hex string. The mapping is:

| role | index | role | index |
|------|-------|------|-------|
| red    | `131` | magenta | `176` |
| yellow | `220` | dark text | `16`  |
| blue   | `68`  | light text | `255` |
| green  | `108` | grey/frame | `240`/`244` |

Two hard-won gotchas if you ever re-theme it:

- **Do not use `#rrggbb` hex values in `.p10k.zsh`.** Under `setopt extended_glob`
  (which the prompt enables) `#` is a glob operator. On a brace-expansion line such
  as `POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,...}_FOREGROUND=#A3BE8C`, zsh tries
  to glob the `#…` and aborts startup with `no matches found`. Indices in the
  16–255 range are also scheme-independent (unlike `0–15`), so they render the
  same regardless of the terminal's 16-color scheme. Hex is fine in the
  oh-my-posh JSON theme (it is JSON, not zsh) — only `.p10k.zsh` is affected.
- **`zsh -n` is not enough to verify a color change.** It is a syntax check and
  will not catch the runtime glob error above. Always actually source the file:
  `zsh -c 'setopt extended_glob nomatch; source ~/.p10k.zsh && echo OK'`.

Segment icons have no separate color setting here — each icon inherits its
segment's foreground, so re-coloring a segment re-colors its icon too.

## What should stay local
- `~/.zshrc.local`
- `~/.claude/settings.local.json` or `~/.claude/settings.json`
- `~/.claude/api-key-helper.sh`
- Any 1Password item paths, raw credentials, or internal-only endpoints you do not want in git

## Quick install
```bash
git clone https://github.com/LZong-tw/my-zsh-settings.git
cd ~/my-zsh-settings
./install.sh
```

`install.sh` will:
1. Back up and symlink `~/.zshenv`
2. Back up and symlink `~/.zprofile`
3. Back up and symlink `~/.zshrc`
4. Back up and symlink `~/.p10k.zsh`
5. Back up and symlink `~/.zsh.startup-profiler.zsh`
6. Copy `zsh/.zshrc.local.example` to `~/.zshrc.local` if it does not already exist
7. Install managed helper scripts into `~/.local/bin`

## After install
1. Edit `~/.zshrc.local`
2. Fill in your real endpoints and 1Password references
3. Reload with `exec zsh -l`

## WSL screenshot paste bridge
For Windows + WSL agent sessions, install the optional `wsl-screenshot-cli`
bridge:

```bash
./install.sh --with-wsl-screenshot-cli
```

When `wsl-screenshot-cli` is installed, `.zshrc` starts it quietly in WSL
terminals. The intended UX is native-feeling: take a screenshot with
`Win+Shift+S`, paste in the WSL terminal, and the prompt receives a WSL-readable
PNG path such as `/tmp/.wsl-screenshot-cli/<hash>.png`. Pasting into Windows
apps still behaves normally as an image/file.

Useful controls:

```bash
wsl-screenshot-cli status
wsl-screenshot-cli stop
WSL_SCREENSHOT_CLI_AUTOSTART=0 exec zsh -l
WSL_SCREENSHOT_CLI_INTERVAL_MS=1000 exec zsh -l
```

Keep `wslshot` as a fallback for command-driven workflows, but prefer
`wsl-screenshot-cli` when the goal is "paste like native" UX for Claude Code,
Codex CLI, Gemini CLI, and other WSL terminal agents.

## Optional startup profiling
Add these to `~/.zshrc.local` only when you want profiling:

```bash
export ZSH_STARTUP_PROFILING=1
export ZSH_STARTUP_PROFILE_THRESHOLD=1.0
# export ZSH_STARTUP_PROFILE_LOG_PATH="$HOME/.cache/zsh-slow-start.log"
# export ZSH_STARTUP_PROFILE_ZPROF=1
```

When enabled, both `~/.zprofile` and `~/.zshrc` can write phase timings through the portable module at `~/.zsh.startup-profiler.zsh`. Slow entries also include `zprof` function timings by default; set `ZSH_STARTUP_PROFILE_ZPROF=0` to keep only phase timings.

## Kubernetes prompt context
Powerlevel10k uses a custom lazy kube context segment instead of the built-in `kubecontext` segment. The prompt only reads a cache at `$XDG_CACHE_HOME/p10k-kubecontext` or `~/.cache/p10k-kubecontext`; `kubectl`, `kubectx`, and `kubens` refresh that cache in the background after they run.

## AWS EKS credentials for kubectl
`bin/kubectl-eks-token` is installed to `~/.local/bin/kubectl-eks-token`.
Point EKS kubeconfig `users[].user.exec.command` at that path and pass the AWS
profile through `--profile`.

The wrapper first uses the current shell's credentials when the shell is already
assumed into the requested profile (`assume kkbox-testing`, `aws-vault exec
kkbox-testing`, etc.). If no matching ambient session exists, it tries
`aws eks get-token` with a clean `AWS_PROFILE`. If the credential cache is stale,
it falls back to Granted:

```bash
assume --exec 'aws eks get-token ...' kkbox-testing
```

If Granted still returns expired credentials, the wrapper retries once with
`assume --no-cache --exec ...`. It keeps stdout reserved for the Kubernetes
`ExecCredential` JSON and sends Granted status/error messages to stderr, which
prevents kubectl from seeing malformed plugin output such as
`client.authentication.k8s.io/__internal`. In interactive terminals, fallback
stderr is passed through so MFA/error prompts remain visible.

## Optional plugin install
```bash
./install.sh --with-plugins
```

Manual equivalents:

```bash
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
```

## iTerm2 and tmux -CC
- Install iTerm2 shell integration:

```bash
curl -L https://iterm2.com/shell_integration/zsh -o ~/.iterm2_shell_integration.zsh
```

- Use `tmuxcc` to start `tmux -CC`
- Run `claude` inside that session
- If Claude should manage panes itself, run `claude --tmux` outside `tmuxcc`

More detail is in `CLAUDE.md`.

## Reverting
```bash
mv ~/.zshrc.backup-<timestamp> ~/.zshrc
```

## Flags
- `--with-deps`: install shell dependencies via the OS package manager — apt on
  Debian/Kali (`zsh-syntax-highlighting`, `zsh-autosuggestions`,
  `command-not-found`, `zoxide`, `eza`, `fzf`) or Homebrew on macOS (the same
  set plus `powerlevel10k`). Powerlevel10k is not packaged on Debian/Kali, so use
  `--with-plugins` to clone it there.
- `--with-plugins`: clone Powerlevel10k, zsh-autosuggestions, and zsh-syntax-highlighting
- `--with-wsl-screenshot-cli`: install `wsl-screenshot-cli` on WSL so
  `Win+Shift+S` screenshots can be pasted into terminal agents as image paths
- `--no-oh-my-zsh`: skip automatic Oh My Zsh installation
- `--no-local-bin`: skip installing managed helper scripts into `~/.local/bin`
