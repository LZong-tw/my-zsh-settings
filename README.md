# zsh Configuration Repository

This repository contains a configurable zsh setup that you can easily apply on a new machine or environment.

Enjoy your zsh configuration!

## Goals
- Easy install and update
- Centralized config (version-controlled)
- Easy to extend with plugins, aliases, and functions

## Repository layout
- `zsh/.zshrc` — Main zsh configuration template
- `install.sh` — Installer script that backs up any existing `~/.zshrc` and symlinks the one from this repository

## Prerequisites
- zsh (preferred) installed
- git installed
- Oh My Zsh (recommended). The installer can optionally auto-install Oh My Zsh for you if it's missing.

## Quick install
```bash
# Clone repository
git clone <your-repo-url> ~/projects/zsh-config
cd ~/projects/zsh-config

# Run the installer. This will:
# 1) backup any existing ~/.zshrc to ~/.zshrc.backup-<timestamp>
# 2) symlink the project zsh/.zshrc to ~/.zshrc
./install.sh
```

To also automatically install recommended theme and plugins, run:

```bash
# Option 1: Run the script with the optional flag to install plugins/themes
./install.sh --with-plugins

# Option 2: Or run these commands manually if you prefer to do it yourself:
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
```

## Usage
- Edit `zsh/.zshrc` in this repo to adjust settings, aliases and functions.
- After editing the repo version, reload your shell configuration with:
```bash
source ~/.zshrc
```

## Reverting
If you want to restore the original `~/.zshrc` that was backed up by the installer, simply move it back:
```bash
mv ~/.zshrc.backup-<timestamp> ~/.zshrc
```

## Notes
- The sample `zsh/.zshrc` already references `powerlevel10k` as the theme and enables `zsh-autosuggestions` and `zsh-syntax-highlighting` in the `plugins` array. Installing the theme and plugins as shown above will allow those lines to take effect.
- This project purposefully symlinks your home `~/.zshrc` to `zsh/.zshrc` inside this repo so you can manage it with version control.

- ### Recommended terminal experience: This configuration looks best in iTerm2 with the "Solarized Dark" color scheme (use a Powerline-compatible font for the Powerlevel10k prompt).

- The `install.sh` installer will attempt to auto-install Oh My Zsh if it is not found on the system; to opt out, run:
```bash
./install.sh --no-oh-my-zsh
```

Flags summary:
- `--with-plugins`: clone Powerlevel10k, zsh-autosuggestions and zsh-syntax-highlighting into `${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}`
- `--no-oh-my-zsh`: skip automatic Oh My Zsh installation

````
