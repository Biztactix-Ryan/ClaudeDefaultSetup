#!/usr/bin/env bash
# Desktop / ntfy notification when a long turn finishes.
#   UserPromptSubmit -> notify.sh start   (records when the turn began)
#   Stop             -> notify.sh stop    (notifies if it ran long enough)
#
# Config (env, or ~/.claude/notify.env which is sourced if present):
#   NTFY_TOPIC                 ntfy topic; if set, POST to $NTFY_URL/$NTFY_TOPIC
#   NTFY_URL                   default https://ntfy.sh
#   NTFY_TOKEN                 optional bearer token for a private ntfy server
#   CLAUDE_NOTIFY_MIN_SECONDS  only notify when the turn took at least this (default 120)
#   CLAUDE_NOTIFY_DISABLE      set to 1 to turn off
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
[ -f "$CFG/notify.env" ] && . "$CFG/notify.env"
[ -n "$CLAUDE_NOTIFY_DISABLE" ] && exit 0

input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // "default"' 2>/dev/null)
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""' 2>/dev/null)
run="${XDG_RUNTIME_DIR:-/tmp}/claude-notify-${USER:-u}"
mkdir -p "$run" 2>/dev/null
stamp="$run/$sid"

case "${1:-}" in
  start)
    date +%s > "$stamp"
    exit 0 ;;
  stop)
    [ -f "$stamp" ] || exit 0
    started=$(cat "$stamp"); rm -f "$stamp"
    now=$(date +%s); elapsed=$(( now - started ))
    min=${CLAUDE_NOTIFY_MIN_SECONDS:-120}
    [ "$elapsed" -ge "$min" ] || exit 0
    if [ "$elapsed" -ge 3600 ]; then took="$((elapsed/3600))h $(( (elapsed%3600)/60 ))m"
    else took="$((elapsed/60))m $((elapsed%60))s"; fi
    proj="${cwd##*/}"; [ -z "$proj" ] && proj="Claude Code"
    title="Claude finished: $proj"
    msg="Turn took $took. Session ${sid:0:8} in $cwd"

    if [ -n "$NTFY_TOPIC" ] && command -v curl >/dev/null 2>&1; then
      auth=(); [ -n "$NTFY_TOKEN" ] && auth=(-H "Authorization: Bearer $NTFY_TOKEN")
      curl -fsS -m 10 "${auth[@]}" -H "Title: $title" -H "Tags: robot" -d "$msg" \
        "${NTFY_URL:-https://ntfy.sh}/$NTFY_TOPIC" >/dev/null 2>&1 || true
    fi
    if command -v notify-send >/dev/null 2>&1; then
      notify-send -a "Claude Code" "$title" "$msg" >/dev/null 2>&1 || true
    elif command -v osascript >/dev/null 2>&1; then
      osascript -e "display notification \"$msg\" with title \"$title\"" >/dev/null 2>&1 || true
    elif command -v powershell.exe >/dev/null 2>&1; then
      powershell.exe -NoProfile -Command "[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')|Out-Null; \$n=New-Object System.Windows.Forms.NotifyIcon; \$n.Icon=[System.Drawing.SystemIcons]::Information; \$n.Visible=\$true; \$n.ShowBalloonTip(5000,'$title','$msg',[System.Windows.Forms.ToolTipIcon]::Info)" >/dev/null 2>&1 || true
    fi
    exit 0 ;;
  *)
    echo "usage: notify.sh start|stop" >&2; exit 0 ;;
esac
