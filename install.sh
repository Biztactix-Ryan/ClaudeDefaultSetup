#!/usr/bin/env bash
# ClaudeDefaultSetup installer. Idempotent: re-run any time to pull updates.
#
#   ./install.sh                 everything
#   ./install.sh --skip-projectman   everything except pipx/ProjectMan
#   ./install.sh --only statusline,hooks
#
# Touches only the user Claude config ($CLAUDE_CONFIG_DIR, default ~/.claude),
# ~/.git-hooks, and git's global core.hooksPath. Never commits anything.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
ONLY=""; SKIP_PM=0
while [ $# -gt 0 ]; do
  case "$1" in
    --only) ONLY="$2"; shift 2 ;;
    --only=*) ONLY="${1#--only=}"; shift ;;
    --skip-projectman) SKIP_PM=1; shift ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
want() { [ -z "$ONLY" ] || [[ ",$ONLY," == *",$1,"* ]]; }

log()  { printf '\033[36m[setup]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[setup] %s\033[0m\n' "$*"; }
die()  { printf '\033[31m[setup] %s\033[0m\n' "$*" >&2; exit 1; }

# Copy $1 to $2, backing up $2 to $2.bak only when content differs.
install_file() {
  local src="$1" dst="$2" mode="${3:-644}"
  mkdir -p "$(dirname "$dst")"
  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
    chmod "$mode" "$dst"; return 0
  fi
  if [ -f "$dst" ]; then cp -p "$dst" "$dst.bak"; log "backed up $dst -> $dst.bak"; fi
  cp "$src" "$dst"; chmod "$mode" "$dst"; log "wrote $dst"
}

# --- 0. dependencies ---------------------------------------------------------
missing=()
for t in bash jq git awk; do command -v "$t" >/dev/null 2>&1 || missing+=("$t"); done
if [ ${#missing[@]} -gt 0 ]; then
  die "missing: ${missing[*]}. jq install: apt install jq | brew install jq | winget install jqlang.jq"
fi
mkdir -p "$CFG"

# --- 1. status line ----------------------------------------------------------
if want statusline; then
  install_file "$HERE/statusline/statusline.sh" "$CFG/statusline.sh" 755
fi

# --- 2. attribution: global commit-msg hook ----------------------------------
if want attribution; then
  install_file "$HERE/attribution/commit-msg" "$HOME/.git-hooks/commit-msg" 755
  current_hp=$(git config --global core.hooksPath 2>/dev/null || true)
  case "$current_hp" in
    "") git config --global core.hooksPath "$HOME/.git-hooks"; log "set core.hooksPath=$HOME/.git-hooks" ;;
    "$HOME/.git-hooks"|"~/.git-hooks") : ;;
    *) warn "core.hooksPath is already '$current_hp' (Husky or similar). Left unchanged."
       warn "To use the attribution backstop too, add the commit-msg logic to that hooks directory." ;;
  esac
fi

# --- 3. hooks ----------------------------------------------------------------
if want hooks; then
  for s in "$HERE"/hooks/*.sh; do install_file "$s" "$CFG/hooks/$(basename "$s")" 755; done
fi

# --- 4. slash commands -------------------------------------------------------
if want commands; then
  for c in "$HERE"/commands/*.md; do
    [ "$(basename "$c")" = INSTALL.md ] && continue
    install_file "$c" "$CFG/commands/$(basename "$c")"
  done
fi

# --- 5. settings.json merge (statusLine, attribution, env, permissions, hooks)
if want settings; then
  "$HERE/settings/merge.sh"
fi

# --- 6. ProjectMan -----------------------------------------------------------
if want projectman && [ "$SKIP_PM" -eq 0 ]; then
  "$HERE/projectman/install.sh" || warn "ProjectMan step failed; fix the message above and re-run ./install.sh --only projectman"
fi

# --- done --------------------------------------------------------------------
log "done. Restart Claude Code (or start a new session) to pick up the status line, hooks and commands."
log "Run ./verify.sh to check the result."
