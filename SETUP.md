# Claude Code default setup

Claude: you have been pointed at this repo to set up Claude Code on a new machine.

## Fast path (preferred)

Run the installer from the repo root and then the verifier:

```bash
./install.sh && ./verify.sh
```

(Windows: `.\install.ps1` from PowerShell 7, then `./verify.sh` from Git Bash.)

The installer is idempotent and covers every module below. If it stops with an
error, read the message, fix the dependency it names (usually `jq` or `pipx`),
and re-run. If a step needs a decision from me (an existing `core.hooksPath`,
a `claude mcp add` that could not run), report it rather than working around it.

## Manual path

If the installer cannot run, work through the modules **in order**. Each
module's `INSTALL.md` is a self-contained set of instructions; follow it exactly.

| # | Module | Instructions | What it does |
|---|--------|--------------|--------------|
| 0 | GitHub CLI | [gh/INSTALL.md](gh/INSTALL.md) | Installs `gh` if missing (brew / apt repo / dnf / pacman / apk / release tarball); reminds you to `gh auth login` |
| 1 | Status line | [statusline/INSTALL.md](statusline/INSTALL.md) | Installs `statusline.sh` |
| 2 | Attribution fix | [attribution/INSTALL.md](attribution/INSTALL.md) | Empty commit/PR attribution plus a global `commit-msg` hook backstop |
| 3 | Hooks | [hooks/INSTALL.md](hooks/INSTALL.md) | Bash guard, format-on-edit, long-turn notification, ProjectMan session context |
| 4 | Slash commands | [commands/INSTALL.md](commands/INSTALL.md) | `/commit`, `/review`, `/handoff`, `/deploy-check` |
| 5 | Skills | [skills/INSTALL.md](skills/INSTALL.md) | `/setup-project`: per-repo CLAUDE.md, deploy detection, project SessionStart hook, ProjectMan init |
| 6 | Settings template | [settings/INSTALL.md](settings/INSTALL.md) | Merges statusLine, attribution, env, permissions allow/deny and hook wiring into user `settings.json` |
| 7 | .NET SDKs | [dotnet/INSTALL.md](dotnet/INSTALL.md) | Current LTS + newest other supported SDK via the official dotnet-install script, no previews |
| 8 | ProjectMan | [projectman/INSTALL.md](projectman/INSTALL.md) | Pinned `pipx` install, `projectman setup-claude --global`, six-doc init wizard skill |

## Rules for every module

- Only touch the **user** config (`~/.claude/`, or `$CLAUDE_CONFIG_DIR` if set). Never edit a project's `.claude/` without asking.
- Back up any file before overwriting it (`<file>.bak`).
- Merge into `settings.json` with `jq` (or `settings/merge.sh`); never rewrite it as text.
- Copy files from this repo with `cp` so they stay byte-identical; do not retype them.
- Do not commit anything to any repo as part of setup.
- Finish with `./verify.sh` and give me one combined report: paths written, backups made, anything that needs my attention, and a reminder to restart Claude Code.
