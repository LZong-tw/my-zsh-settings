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
- `install.sh` — backs up managed dotfiles, symlinks the shared config, and seeds `~/.zshrc.local`
- `CLAUDE.md` — Claude Code, 1Password, and tmux -CC notes
- `examples/claude-api-key-helper.sh.example` — sample `apiKeyHelper` script

## What should be committed
- Shared shell behavior across `.zshenv`, `.zprofile`, `.zshrc`, and `.p10k.zsh`
- Aliases, wrappers, tmux helpers, prompt config, completion tuning
- Docs and example files

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

## After install
1. Edit `~/.zshrc.local`
2. Fill in your real endpoints and 1Password references
3. Reload with `exec zsh -l`

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
- `--with-plugins`: clone Powerlevel10k, zsh-autosuggestions, and zsh-syntax-highlighting
- `--no-oh-my-zsh`: skip automatic Oh My Zsh installation
