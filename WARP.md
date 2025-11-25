# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Repository purpose

This repository centralizes your Zsh configuration so you can quickly apply the same setup on new machines or environments. The repo provides a template `~/.zshrc` and an installer script that backs up any existing config and symlinks to the version tracked here.

## High-level structure & architecture

- `install.sh`
  - Entry point for setting up this config on a machine.
  - Resolves the project directory, then:
    - Verifies that `zsh/.zshrc` exists.
    - If `~/.zshrc` already exists or is a symlink, moves it to a timestamped backup at `~/.zshrc.backup-YYYYMMDD-HHMMSS`.
    - Creates a symbolic link from `zsh/.zshrc` in this repo to `~/.zshrc`.
  - Prints instructions to reload the shell via `source ~/.zshrc`.

- `zsh/.zshrc`
  - Main Zsh configuration template managed by this repo.
  - Responsibilities:
    - Sets basic environment, e.g. `LANG`, `EDITOR`, and extends `PATH`.
    - Defines a simple prompt (`PROMPT`) and a few common `ls` aliases.
    - Serves as the central entry point for future modularization of configuration (e.g., sourcing `aliases.zsh`, `plugins.zsh`, etc. from this repo).
  - Designed to gradually absorb your current `~/.zshrc` content; comments indicate how to expand and split into additional files under `zsh/`.

Overall architecture: **single source-of-truth Zsh config** tracked in `zsh/.zshrc`, installed system-wide for the user via a **symlink-based installer** (`install.sh`). All future Zsh configuration should be routed through files in this repo and then reloaded in the shell.

## Important usage from README

The README documents the initial usage pattern:

- Repository layout:
  - `zsh/.zshrc`: main Zsh config template.
  - `install.sh`: installer that backs up your existing `~/.zshrc` and links it to this repo.

- Initial install on a new environment (adjust repo URL as needed):

```bash
git clone <your-repo-url> ~/projects/zsh-config
cd ~/projects/zsh-config
./install.sh
```

After installation, `~/.zshrc` is a symlink pointing to `zsh/.zshrc` in this repository. Further edits to your shell configuration should be made in the repo, not directly in `~/.zshrc`.

## Common commands & workflows

These are the main commands Warp is likely to run in this repo:

- **Install / re-install configuration** (from the repo root):

```bash
./install.sh
```

- **Reload Zsh configuration in the current shell** (after editing `zsh/.zshrc` or other sourced files):

```bash
source ~/.zshrc
```

- **Open main Zsh config for editing** (replace `$EDITOR` as desired):

```bash
$EDITOR zsh/.zshrc
```

There is currently no build system, test suite, or lint configuration defined in this repository. Development consists of editing the Zsh configuration files and reloading them in a running shell to validate behavior.

## Notes for future Warp agents

- Treat `zsh/.zshrc` as the canonical entry point for Zsh configuration. If you add new configuration files (e.g., `zsh/aliases.zsh`, `zsh/plugins.zsh`), ensure they are sourced from `zsh/.zshrc`.
- When modifying `install.sh`, preserve its behavior of backing up any existing `~/.zshrc` before overwriting it with a symlink.
- If you introduce tooling such as linters (e.g., `shellcheck`) or tests for scripts, update this `WARP.md` with the corresponding commands so future agents can use them.