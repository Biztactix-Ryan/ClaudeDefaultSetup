#!/usr/bin/env bash
# PostToolUse on Edit|Write|MultiEdit: format the touched file in place so
# formatting never becomes a review comment.
#   .cs                       -> dotnet format (nearest .csproj/.sln)
#   js/ts/json/css/md/yaml... -> prettier, only if the project (or PATH) has it
#   .py                       -> ruff format, if present
# Never fetches anything (no npx download), never fails the tool call.
input=$(cat)
f=$(printf '%s' "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null)
[ -n "$f" ] && [ -f "$f" ] || exit 0
[ -n "$CLAUDE_FORMAT_DISABLE" ] && exit 0

dir=$(dirname "$f")

# Walk up from $dir looking for the first match of any glob given.
find_up() {
  local d="$1"; shift
  while [ "$d" != "/" ] && [ -n "$d" ]; do
    for pat in "$@"; do
      # shellcheck disable=SC2086
      set -- $pat; local m
      for m in "$d"/$pat; do [ -e "$m" ] && { printf '%s' "$m"; return 0; }; done
    done
    d=$(dirname "$d")
  done
  return 1
}

case "$f" in
  *.cs)
    command -v dotnet >/dev/null 2>&1 || exit 0
    proj=$(find_up "$dir" '*.csproj') || exit 0
    rel=$(realpath --relative-to="$(dirname "$proj")" "$f" 2>/dev/null || echo "$f")
    ( cd "$(dirname "$proj")" && dotnet format "$(basename "$proj")" --include "$rel" --no-restore >/dev/null 2>&1 ) || true
    ;;
  *.js|*.jsx|*.mjs|*.cjs|*.ts|*.tsx|*.json|*.css|*.scss|*.md|*.yaml|*.yml|*.html|*.vue)
    bin=$(find_up "$dir" 'node_modules/.bin/prettier') || bin=$(command -v prettier 2>/dev/null) || exit 0
    "$bin" --write --log-level silent "$f" >/dev/null 2>&1 || "$bin" --write --loglevel silent "$f" >/dev/null 2>&1 || true
    ;;
  *.py)
    if command -v ruff >/dev/null 2>&1; then ruff format --quiet "$f" >/dev/null 2>&1 || true; fi
    ;;
esac
exit 0
