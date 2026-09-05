# ProjectMan

Install ProjectMan and its Claude Code integration on this machine, pinned to a known-good ref so a ProjectMan change cannot silently break a new box.

## 1. Run the installer

From this directory of the repo:

```bash
./install.sh
```

It does, in order:
1. `pipx install --force "projectman[all] @ git+https://github.com/Biztactix-Ryan/ProjectMan.git@<pinned ref>"`
   The pin lives at the top of `install.sh` (`PROJECTMAN_REF`). Do not change it during setup.
2. `projectman setup-claude --global` which writes `~/.claude/agents/pm.md` and `~/.claude/skills/pm*/SKILL.md`, and registers the `projectman` MCP server at user scope via `claude mcp add`.
3. Copies `skills/projectman-init-wizard/SKILL.md` to `~/.claude/skills/projectman-init-wizard/` so `/pm init` and the six-doc context wizard (VISION, ARCHITECTURE, PROJECT, INFRASTRUCTURE, SECURITY, DECISIONS) are available in every repo.

If `pipx` is missing the script stops and prints the install command for this OS. Install it and re-run; do not substitute `pip install`.

If `projectman setup-claude` reports that the `claude` CLI was not found, run the `claude mcp add ...` command it prints once Claude Code is installed, then re-run `./install.sh` (it is idempotent).

## 2. Verify

```bash
projectman --version || pipx list | grep -i projectman
claude mcp list | grep -i projectman
ls ~/.claude/skills/ | grep -E '^pm|projectman-init-wizard'
```

Expected: projectman on PATH, `projectman` listed as a user-scope MCP server, and skills `pm`, `pm-status`, `pm-plan`, `pm-do`, `pm-orchestrate`, `pm-autoscope`, `pm-cleanup`, `projectman-init-wizard`.

## 3. Report

Tell me the installed ProjectMan version and pinned ref, whether the MCP server registered, and the list of skills written. Remind me to restart Claude Code.

## Bumping the pin

Edit `PROJECTMAN_REF` in `install.sh` to the new commit SHA (or a tag once ProjectMan has them), commit, and re-run `./install.sh` on each machine. The `--force` flag makes re-running an upgrade.
