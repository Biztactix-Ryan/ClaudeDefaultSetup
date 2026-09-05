# Hooks

Four scripts copied to `~/.claude/hooks/` and wired by `../settings/settings.template.json`. Each reads the hook payload JSON on stdin and needs `jq`.

| Event | Script | What it does |
|-------|--------|--------------|
| `PreToolUse` (Bash) | `bash-guard.sh` | Denies, with a reason: force push (`--force-with-lease` allowed), recursive `rm` of `/`, `~`, `$HOME` or `..`, `--no-preserve-root`, `DROP TABLE/DATABASE/SCHEMA`, `TRUNCATE`, `dotnet ef database drop`, `prisma migrate reset`, `infisical export`/`secrets`, and `cat`/`source` of a real `.env` file (`.env.example` allowed). Read-only front commands (`grep`, `git log`, etc.) are exempt from the SQL check so you can still search migrations. |
| `PostToolUse` (Edit, Write, MultiEdit) | `format-on-edit.sh` | `.cs` files: `dotnet format` on the nearest `.csproj`, scoped to the touched file. JS/TS/JSON/CSS/MD/YAML/HTML/Vue: `prettier --write` only if the project has `node_modules/.bin/prettier` or one is on PATH (never `npx`, so no network). `.py`: `ruff format` if present. Silent, never fails the tool call. `CLAUDE_FORMAT_DISABLE=1` turns it off. |
| `UserPromptSubmit` + `Stop` | `notify.sh start` / `notify.sh stop` | Records when a turn starts; on stop, if the turn took at least `CLAUDE_NOTIFY_MIN_SECONDS` (default 120), sends a notification: ntfy when `NTFY_TOPIC` is set, then `notify-send` (Linux), `osascript` (macOS), or a PowerShell balloon (WSL/Git Bash). |
| `SessionStart` | `session-start.sh` | If the working directory has `.project/config.yaml`, prints a ProjectMan summary (epics/stories/tasks by status, points, in-progress tasks, active sprint, last handoff) into the session context. Uses the pipx venv Python so no extra install. Silent outside ProjectMan projects. This is also the hook point for a future session-observability integration. |

## Install

```bash
mkdir -p ~/.claude/hooks
cp *.sh ~/.claude/hooks/ && chmod +x ~/.claude/hooks/*.sh
../settings/merge.sh          # wires them into settings.json
```

## Notification config

Create `~/.claude/notify.env` (not tracked anywhere) with any of:

```sh
NTFY_TOPIC=your-private-topic
NTFY_URL=https://ntfy.sh          # or a self-hosted server
NTFY_TOKEN=                       # bearer token if the server needs one
CLAUDE_NOTIFY_MIN_SECONDS=120
```

## Verify

```bash
jq -n '{tool_input:{command:"git push --force origin main"}}' | ~/.claude/hooks/bash-guard.sh    # prints a deny JSON
jq -n '{tool_input:{command:"git status"}}' | ~/.claude/hooks/bash-guard.sh                      # prints nothing
echo '{"cwd":"'"$PWD"'"}' | ~/.claude/hooks/session-start.sh                                    # summary if $PWD has .project/
```

Hooks load at session start; restart Claude Code after installing. `/hooks` inside Claude Code lists what is active.
