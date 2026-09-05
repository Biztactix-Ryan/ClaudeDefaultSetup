# Claude Code default setup

Claude: you have been pointed at this repo to set up Claude Code on a new machine.
Work through the modules below **in order**. Each module's `INSTALL.md` is a
self-contained set of instructions; follow it exactly, then move to the next.
Do not skip a module unless I tell you to. Give one combined report at the end
(paths written, backups made, anything that needs my attention).

| # | Module | Instructions | What it does |
|---|--------|--------------|--------------|
| 1 | Status line | [statusline/INSTALL.md](statusline/INSTALL.md) | Installs `statusline.sh` and wires `statusLine` into user `settings.json` |
| 2 | Attribution fix | [attribution/INSTALL.md](attribution/INSTALL.md) | Disables Claude commit/PR attribution and adds a global `commit-msg` hook backstop |

General rules for every module:
- Only touch the **user** config (`~/.claude/`, or `$CLAUDE_CONFIG_DIR` if set). Never edit a project's `.claude/` without asking.
- Back up any file before overwriting it (`<file>.bak`).
- Merge into `settings.json` with `jq`; never rewrite it as text.
- Copy files from this repo with `cp` so they stay byte-identical; do not retype them.
- Do not commit anything to any repo as part of setup.
