#!/usr/bin/env bash
# Claude Code status line
# mode | project | git branch | context | session cost | weekly quota + pace
#
# Reads the session JSON on stdin (see https://code.claude.com/docs/en/statusline)
# and prints a single coloured line. Every segment degrades gracefully when its
# source field is missing, so a segment disappears rather than printing "null".
input=$(cat)
# Debug: `touch ~/.claude/statusline-debug` to capture the raw payload for
# inspection, so new fields can be wired up without guessing.
[ -e "$HOME/.claude/statusline-debug" ] &&
  printf '%s' "$input" > "$HOME/.claude/statusline-last.json" 2>/dev/null
# --- colours -----------------------------------------------------------------
R=$'\033[0m'; DIM=$'\033[2m'; B=$'\033[1m'
RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'
BLU=$'\033[34m'; MAG=$'\033[35m'; CYN=$'\033[36m'
SEP="${DIM} │ ${R}"
# --- pull every field in one jq pass (fast: one subprocess) ------------------
# Split on US (0x1f): unlike tab, it is not IFS whitespace, so empty fields
# (absent JSON keys) keep their position instead of collapsing.
IFS=$'\x1f' read -r MODEL EFFORT FAST STYLE PROJ_DIR CUR_DIR WORKTREE \
                    CTX_PCT CTX_IN CTX_OUT CTX_MAX \
                    COST WEEK_PCT WEEK_RESET HOUR5_PCT _END <<<"$(
  printf '%s' "$input" | jq -r '
    [ (.model.display_name // ""),
      (.effort.level // ""),
      (.fast_mode // false),
      (.output_style.name // ""),
      (.workspace.project_dir // .cwd // ""),
      (.workspace.current_dir // .cwd // ""),
      (.workspace.git_worktree // .worktree.name // ""),
      (.context_window.used_percentage // 0),
      (.context_window.total_input_tokens // 0),
      (.context_window.total_output_tokens // 0),
      (.context_window.context_window_size // 0),
      (.cost.total_cost_usd // 0),
      (.rate_limits.seven_day.used_percentage // -1),
      (.rate_limits.seven_day.resets_at // 0),
      (.rate_limits.five_hour.used_percentage // -1),
      "end"
    ] | map(tostring) | join("\u001f")' 2>/dev/null)"
parts=()
# --- 1. mode -----------------------------------------------------------------
# Claude Code does not send permission_mode to the status line (it renders that
# in its own footer badges), so "mode" here is model + effort + session flags.
MODEL="${MODEL%% (*}"                       # "Opus 4.8 (1M context)" -> "Opus 4.8"
mode_seg="${CYN}${B}${MODEL:-claude}${R}"
[ -n "$EFFORT" ] && mode_seg+="${DIM}·${R}${CYN}${EFFORT}${R}"
[ "$FAST" = "true" ] && mode_seg+=" ${YEL}⚡${R}"
case "$STYLE" in default|"") ;; *) mode_seg+=" ${MAG}${STYLE}${R}" ;; esac
parts+=("$mode_seg")
# --- 2. project name ---------------------------------------------------------
PROJ="${PROJ_DIR##*/}"
[ -z "$PROJ" ] && PROJ="${CUR_DIR##*/}"
[ -n "$PROJ" ] && seg="${BLU}${B}${PROJ}${R}" || seg=""
# show the sub-directory when cwd has moved below the project root
if [ -n "$CUR_DIR" ] && [ -n "$PROJ_DIR" ] && [ "$CUR_DIR" != "$PROJ_DIR" ]; then
  case "$CUR_DIR" in
    "$PROJ_DIR"/*) seg+="${DIM}/${CUR_DIR#"$PROJ_DIR"/}${R}" ;;
    *)             seg+="${DIM} ⟨${CUR_DIR##*/}⟩${R}" ;;
  esac
fi
[ -n "$seg" ] && parts+=("$seg")
# --- 3. git branch -----------------------------------------------------------
if [ -n "$CUR_DIR" ] && git -C "$CUR_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH=$(git -C "$CUR_DIR" symbolic-ref --quiet --short HEAD 2>/dev/null \
           || git -C "$CUR_DIR" rev-parse --short HEAD 2>/dev/null)
  git_seg="${MAG} ${BRANCH}${R}"
  # dirty marker
  if [ -n "$(git -C "$CUR_DIR" status --porcelain --untracked-files=no 2>/dev/null | head -1)" ]; then
    git_seg+="${YEL}*${R}"
  fi
  # ahead/behind upstream
  counts=$(git -C "$CUR_DIR" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null)
  if [ -n "$counts" ]; then
    behind=${counts%%[[:space:]]*}; ahead=${counts##*[[:space:]]}
    [ "$ahead"  -gt 0 ] 2>/dev/null && git_seg+="${GRN}↑${ahead}${R}"
    [ "$behind" -gt 0 ] 2>/dev/null && git_seg+="${RED}↓${behind}${R}"
  fi
  [ -n "$WORKTREE" ] && git_seg+="${DIM} (wt:${WORKTREE})${R}"
  parts+=("$git_seg")
fi
# --- 4. context used + % -----------------------------------------------------
CTX_PCT_I=${CTX_PCT%%.*}; CTX_PCT_I=${CTX_PCT_I:-0}
if [ "$CTX_MAX" -gt 0 ] 2>/dev/null; then
  read -r used_h max_h <<<"$(awk -v i="$CTX_IN" -v o="$CTX_OUT" -v m="$CTX_MAX" 'BEGIN{
      u=i+o
      printf "%s %s",
        (u>=1000 ? sprintf("%.1fk", u/1000) : sprintf("%d", u)),
        (m>=1000000 ? sprintf("%dM", m/1000000) : sprintf("%dk", m/1000))
  }')"
  if   [ "$CTX_PCT_I" -ge 85 ]; then c=$RED
  elif [ "$CTX_PCT_I" -ge 60 ]; then c=$YEL
  else                               c=$GRN; fi
  parts+=("${DIM}ctx${R} ${c}${used_h}${DIM}/${max_h}${R} ${c}${B}${CTX_PCT_I}%${R}")
fi
# --- 5. session cost ---------------------------------------------------------
parts+=("$(awk -v c="$COST" -v g="$GRN" -v y="$YEL" -v r="$RED" -v d="$DIM" -v z="$R" 'BEGIN{
    col = (c>=5 ? r : (c>=1 ? y : g))
    printf "%s$%s%.2f%s", d, col, c, z
}')")
# --- 6. weekly quota (Pro/Max subscribers only) ------------------------------
# 7d ███│█░░░░░░ 40%·2h +0.8d   bar = usage in 10% cells, │ = where even burn over
# the 7-day window would be right now, fill past │ is red/yellow (over pace),
# +0.8d = usage is 0.8 days ahead of even pace (negative = under). ·2h = time
# to the weekly reset, shown when under 48h away.
if [ "${WEEK_PCT%%.*}" -ge 0 ] 2>/dev/null; then
  W=${WEEK_PCT%%.*}
  if   [ "$W" -ge 85 ]; then c=$RED
  elif [ "$W" -ge 60 ]; then c=$YEL
  else                       c=$GRN; fi
  left=-1
  if [ "${WEEK_RESET%%.*}" -gt 0 ] 2>/dev/null; then
    now=$(date +%s); left=$(( ${WEEK_RESET%%.*} - now ))
  fi
  wk="${DIM}7d${R} "
  wk+="$(awk -v used="$WEEK_PCT" -v left="$left" -v g="$GRN" -v y="$YEL" -v r="$RED" -v d="$DIM" -v b="$B" -v z="$R" 'BEGIN{
      have_pace = (left >= 0 && left <= 604800)
      expected = have_pace ? (604800 - left) / 604800 * 100 : -1
      filled = int(used / 10 + 0.5); if (filled > 10) filled = 10
      pos = have_pace ? int(expected / 10 + 0.5) : -1        # marker after this many cells
      gap = used - expected
      over_col = (gap > 10 ? r : y)
      bar = ""
      for (i = 1; i <= 10; i++) {
        if (i <= filled) {
          col = (have_pace && i > pos) ? over_col : g
          bar = bar col "\342\226\210" z              # full block
        } else {
          bar = bar d "\342\226\221" z                # light shade
        }
        if (have_pace && i == pos) bar = bar b "\342\224\202" z   # marker after cell pos
      }
      if (have_pace && pos == 0) bar = b "\342\224\202" z bar
      printf "%s", bar
  }')"
  wk+=" ${c}${B}${W}%${R}"
  if [ "$left" -gt 0 ] && [ "$left" -lt 172800 ]; then
    if [ "$left" -ge 3600 ]; then wk+="${DIM}·${R}$((left/3600))h"
    else                          wk+="${DIM}·${R}$((left/60))m"; fi
  fi
  if [ "$left" -ge 0 ] && [ "$left" -le 604800 ]; then
    # days ahead (+) or behind (-) of even pace; ~0 counts as on pace (green)
    wk+="$(awk -v used="$WEEK_PCT" -v left="$left" -v g="$GRN" -v y="$YEL" -v r="$RED" -v z="$R" 'BEGIN{
        days = (used - (604800 - left) / 604800 * 100) / 100 * 7
        col = (days > 0.7 ? r : (days > 0.05 ? y : g))
        printf " %s%+.1fd%s", col, days, z
    }')"
  fi
  parts+=("$wk")
fi
# --- join --------------------------------------------------------------------
out=""
for p in "${parts[@]}"; do
  [ -n "$out" ] && out+="$SEP"
  out+="$p"
done
printf '%b\n' "$out"
