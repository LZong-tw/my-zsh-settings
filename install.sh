#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_LOCAL_ZSHRC="$HOME/.zshrc.local"
SOURCE_LOCAL_ZSHRC_EXAMPLE="$PROJECT_DIR/zsh/.zshrc.local.example"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
INSTALL_PLUGINS=false
INSTALL_OMZ=true
INSTALL_LOCAL_BIN=true
INSTALL_DEPS=false
INSTALL_WSL_SCREENSHOT_CLI=false

print_usage() {
  echo "Usage: $0 [--with-deps] [--with-plugins] [--with-wsl-screenshot-cli] [--no-oh-my-zsh] [--no-local-bin]"
  echo "  --with-deps:    install shell deps via the OS package manager"
  echo "                  (apt on Debian/Kali, Homebrew on macOS):"
  echo "                  zsh-syntax-highlighting, zsh-autosuggestions,"
  echo "                  command-not-found, zoxide, eza, fzf (+ powerlevel10k on brew)"
  echo "  --with-plugins: also clone Powerlevel10k and recommended plugins into \
${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  echo "  --with-wsl-screenshot-cli: install wsl-screenshot-cli for native-feeling"
  echo "                  Win+Shift+S screenshot paste in WSL terminals"
  echo "  --no-oh-my-zsh: skip auto-installing Oh My Zsh if it's not present"
  echo "  --no-local-bin: skip installing managed helper scripts into ~/.local/bin"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-plugins|--install-plugins)
      INSTALL_PLUGINS=true
      shift
      ;;
    --with-deps|--install-deps)
      INSTALL_DEPS=true
      shift
      ;;
    --with-wsl-screenshot-cli|--install-wsl-screenshot-cli)
      INSTALL_WSL_SCREENSHOT_CLI=true
      shift
      ;;
    --no-oh-my-zsh|--skip-oh-my-zsh)
      INSTALL_OMZ=false
      shift
      ;;
    --no-local-bin|--skip-local-bin)
      INSTALL_LOCAL_BIN=false
      shift
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      print_usage
      exit 1
      ;;
  esac
done

# Install shell dependencies through the OS package manager so the repo can
# carry Kali's interactive features (syntax highlighting, autosuggestions,
# command-not-found) plus the modern CLI tools the .zshrc expects.
install_deps() {
  if command -v apt-get >/dev/null 2>&1; then
    echo "Detected apt (Debian/Kali). Installing shell dependencies..."
    local SUDO=""
    [[ "${EUID:-$(id -u)}" -eq 0 ]] || SUDO="sudo"
    $SUDO apt-get update -qq || true
    # Powerlevel10k is not packaged on Debian/Kali; use --with-plugins for it.
    $SUDO apt-get install -y \
      zsh \
      zsh-syntax-highlighting \
      zsh-autosuggestions \
      command-not-found \
      zoxide \
      eza \
      fzf \
      || echo "Warning: some apt packages failed to install" >&2
  elif command -v brew >/dev/null 2>&1; then
    echo "Detected Homebrew (macOS). Installing shell dependencies..."
    brew install \
      powerlevel10k \
      zsh-syntax-highlighting \
      zsh-autosuggestions \
      zoxide \
      eza \
      fzf \
      || echo "Warning: some Homebrew formulae failed to install" >&2
  else
    echo "No apt or Homebrew found; skipping automatic dependency install." >&2
    echo "Install zsh-syntax-highlighting, zsh-autosuggestions, zoxide, eza, and fzf manually." >&2
  fi
}

download_file() {
  local url=$1
  local dest=$2

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$dest" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$dest" "$url"
  else
    echo "Error: curl or wget is required for downloads." >&2
    return 1
  fi
}

