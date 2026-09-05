#!/usr/bin/env bash
# .NET SDKs: current LTS + the newest other supported channel. No preview,
# go-live, RC, alpha or beta builds. Idempotent: channels already present in
# `dotnet --list-sdks` are skipped; re-running picks up new patch releases.
#
#   DOTNET_CHANNELS="10.0 9.0" ./install.sh   override the selection
#   DOTNET_INSTALL_DIR=/opt/dotnet ./install.sh override the target root
set -euo pipefail

INDEX_URL="https://builds.dotnet.microsoft.com/dotnet/release-metadata/releases-index.json"
SCRIPT_URL="https://dot.net/v1/dotnet-install.sh"

log()  { printf '\033[36m[dotnet]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[dotnet] %s\033[0m\n' "$*"; }
die()  { printf '\033[31m[dotnet] %s\033[0m\n' "$*" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl is required"
command -v jq   >/dev/null 2>&1 || die "jq is required"

# --- 1. choose channels from Microsoft's release metadata --------------------
if [ -n "${DOTNET_CHANNELS:-}" ]; then
  read -r -a CHANNELS <<<"$DOTNET_CHANNELS"
else
  index=$(curl -fsSL --max-time 30 "$INDEX_URL") || die "could not fetch $INDEX_URL"
  # supported = active or maintenance. This excludes preview, go-live and eol.
  sel=$(printf '%s' "$index" | jq -r '
    [ .["releases-index"][] | select(.["support-phase"] | IN("active","maintenance")) ]
    | sort_by(.["channel-version"] | split(".") | map(tonumber)) | reverse
    | (map(select(.["release-type"]=="lts"))[0].["channel-version"] // "") as $lts
    | (map(select(.["channel-version"] != $lts))[0].["channel-version"] // "") as $other
    | [$lts, $other] | map(select(length > 0)) | join(" ")')
  [ -n "$sel" ] || die "could not determine supported channels from releases-index.json"
  read -r -a CHANNELS <<<"$sel"
  log "LTS channel: ${CHANNELS[0]}   other supported channel: ${CHANNELS[1]:-none}"
fi

# --- 2. decide where to install --------------------------------------------
# Prefer the root of an existing dotnet so all SDKs live under one host (a
# second root would hide the SDKs from each other). Fall back to ~/.dotnet.
SUDO=""
if [ -n "${DOTNET_INSTALL_DIR:-}" ]; then
  ROOT="$DOTNET_INSTALL_DIR"
elif command -v dotnet >/dev/null 2>&1; then
  ROOT="$(dirname "$(readlink -f "$(command -v dotnet)")")"
  if [ ! -w "$ROOT" ]; then
    if command -v sudo >/dev/null 2>&1; then SUDO="sudo"; warn "existing dotnet root $ROOT is not writable; using sudo"
    else ROOT="$HOME/.dotnet"; warn "existing dotnet root is not writable and no sudo; installing to $ROOT instead"; fi
  fi
else
  ROOT="$HOME/.dotnet"
fi
log "install root: $ROOT"

# --- 3. install each channel that is missing --------------------------------
have_sdks=$(command -v dotnet >/dev/null 2>&1 && dotnet --list-sdks 2>/dev/null | awk '{print $1}' || true)
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
curl -fsSL --max-time 60 "$SCRIPT_URL" -o "$tmp" || die "could not fetch $SCRIPT_URL"
chmod +x "$tmp"

installed_any=0
for ch in "${CHANNELS[@]}"; do
  # Latest non-preview SDK version for this channel, from the index.
  latest=$(printf '%s' "${index:-}" | jq -r --arg ch "$ch" '.["releases-index"][] | select(.["channel-version"]==$ch) | .["latest-sdk"] // ""' 2>/dev/null || true)
  if [ -n "$latest" ] && printf '%s\n' "$have_sdks" | grep -qx "$latest"; then
    log "SDK $latest already installed"; continue
  fi
  if [ -z "$latest" ] && printf '%s\n' "$have_sdks" | grep -q "^${ch%%.*}\."; then
    log "SDK for channel $ch already present (offline check)"; continue
  fi
  log "installing SDK channel $ch${latest:+ ($latest)}"
  # --channel X.Y installs the latest *released* SDK on that channel. Never
  # pass --quality preview/daily here.
  $SUDO "$tmp" --channel "$ch" --install-dir "$ROOT" --no-path
  installed_any=1
done

# --- 4. PATH / DOTNET_ROOT for a user-local root -----------------------------
already_on_path=0
case ":$PATH:" in *":$HOME/.dotnet:"*) already_on_path=1 ;; esac
grep -aqs 'DOTNET_ROOT' "$HOME/.profile" "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile" 2>/dev/null && already_on_path=1
if [ "$ROOT" = "$HOME/.dotnet" ] && [ "$already_on_path" -eq 0 ]; then
  block='# dotnet (ClaudeDefaultSetup)
export DOTNET_ROOT="$HOME/.dotnet"
case ":$PATH:" in *":$DOTNET_ROOT:"*) ;; *) export PATH="$DOTNET_ROOT:$DOTNET_ROOT/tools:$PATH" ;; esac'
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$rc" ] || continue
    grep -aq 'dotnet (ClaudeDefaultSetup)' "$rc" || { printf '\n%s\n' "$block" >> "$rc"; log "added DOTNET_ROOT/PATH to $rc"; }
  done
  export DOTNET_ROOT="$HOME/.dotnet"; export PATH="$DOTNET_ROOT:$PATH"
fi

# --- 5. report ---------------------------------------------------------------
if command -v dotnet >/dev/null 2>&1; then
  log "SDKs now present:"; dotnet --list-sdks | sed 's/^/         /'
  if dotnet --list-sdks | grep -Eq -- '-(preview|rc|alpha|beta)'; then
    warn "a preview/RC SDK is also installed. It was not installed by this script; remove it if unwanted."
    warn "a global.json in a repo controls which SDK is used; without one the highest version wins, including previews."
  fi
else
  warn "dotnet not on PATH in this shell yet; open a new shell."
fi
[ "$installed_any" -eq 1 ] && log "done (new SDKs installed)" || log "done (nothing to install)"
