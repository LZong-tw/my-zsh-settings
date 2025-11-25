#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_ZSHRC="$HOME/.zshrc"
SOURCE_ZSHRC="$PROJECT_DIR/zsh/.zshrc"
BACKUP_ZSHRC="$HOME/.zshrc.backup-$(date +%Y%m%d-%H%M%S)"
INSTALL_PLUGINS=false
INSTALL_OMZ=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-plugins|--install-plugins)
      INSTALL_PLUGINS=true
      shift
      ;;
    --no-oh-my-zsh|--skip-oh-my-zsh)
      INSTALL_OMZ=false
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--with-plugins] [--no-oh-my-zsh]"
      echo "  --with-plugins: also clone Powerlevel10k and recommended plugins into \
    ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
      echo "  --no-oh-my-zsh: skip auto-installing Oh My Zsh if it's not present"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--with-plugins] [--no-oh-my-zsh]"
      exit 1
      ;;
  esac
done

if [[ ! -f "$SOURCE_ZSHRC" ]]; then
  echo "Cannot find source zshrc: $SOURCE_ZSHRC" >&2
  exit 1
fi

ZSH_DIR="${ZSH:-$HOME/.oh-my-zsh}"
# If Oh My Zsh is missing and user did not opt-out, install it first.
if [[ "$INSTALL_OMZ" = true ]]; then
  if [[ ! -d "$ZSH_DIR" ]]; then
    echo "Oh My Zsh not found at $ZSH_DIR. Installing Oh My Zsh..."
    # Prefer curl, fall back to wget
    if command -v curl >/dev/null 2>&1; then
      RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    elif command -v wget >/dev/null 2>&1; then
      RUNZSH=no CHSH=no sh -c "$(wget -qO- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    else
      echo "Warning: curl/wget not found; cannot auto-install Oh My Zsh. Install it manually from https://ohmyz.sh/#install" >&2
    fi
  else
    echo "Oh My Zsh detected at: $ZSH_DIR. Skipping install."
  fi
fi

# Now backup and symlink the user's zshrc from the repo.
if [[ -f "$TARGET_ZSHRC" || -L "$TARGET_ZSHRC" ]]; then
  echo "Existing ~/.zshrc detected, backing up to: $BACKUP_ZSHRC"
  mv "$TARGET_ZSHRC" "$BACKUP_ZSHRC"
fi

ln -s "$SOURCE_ZSHRC" "$TARGET_ZSHRC"

echo "Symlink created: $TARGET_ZSHRC -> $SOURCE_ZSHRC"
echo "Done! Restart your terminal or run: source ~/.zshrc"

echo "Symlink created: $TARGET_ZSHRC -> $SOURCE_ZSHRC"
echo "Done! Restart your terminal or run: source ~/.zshrc"

if [[ "$INSTALL_PLUGINS" = true ]]; then
  echo "\nInstalling recommended theme and plugins..."
  if ! command -v git >/dev/null 2>&1; then
    echo "Error: git is not installed. Please install git and re-run the script with --with-plugins." >&2
    exit 1
  fi

  ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  mkdir -p "$ZSH_CUSTOM_DIR/themes" "$ZSH_CUSTOM_DIR/plugins"

  # Powerlevel10k theme
  if [[ -d "$ZSH_CUSTOM_DIR/themes/powerlevel10k" ]]; then
    echo "Powerlevel10k already installed, skipping."
  else
    echo "Cloning Powerlevel10k theme..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM_DIR/themes/powerlevel10k"
  fi

  # zsh-autosuggestions plugin
  if [[ -d "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions" ]]; then
    echo "zsh-autosuggestions already installed, skipping."
  else
    echo "Cloning zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
  fi

  # zsh-syntax-highlighting plugin
  if [[ -d "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting" ]]; then
    echo "zsh-syntax-highlighting already installed, skipping."
  else
    echo "Cloning zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"
  fi

  echo "Plugin/theme installation complete. Make sure Oh-My-Zsh is installed to correctly load custom plugins/themes."
fi