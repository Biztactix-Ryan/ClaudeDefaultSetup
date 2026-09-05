# ClaudeDefaultSetup

Baseline Claude Code configuration for a new machine: status line, git attribution suppression, guard/format/notify hooks, slash commands, a `/setup-project` skill for onboarding repos, a settings template, and ProjectMan pinned to a known-good ref.

Once installed, run `/setup-project` inside any repo to detect its stack and deploy target, write a concise `CLAUDE.md`, add a project SessionStart hook with ProjectMan status, and initialise ProjectMan if needed.

## Usage

Open Claude Code on the new machine and paste:

```
Clone https://github.com/Biztactix-Ryan/ClaudeDefaultSetup.git into a temp directory, read SETUP.md, and follow it.
```

Or do it by hand:

```bash
git clone https://github.com/Biztactix-Ryan/ClaudeDefaultSetup.git
cd ClaudeDefaultSetup
./install.sh        # idempotent; re-run any time to pull updates
./verify.sh         # checks tools, settings.json, hooks, skills, commands
```

Windows: `.\install.ps1` in PowerShell 7 (needs Git for Windows and jq), then `./verify.sh` from Git Bash.

`./install.sh --only statusline,hooks` installs a subset; `--skip-projectman` and `--skip-dotnet` skip those steps.

## What gets installed

| Where | What |
|-------|------|
| `~/.claude/statusline.sh` | model · effort │ project │ git branch │ context │ session cost │ weekly quota with pace gap (+/- vs even daily burn) and reset countdown in the last 48h |
| `~/.claude/settings.json` | merged, never replaced: `statusLine`, `attribution` off, 2-year session retention (`cleanupPeriodDays`), telemetry-off `env`, permissions allow/deny lists, hook wiring |
| `~/.claude/hooks/` | `bash-guard.sh` (deny force push, `rm -rf /`, DROP TABLE, secret dumps), `format-on-edit.sh` (dotnet format / prettier / ruff), `notify.sh` (ntfy or desktop after long turns), `session-start.sh` (ProjectMan summary) |
| `~/.claude/commands/` | `/commit`, `/review`, `/handoff`, `/deploy-check` |
| `~/.claude/skills/` | `setup-project` (per-repo onboarding), `pm*` from `projectman setup-claude --global`, `projectman-init-wizard` |
| `~/.git-hooks/commit-msg` + `core.hooksPath` | strips any Claude attribution trailer as a backstop |
| pipx | `projectman[all]` at the ref pinned in `projectman/install.sh` |
| .NET | current LTS SDK + newest other supported SDK channel (no previews), chosen from Microsoft's releases index |

## Layout

```
install.sh / install.ps1   idempotent installers (all modules, or --only)
verify.sh                  post-install checks
SETUP.md                   what Claude follows when pointed at the repo
statusline/                statusline.sh + INSTALL.md
attribution/               commit-msg hook + INSTALL.md
hooks/                     four hook scripts + INSTALL.md
commands/                  four slash commands + INSTALL.md
skills/                    setup-project skill + INSTALL.md
settings/                  settings.template.json, merge.sh, INSTALL.md
dotnet/                    install.sh (LTS + newest other supported SDK), INSTALL.md
projectman/                install.sh (pinned), skills/projectman-init-wizard, INSTALL.md
```

## Adding a module

1. Create `<module>/INSTALL.md` with the exact instructions Claude should follow.
2. Put any files to be installed alongside it, so they can be copied rather than retyped.
3. Add the copy step to `install.sh` (and `install.ps1`), a check to `verify.sh`, and a row to the table in `SETUP.md`.

## Notifications

`hooks/notify.sh` reads `~/.claude/notify.env` (never tracked). Set `NTFY_TOPIC` for push notifications; otherwise it falls back to the desktop notifier.

## Requirements

`bash`, `jq`, `git`, `awk`; `pipx` for ProjectMan; `dotnet` / `prettier` / `ruff` optional for the format hook. The status line's git segment uses a Nerd Font glyph; install a Nerd Font in the terminal if it renders as a box.

## Public repo

This repo is public. Nothing in it may contain credentials, tokens, hostnames of private infrastructure, personal names or emails. Machine-specific values (ntfy topics, tokens) go in `~/.claude/notify.env`, which `.gitignore` excludes.
