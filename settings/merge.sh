#!/usr/bin/env bash
# Merge settings.template.json into the user settings.json without clobbering
# anything the template does not mention.
#
#   usage: merge.sh [template] [target]
#   default template: ./settings.template.json
#   default target:   $CLAUDE_CONFIG_DIR/settings.json  (~/.claude/settings.json)
#
# Semantics:
#   objects            recursive merge, template wins on conflicting scalars
#   permissions.allow  union (existing + template, deduplicated)
#   permissions.deny   union
#   hooks.<Event>      union of matcher groups, deduplicated by content
#   includeCoAuthoredBy removed (deprecated, replaced by "attribution")
# Idempotent: running it twice yields the same file.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${1:-$HERE/settings.template.json}"
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
TARGET="${2:-$CFG/settings.json}"

command -v jq >/dev/null 2>&1 || { echo "merge.sh: jq is required" >&2; exit 1; }
jq -e . "$TEMPLATE" >/dev/null || { echo "merge.sh: template is not valid JSON: $TEMPLATE" >&2; exit 1; }

mkdir -p "$(dirname "$TARGET")"
if [ -f "$TARGET" ]; then
  jq -e . "$TARGET" >/dev/null || { echo "merge.sh: existing settings is not valid JSON, refusing to touch: $TARGET" >&2; exit 1; }
  current="$TARGET"
else
  current=/dev/null
fi

# When CLAUDE_CONFIG_DIR points somewhere non-default, rewrite ~/.claude paths
# in the template so hook/statusline commands resolve.
tpl_json=$(cat "$TEMPLATE")
if [ "$CFG" != "$HOME/.claude" ]; then
  tpl_json=$(printf '%s' "$tpl_json" | sed "s#~/\.claude#${CFG}#g")
fi

merged=$(jq -s '
  def arr(x): if x == null then [] else x end;
  def union(a; b): (arr(a) + arr(b)) | unique;
  (.[0] // {}) as $cur | .[1] as $tpl |
  ($cur * $tpl)
  | del(.includeCoAuthoredBy)
  | if ($cur.permissions != null or $tpl.permissions != null) then
      .permissions.allow = union($cur.permissions.allow; $tpl.permissions.allow)
      | .permissions.deny = union($cur.permissions.deny; $tpl.permissions.deny)
    else . end
  | if ($cur.hooks != null or $tpl.hooks != null) then
      .hooks = ( (($cur.hooks // {}) + ($tpl.hooks // {}))
        | with_entries(.key as $k | .value = union(($cur.hooks // {})[$k]; ($tpl.hooks // {})[$k])) )
    else . end
' <(if [ "$current" = /dev/null ]; then echo '{}'; else cat "$current"; fi) <(printf '%s' "$tpl_json"))

if [ -f "$TARGET" ]; then
  if [ "$(jq -S . "$TARGET")" = "$(printf '%s' "$merged" | jq -S .)" ]; then
    echo "settings.json already up to date: $TARGET"
    exit 0
  fi
  cp "$TARGET" "$TARGET.bak"
  echo "backed up to $TARGET.bak"
fi
printf '%s\n' "$merged" > "$TARGET"
echo "wrote $TARGET"
