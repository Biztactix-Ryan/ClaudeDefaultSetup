#!/usr/bin/env bash
# ProjectMan: pinned pipx install -> setup-claude --global -> init-wizard skill.
# Idempotent: re-running upgrades to the pinned ref and rewrites the skills.
set -euo pipefail

# --- pin ---------------------------------------------------------------------
# Bump this deliberately. ProjectMan has no release tags yet, so the pin is a
# commit SHA (main @ 2026-09-02, pyproject version 0.8.15). Override with
# PROJECTMAN_REF=<sha|tag|branch> for testing.
PROJECTMAN_REF="${PROJECTMAN_REF:-aae7e091c530f66fe092363e6a95e17f4baf2c72}"
PROJECTMAN_REPO="https://github.com/Biztactix-Ryan/ProjectMan.git"
SPEC="projectman[all] @ git+${PROJECTMAN_REPO}@${PROJECTMAN_REF}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

log() { printf '\033[36m[projectman]\033[0m %s\n' "$*"; }
die() { printf '\033[31m[projectman] %s\033[0m\n' "$*" >&2; exit 1; }

# --- 1. pipx -----------------------------------------------------------------
if ! command -v pipx >/dev/null 2>&1; then
  cat >&2 <<'MSG'
pipx is not installed. Install it, then re-run:
  Debian/Ubuntu : sudo apt install pipx && pipx ensurepath
  macOS         : brew install pipx && pipx ensurepath
  Windows       : py -m pip install --user pipx && py -m pipx ensurepath
  generic       : python3 -m pip install --user pipx && python3 -m pipx ensurepath
MSG
  exit 1
fi

CONSTRAINTS="${HERE}/constraints.txt"
log "installing ${SPEC}"
log "with pip constraints from ${CONSTRAINTS}: $(grep -v '^#' "${CONSTRAINTS}" | grep -v '^$' | tr '\n' ' ')"
# --force makes this an upgrade/reinstall when projectman is already present.
# --constraint pins transitive deps ProjectMan leaves open (see constraints.txt).
pipx install --force --pip-args="--constraint ${CONSTRAINTS}" "${SPEC}"

command -v projectman >/dev/null 2>&1 || die "projectman not on PATH after install. Run 'pipx ensurepath' and open a new shell."
log "installed: $(pipx list --short 2>/dev/null | grep -i '^projectman' || echo projectman)"

# Smoke-test the MCP server with an initialize handshake; "registered" is not "works".
hs=$(printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"setup","version":"0"}}}' \
     | timeout 30 projectman serve 2>&1 | head -c 2000 || true)
case "$hs" in
  *'"result"'*) log "MCP server answers initialize OK" ;;
  *) die "projectman serve failed the MCP handshake:
${hs}
Check projectman/constraints.txt (a transitive dependency probably moved)." ;;
esac

# --- 2. setup-claude ---------------------------------------------------------
# --global writes agents/pm.md + skills/pm* into ~/.claude and registers the
# MCP server at user scope via `claude mcp add` (prints a manual command if the
# claude CLI is not on PATH yet).
log "running projectman setup-claude --global"
projectman setup-claude --global

# --- 3. init wizard skill ----------------------------------------------------
SKILL_SRC="${HERE}/skills/projectman-init-wizard"
SKILL_DST="${CFG}/skills/projectman-init-wizard"
mkdir -p "${SKILL_DST}"
cp "${SKILL_SRC}/SKILL.md" "${SKILL_DST}/SKILL.md"
log "wrote ${SKILL_DST}/SKILL.md"

log "done. Restart Claude Code, then in any repo: /pm init  (or /projectman-init-wizard)"
