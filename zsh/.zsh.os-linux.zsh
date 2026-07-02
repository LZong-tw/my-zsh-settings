# ~/.zsh.os-linux.zsh — Linux/WSL-only zsh bits (managed by my-zsh-settings)
# Sourced from .zshrc. No-op on macOS. Keep this file small and machine-agnostic;
# put secrets and box-specific values in ~/.zshrc.local instead.
[[ "$OSTYPE" == linux* ]] || return

# --------------------------------------------------------------------------
# clipaste — screenshot/image paste for terminal AI tools on WSL2
# --------------------------------------------------------------------------
# Windows side runs clipaste.exe (HTTP server on 127.0.0.1:18340). This box
# installs xclip/wl-paste shims in ~/.local/bin so Claude Code pastes images
# with Ctrl+V directly. Codex CLI reads the clipboard in-process and BYPASSES
# the shim, so it uses the clipaste-paste helper via this alias:
#   take a screenshot on Windows -> run `codeximg` -> paste the printed /tmp path
if (( $+commands[clipaste-paste] )); then
  alias codeximg='clipaste-paste'
fi

# (Re)install the clipaste xclip/wl-paste/clipaste-paste shims. Needed on WSL2
# *mirrored* networking, where `clipaste wsl-setup` can't auto-detect the host
# (it only reads /etc/resolv.conf). See github.com/hqhq1025/clipaste/issues/7.
# Usage: clipaste-wsl-shims [host]   (host defaults to 127.0.0.1 for mirrored mode)
clipaste-wsl-shims() {
  emulate -L zsh
  local host="${1:-127.0.0.1}"
  local url="http://${host}:18340"
  local bin="$HOME/.local/bin"
  mkdir -p "$bin"

  if ! curl -sf -o /dev/null "${url}/health" 2>/dev/null; then
    print -u2 "clipaste-wsl-shims: no clipaste server at ${url} — is clipaste.exe running on Windows?"
    return 1
  fi

  local f
  for f in xclip wl-paste; do
    local trigger real_var
    if [[ "$f" == xclip ]]; then
      trigger='*"-selection clipboard"*"-t image/png"*"-o"*|*"-sel clip"*"-t image/png"*"-o"*'
      targets='*"-selection clipboard"*"-t TARGETS"*"-o"*|*"-sel clip"*"-t TARGETS"*"-o"*'
      real_var=REAL_XCLIP; realcmd=xclip
    else
      trigger='*"--type image/"*|*"-t image/"*'
      targets='*"--list-types"*'
      real_var=REAL_WL_PASTE; realcmd=wl-paste
    fi
    cat > "$bin/$f" <<SHIM
#!/bin/bash
# clipaste $f shim (managed by my-zsh-settings clipaste-wsl-shims)
CLIPASTE_URL="$url"
$real_var="\$(PATH=\$(echo "\$PATH" | sed "s|\$HOME/.local/bin:||g") command -v $realcmd 2>/dev/null)"
case "\$*" in
    $targets)
        if curl -sf "\${CLIPASTE_URL}/clipboard/type" 2>/dev/null | grep -q '"image"'; then
            echo "image/png"; exit 0
        fi ;;
    $trigger)
        tmpfile=\$(mktemp /tmp/clipaste-remote-XXXXXX.png)
        if curl -sf -o "\$tmpfile" "\${CLIPASTE_URL}/clipboard/image" 2>/dev/null && [ -s "\$tmpfile" ]; then
            cat "\$tmpfile"; rm -f "\$tmpfile"; exit 0
        fi
        rm -f "\$tmpfile" ;;
esac
if [ -n "\$$real_var" ] && [ -x "\$$real_var" ]; then exec "\$$real_var" "\$@"; else echo "$realcmd not found" >&2; exit 1; fi
SHIM
    chmod +x "$bin/$f"
  done

  cat > "$bin/clipaste-paste" <<SHIM
#!/bin/bash
# clipaste-paste helper (managed by my-zsh-settings clipaste-wsl-shims)
CLIPASTE_URL="$url"
if ! curl -sf "\${CLIPASTE_URL}/clipboard/type" 2>/dev/null | grep -q '"image"'; then
    echo "clipaste-paste: no image on clipboard - take a screenshot on Windows first" >&2; exit 1
fi
out="\${TMPDIR:-/tmp}/clipaste-\$(date +%s)-\$\$.png"
if curl -sf -o "\$out" "\${CLIPASTE_URL}/clipboard/image" 2>/dev/null && [ -s "\$out" ]; then echo "\$out"; exit 0; fi
rm -f "\$out"; echo "clipaste-paste: failed to fetch image from \${CLIPASTE_URL}" >&2; exit 1
SHIM
  chmod +x "$bin/clipaste-paste"

  print "clipaste shims installed in $bin (host: $host). xclip/wl-paste/clipaste-paste ready."
}
