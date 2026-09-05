#!/usr/bin/env bash
# GitHub CLI (gh). /review, /deploy-check, ProjectMan git-status and the
# ProjectMan pin lookup all shell out to it.
# Idempotent: exits immediately if gh is already on PATH.
#
#   GH_INSTALL_METHOD=binary ./install.sh   force the no-sudo tarball install
set -euo pipefail

log()  { printf '\033[36m[gh]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[gh] %s\033[0m\n' "$*"; }
die()  { printf '\033[31m[gh] %s\033[0m\n' "$*" >&2; exit 1; }

if command -v gh >/dev/null 2>&1; then
  log "already installed: $(gh --version | head -1)"
else
  method="${GH_INSTALL_METHOD:-}"
  SUDO=""; [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"
  if [ -z "$method" ]; then
    if   command -v brew    >/dev/null 2>&1; then method=brew
    elif command -v apt-get >/dev/null 2>&1 && [ -n "$SUDO$([ "$(id -u)" -eq 0 ] && echo root)" ]; then method=apt
    elif command -v dnf     >/dev/null 2>&1 && [ -n "$SUDO$([ "$(id -u)" -eq 0 ] && echo root)" ]; then method=dnf
    elif command -v pacman  >/dev/null 2>&1 && [ -n "$SUDO$([ "$(id -u)" -eq 0 ] && echo root)" ]; then method=pacman
    elif command -v apk     >/dev/null 2>&1 && [ -n "$SUDO$([ "$(id -u)" -eq 0 ] && echo root)" ]; then method=apk
    else method=binary; fi
  fi
  log "installing via $method"
  case "$method" in
    brew)   brew install gh ;;
    apt)
      # Official GitHub apt repo (https://github.com/cli/cli/blob/trunk/docs/install_linux.md)
      $SUDO mkdir -p -m 755 /etc/apt/keyrings
      tmpkey=$(mktemp)
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o "$tmpkey"
      $SUDO install -m 0644 "$tmpkey" /etc/apt/keyrings/githubcli-archive-keyring.gpg; rm -f "$tmpkey"
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | $SUDO tee /etc/apt/sources.list.d/github-cli.list >/dev/null
      $SUDO apt-get update -qq && $SUDO apt-get install -y -qq gh ;;
    dnf)    $SUDO dnf install -y 'dnf-command(config-manager)' >/dev/null 2>&1 || true
            $SUDO dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo 2>/dev/null || true
            $SUDO dnf install -y gh ;;
    pacman) $SUDO pacman -Sy --noconfirm github-cli ;;
    apk)    $SUDO apk add --no-cache github-cli ;;
    binary)
      # No package manager or no sudo: latest release tarball into ~/.local/bin
      command -v curl >/dev/null 2>&1 || die "curl is required for the binary install"
      command -v tar  >/dev/null 2>&1 || die "tar is required for the binary install"
      os=$(uname -s | tr '[:upper:]' '[:lower:]'); arch=$(uname -m)
      case "$arch" in x86_64|amd64) arch=amd64 ;; aarch64|arm64) arch=arm64 ;; armv6l|armv7l) arch=armv6 ;; *) die "unsupported arch $arch" ;; esac
      [ "$os" = darwin ] && os=macOS
      ver=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | jq -r '.tag_name | ltrimstr("v")')
      [ -n "$ver" ] && [ "$ver" != null ] || die "could not determine latest gh version"
      ext=tar.gz; [ "$os" = macOS ] && ext=zip
      url="https://github.com/cli/cli/releases/download/v${ver}/gh_${ver}_${os}_${arch}.${ext}"
      tmpd=$(mktemp -d); trap 'rm -rf "$tmpd"' EXIT
      log "downloading $url"
      curl -fsSL "$url" -o "$tmpd/gh.$ext"
      if [ "$ext" = zip ]; then (cd "$tmpd" && unzip -q gh.zip); else tar -xzf "$tmpd/gh.$ext" -C "$tmpd"; fi
      mkdir -p "$HOME/.local/bin"
      install -m 0755 "$tmpd/gh_${ver}_${os}_${arch}/bin/gh" "$HOME/.local/bin/gh"
      case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *)
        warn "$HOME/.local/bin is not on PATH; add it to your shell rc"; export PATH="$HOME/.local/bin:$PATH" ;;
      esac ;;
    *) die "unknown GH_INSTALL_METHOD '$method'" ;;
  esac
  command -v gh >/dev/null 2>&1 || die "gh still not on PATH after install"
  log "installed: $(gh --version | head -1)"
fi

# Auth is interactive; never run it from a script.
if gh auth status >/dev/null 2>&1; then
  log "authenticated (gh auth status OK)"
else
  warn "gh is not logged in. Run:  gh auth login  (choose GitHub.com, HTTPS or SSH, login with a browser)"
fi
