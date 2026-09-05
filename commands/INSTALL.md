# Slash commands

Small, opinionated, reusable. Copied to `~/.claude/commands/` so they are available as `/commit`, `/review`, `/handoff`, `/deploy-check` in every project.

| Command | Does |
|---------|------|
| `/commit [note]` | Conventional commit from the **staged** diff only. Adds `Refs: <ID>` (or `Closes:`) when the branch name carries a ProjectMan ID (`US-APP-12`, `US-APP-12-3`, `EPIC-APP-2`). Never adds attribution lines. Stops if nothing is staged. |
| `/review [target]` | Security + correctness pass with a managed-services lens: input validation, injection sinks, auth and tenant boundaries, IDOR, secrets and PII leakage, async and migration correctness. Findings ordered by severity with `file:line`, then a ship / no-ship line. Target may be empty (working tree), a branch, commit, path, or PR number. |
| `/handoff [note]` | Writes `.project/handoffs/<timestamp>-<slug>.md` and `.project/HANDOFF.md` (or `HANDOFF.md` at the root outside ProjectMan projects): goal, state, decisions, gotchas, numbered next steps, resume commands. The SessionStart hook points the next session at it. Does not commit. |
| `/deploy-check [service]` | Coolify/Traefik pre-flight: env vars read vs provided, committed `.env` files, healthcheck endpoint and port, migration idempotency (EF Core, raw SQL, Prisma/knex/alembic), container basics. Read-only report with blockers and a go / no-go. |

## Install

```bash
mkdir -p ~/.claude/commands
cp *.md ~/.claude/commands/     # INSTALL.md is excluded by install.sh; skip it if copying by hand
rm -f ~/.claude/commands/INSTALL.md
```

## Verify

Type `/` in Claude Code and confirm the four commands appear with their descriptions.