install_wsl_screenshot_cli() {
  local repo="Nailuu/wsl-screenshot-cli"
  local binary="wsl-screenshot-cli"
  local install_dir="$HOME/.local/bin"
  local arch version version_stripped archive base tmpdir expected actual installed_version

  if ! grep -qiE "wsl|microsoft" /proc/version 2>/dev/null; then
    echo "Not running inside WSL; skipping $binary." >&2
    return 0
  fi

  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *)
      echo "Unsupported architecture for $binary: $arch" >&2
      return 1
      ;;
  esac

  version="$(
    if command -v curl >/dev/null 2>&1; then
      curl -fsSL "https://api.github.com/repos/${repo}/releases/latest"
    else
      wget -qO- "https://api.github.com/repos/${repo}/releases/latest"
    fi | grep '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/'
  )"
  if [[ -z "$version" ]]; then
    echo "Unable to resolve latest $binary release." >&2
    return 1
  fi

  version_stripped="${version#v}"
  if command -v "$binary" >/dev/null 2>&1; then
    installed_version="$("$binary" --version 2>&1 | awk '{print $NF}')"
    if [[ "$installed_version" == "$version_stripped" ]]; then
      echo "$binary already up to date ($version)."
      return 0
    fi
  fi

  archive="${binary}_${version_stripped}_linux_${arch}.tar.gz"
  base="https://github.com/${repo}/releases/download/${version}"
  tmpdir="$(mktemp -d)"

  download_file "$base/$archive" "$tmpdir/$archive"
  download_file "$base/checksums.txt" "$tmpdir/checksums.txt"

  expected="$(grep "$archive" "$tmpdir/checksums.txt" | awk '{print $1}' || true)"
  actual="$(sha256sum "$tmpdir/$archive" | awk '{print $1}')"
  if [[ -z "$expected" || "$expected" != "$actual" ]]; then
    rm -rf "$tmpdir"
    echo "Checksum verification failed for $archive." >&2
    return 1
  fi

  tar -xzf "$tmpdir/$archive" -C "$tmpdir" "$binary"
  mkdir -p "$install_dir"
  install -m 0755 "$tmpdir/$binary" "$install_dir/$binary"
  rm -rf "$tmpdir"
  echo "Installed $binary $version to $install_dir/$binary"
}

if [[ "$INSTALL_DEPS" = true ]]; then
  install_deps
fi

if [[ "$INSTALL_WSL_SCREENSHOT_CLI" = true ]]; then
  install_wsl_screenshot_cli
fi

if [[ ! -f "$PROJECT_DIR/zsh/.zshrc" ]]; then
  echo "Cannot find source zshrc: $PROJECT_DIR/zsh/.zshrc" >&2
  exit 1
fi

link_managed_file() {
  local source_path=$1
  local target_path=$2
  local label backup_path

  [[ -f "$source_path" ]] || return 0

  label="${target_path/#$HOME\//~/}"
  backup_path="${target_path}.backup-${TIMESTAMP}"

  if [[ -L "$target_path" && "$(readlink "$target_path")" == "$source_path" ]]; then
    echo "$label already points to $source_path"
  elif [[ -e "$target_path" || -L "$target_path" ]]; then
    echo "Existing $label detected, backing up to: $backup_path"
    mv "$target_path" "$backup_path"
    ln -s "$source_path" "$target_path"
    echo "Symlink created: $target_path -> $source_path"
  else
    ln -s "$source_path" "$target_path"
    echo "Symlink created: $target_path -> $source_path"
  fi
}

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

MANAGED_DOTFILES=(
  ".zshenv"
  ".zprofile"
  ".zshrc"
  ".p10k.zsh"
  ".zsh.startup-profiler.zsh"
)

for dotfile in "${MANAGED_DOTFILES[@]}"; do
  link_managed_file "$PROJECT_DIR/zsh/$dotfile" "$HOME/$dotfile"
done

if [[ ! -f "$TARGET_LOCAL_ZSHRC" && -f "$SOURCE_LOCAL_ZSHRC_EXAMPLE" ]]; then
  cp "$SOURCE_LOCAL_ZSHRC_EXAMPLE" "$TARGET_LOCAL_ZSHRC"
  echo "Created local override template: $TARGET_LOCAL_ZSHRC"
fi

if [[ "$INSTALL_LOCAL_BIN" = true ]]; then
  mkdir -p "$HOME/.local/bin"
  for helper in "$PROJECT_DIR"/bin/*; do
    [[ -f "$helper" ]] || continue
    target="$HOME/.local/bin/$(basename "$helper")"
    install -m 0755 "$helper" "$target"
    echo "Installed helper: $target"
  done
fi

echo "Done! Restart your terminal or run: exec zsh -l"

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
