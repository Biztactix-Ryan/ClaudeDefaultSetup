#!/usr/bin/env bash
# Public-repo safety check. Fails if the tree contains anything that looks like
# personal data, credentials, private hostnames, or code that configures a git
# or GitHub identity. Run before pushing; CI runs it on every push.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
fail=0
hit() { printf '\033[31mFAIL\033[0m %s\n' "$1"; printf '%s\n' "$2" | sed 's/^/     /'; fail=1; }

files=$(git ls-files | grep -vE '^check-public\.sh$')

# Allowed: the public URLs of this repo and its sibling projects.
ALLOW_URL='github\.com/[A-Za-z0-9_-]+/(ClaudeDefaultSetup|ProjectMan)|raw\.githubusercontent\.com/[A-Za-z0-9_-]+/ClaudeDefaultSetup'

# --- personal data ---------------------------------------------------------
out=$(grep -nE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' $files | grep -vE 'noreply@anthropic|Co-Authored-By|example\.com' )
[ -n "$out" ] && hit "email address" "$out"
out=$(grep -nE '(/home|/Users)/[a-z][a-z0-9_-]+|C:\\\\Users\\\\[A-Za-z]' $files | grep -vE '\$HOME|~/|/home/\[a-z\]\+|\(/home\|/Users\)')
[ -n "$out" ] && hit "user home path" "$out"
out=$(grep -nEi '\.com\.au|forgejo|gitea\.|\b[a-z0-9-]+\.(lan|home|internal|local)\b' $files | grep -vE '\.local/(bin|share|pipx)|Local(AppData)?|settings\.local\.json|\.env\.local')
[ -n "$out" ] && hit "private hostname / domain" "$out"
out=$(grep -nE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' $files | grep -vE '127\.0\.0\.1|0\.0\.0\.0')
[ -n "$out" ] && hit "IP address" "$out"

# --- credentials -------------------------------------------------------------
out=$(grep -nE 'ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|github_pat_|sk-[A-Za-z0-9]{20,}|xox[abp]-|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY|NTFY_TOKEN=[^ ]+[A-Za-z0-9]' $files)
[ -n "$out" ] && hit "credential-like string" "$out"

# --- identity configuration --------------------------------------------------
scripts=$(printf '%s\n' $files | grep -E '\.(sh|ps1)$')
out=$(grep -nE 'git config( --global)? +user\.(name|email)|user\.signingkey|credential\.helper' $scripts)
[ -n "$out" ] && hit "script configures git identity" "$out"
# flag only when it is executed as a command (line start or after ; & |), not quoted in a message
out=$(grep -nE '(^|[;&|(] *)(\$SUDO +)?gh auth (login|setup-git|refresh)' $scripts | grep -vE '^[^:]+:[0-9]+:\s*#')
[ -n "$out" ] && hit "script runs gh auth login" "$out"

# --- account name outside the allowed public URLs ----------------------------
owner=$(git remote get-url origin 2>/dev/null | sed -E 's#.*[:/]([^/]+)/[^/]+(\.git)?$#\1#')
if [ -n "$owner" ]; then
  out=$(grep -n "$owner" $files | grep -vE "$ALLOW_URL")
  [ -n "$out" ] && hit "repo owner name outside a public repo URL" "$out"
fi

[ $fail -eq 0 ] && echo "public-safety check passed" || { echo "public-safety check FAILED"; exit 1; }
