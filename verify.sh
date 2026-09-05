#!/usr/bin/env bash
# Check that the machine has what ClaudeDefaultSetup expects. Exit 1 on any FAIL.
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
ok()   { printf '  \033[32mPASS\033[0m  %s\n' "$*"; }
warn() { printf '  \033[33mWARN\033[0m  %s\n' "$*"; }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$*"; fail=1; }
ver()  { "$@" 2>/dev/null | head -1 | tr -d '\r'; }

echo "Tools"
for t in bash jq git awk; do command -v "$t" >/dev/null 2>&1 && ok "$t  $(ver "$t" --version)" || bad "$t missing (required)"; done
command -v pipx       >/dev/null 2>&1 && ok "pipx  $(ver pipx --version)"           || bad "pipx missing (needed for ProjectMan)"
command -v projectman >/dev/null 2>&1 && ok "projectman  $(pipx list --short 2>/dev/null | grep -i '^projectman' || echo installed)" || bad "projectman missing: run projectman/install.sh"
if command -v dotnet >/dev/null 2>&1; then
  sdks=$(dotnet --list-sdks 2>/dev/null | awk '{print $1}' | tr '\n' ' ')
  ok "dotnet SDKs: ${sdks:-none}"
  stable=$(printf '%s' "$sdks" | tr ' ' '\n' | grep -Evc -- '-(preview|rc|alpha|beta)' || true)
  [ "${stable:-0}" -ge 1 ] || bad "no released (non-preview) .NET SDK installed (run dotnet/install.sh)"
else
  bad "dotnet missing (run dotnet/install.sh)"
fi
if command -v gh >/dev/null 2>&1; then
  ok "gh  $(ver gh --version)"
  gh auth status >/dev/null 2>&1 && ok "gh authenticated" || warn "gh not logged in (run: gh auth login)"
else
  bad "gh missing (run gh/install.sh)"
fi
command -v claude     >/dev/null 2>&1 && ok "claude  $(ver claude --version)"       || warn "claude CLI not on PATH (MCP registration needs it)"

echo "Claude config ($CFG)"
if [ -f "$CFG/settings.json" ]; then
  if jq -e . "$CFG/settings.json" >/dev/null 2>&1; then
    ok "settings.json is valid JSON"
    for k in statusLine attribution permissions hooks env; do
      jq -e ".$k" "$CFG/settings.json" >/dev/null 2>&1 && ok "settings.$k present" || bad "settings.$k missing (run settings/merge.sh)"
    done
    jq -e '.includeCoAuthoredBy' "$CFG/settings.json" >/dev/null 2>&1 && warn "deprecated includeCoAuthoredBy still present" || true
    for ev in PreToolUse PostToolUse Stop SessionStart UserPromptSubmit; do
      jq -e ".hooks.$ev" "$CFG/settings.json" >/dev/null 2>&1 || bad "hooks.$ev not wired"
    done
  else
    bad "settings.json is NOT valid JSON"
  fi
else
  bad "settings.json missing"
fi

echo "Status line"
if [ -x "$CFG/statusline.sh" ]; then
  out=$(echo '{}' | "$CFG/statusline.sh" 2>&1)
  case "$out" in *null*) bad "statusline.sh printed 'null' for empty input" ;; *claude*) ok "statusline.sh runs: $(printf '%s' "$out" | sed 's/\x1b\[[0-9;]*m//g')" ;; *) bad "statusline.sh unexpected output: $out" ;; esac
  cmp -s "$HERE/statusline/statusline.sh" "$CFG/statusline.sh" && ok "statusline.sh matches repo" || warn "statusline.sh differs from repo copy (re-run install.sh to update)"
else
  bad "statusline.sh missing or not executable"
fi

echo "Hooks"
for h in bash-guard.sh format-on-edit.sh notify.sh session-start.sh; do
  [ -x "$CFG/hooks/$h" ] && ok "hooks/$h" || bad "hooks/$h missing or not executable"
done
if [ -x "$CFG/hooks/bash-guard.sh" ]; then
  d=$(jq -n '{tool_input:{command:"git push --force origin main"}}' | "$CFG/hooks/bash-guard.sh")
  printf '%s' "$d" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 && ok "bash-guard denies force push" || bad "bash-guard did not deny force push"
fi

echo "Commands and skills"
for c in commit review handoff deploy-check; do [ -f "$CFG/commands/$c.md" ] && ok "/$c" || bad "commands/$c.md missing"; done
for s in pm pm-status pm-plan pm-do pm-orchestrate pm-autoscope pm-cleanup projectman-init-wizard; do
  [ -f "$CFG/skills/$s/SKILL.md" ] && ok "skill $s" || bad "skill $s missing (projectman setup-claude --global / projectman/install.sh)"
done
for d in "$HERE"/skills/*/; do
  s=$(basename "$d")
  if [ -f "$CFG/skills/$s/SKILL.md" ]; then
    cmp -s "$d/SKILL.md" "$CFG/skills/$s/SKILL.md" && ok "skill $s" || warn "skill $s differs from repo copy (re-run install.sh)"
  else bad "skill $s missing (install.sh --only skills)"; fi
done
[ -f "$CFG/agents/pm.md" ] && ok "agent pm" || warn "agents/pm.md missing"
if command -v claude >/dev/null 2>&1; then
  claude mcp list 2>/dev/null | grep -qi projectman && ok "MCP server projectman registered" || warn "projectman MCP server not registered (claude mcp add --scope user projectman -- projectman serve)"
fi
if command -v projectman >/dev/null 2>&1; then
  hs=$(printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"verify","version":"0"}}}' | timeout 30 projectman serve 2>&1 | head -c 400 || true)
  case "$hs" in *'"result"'*) ok "projectman serve answers MCP initialize" ;; *) bad "projectman serve failed MCP handshake: $(printf '%s' "$hs" | head -1)" ;; esac
fi

echo "Git attribution"
hp=$(git config --global core.hooksPath 2>/dev/null)
[ -n "$hp" ] && ok "core.hooksPath=$hp" || bad "core.hooksPath not set"
[ -x "$HOME/.git-hooks/commit-msg" ] && ok "~/.git-hooks/commit-msg" || warn "~/.git-hooks/commit-msg missing"
if [ -f "$CFG/settings.json" ]; then
  jq -e '.attribution.commit == "" and .attribution.pr == ""' "$CFG/settings.json" >/dev/null 2>&1 && ok "attribution disabled in settings" || bad "attribution not disabled in settings"
fi

echo
[ $fail -eq 0 ] && echo "All checks passed." || { echo "Some checks FAILED."; exit 1; }
