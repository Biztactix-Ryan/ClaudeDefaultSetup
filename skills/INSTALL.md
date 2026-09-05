# Skills

Skills shipped by this repo (ProjectMan's own `pm*` skills come from `projectman setup-claude --global`; the six-doc wizard lives under `../projectman/skills/`).

| Skill | Does |
|-------|------|
| `/setup-project [--no-pm] [--refresh]` | Onboards the current repo: detects stack, commands, deploy target (Coolify, Docker/Compose, Proxmox, k8s, systemd, cloud PaaS, IIS) and deploy scripts with evidence; writes a concise `CLAUDE.md` inside `<!-- setup-project:start/end -->` markers so re-runs only touch that block; installs `.claude/hooks/pm-context.sh` plus a project `SessionStart` hook that injects ProjectMan status; runs `projectman init` and the `projectman-init-wizard` when `.project/` is missing. Never commits, never prints secret values. |

## Install

```bash
for d in */; do mkdir -p ~/.claude/skills/"$d" && cp "$d/SKILL.md" ~/.claude/skills/"$d"; done
```

(`install.sh --only skills` does the same with backups.)

## Verify

Type `/setup-project` in Claude Code inside any repo; the skill should appear in the picker with its description.
