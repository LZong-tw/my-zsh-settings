# ~/.zsh.os-linux.zsh — Linux/WSL-only zsh bits (managed by my-zsh-settings)
# Sourced from .zshrc. No-op on macOS. Keep this file small and machine-agnostic;
# put secrets and box-specific values in ~/.zshrc.local instead.
[[ "$OSTYPE" == linux* ]] || return

# --------------------------------------------------------------------------
# Windows-clipboard image paste for terminal AI tools on WSL2
# --------------------------------------------------------------------------
# On WSL2, ~/.local/bin holds thin shims (installed from this repo's bin-wsl/
# by install.sh) that read the *Windows* clipboard image ON DEMAND via
# powershell.exe and never rewrite it:
#   clip-win-image  -> saves the current clipboard image to a PNG, prints its path
#   xclip / wl-paste-> shadow the real tools so Claude Code pastes images w/ Ctrl+V
#   clipaste-paste  -> for Codex CLI, which reads the clipboard in-process and
#                      bypasses the xclip shim; prints a real path to paste.
#
# We deliberately do NOT run a clipboard-watcher daemon. Both clipaste and
# wsl-screenshot-cli worked by rewriting the Windows clipboard into a text path,
# which broke native-image paste in Windows apps (e.g. Codex Desktop showed the
# path instead of the image). On-demand reads keep both worlds working: native
# Windows apps see the raw bitmap; WSL fetches a copy only when asked.
#
# Codex CLI usage: screenshot on Windows -> run `codeximg` -> paste the printed path.
if (( $+commands[clipaste-paste] )); then
  alias codeximg='clipaste-paste'
fi

# Reinstall/repair the WSL clipboard shims from this repo's bin-wsl/ into
# ~/.local/bin. Handy after editing a shim; install.sh does the same on setup.
# Override the repo location with MYZSH_REPO if it lives elsewhere.
winclip-wsl-shims() {
  emulate -L zsh
  local repo="${MYZSH_REPO:-$HOME/my-zsh-settings}"
  local src="$repo/bin-wsl" bin="$HOME/.local/bin"
  if [[ ! -d "$src" ]]; then
    print -u2 "winclip-wsl-shims: $src not found (set MYZSH_REPO to your my-zsh-settings path)"
    return 1
  fi
  mkdir -p "$bin"
  local f
  for f in clip-win-image xclip wl-paste clipaste-paste; do
    [[ -f "$src/$f" ]] && install -m 0755 "$src/$f" "$bin/$f"
  done
  print "winclip shims installed in $bin from $src."
}
