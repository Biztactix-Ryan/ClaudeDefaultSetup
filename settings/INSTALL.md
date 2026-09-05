# Settings template

`settings.template.json` is a **partial** user `settings.json`. It is merged into `~/.claude/settings.json`; it never replaces the file.

## What it sets

| Key | Purpose |
|-----|---------|
| `statusLine` | Runs `~/.claude/statusline.sh` (see `../statusline/`) |
| `attribution` | Empty commit/PR attribution, no session URL (see `../attribution/`) |
| `env` | `DOTNET_CLI_TELEMETRY_OPTOUT=1`, `DOTNET_NOLOGO=1`, `DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1`, `DOTNET_GENERATE_ASPNET_CERTIFICATE=false`, `NEXT_TELEMETRY_DISABLED=1`, `DO_NOT_TRACK=1` |
| `permissions.allow` | The boring, read-only or build-only commands approved every time: `dotnet build/test/restore/format`, `git status/diff/log/show/branch/fetch`, `npm test`, `npm run test/lint/build`, `docker compose ps/logs/config`, `docker ps`, `jq`, read-only `projectman` subcommands |
| `permissions.deny` | `rm -rf`, `sudo rm`, `git push --force` / `-f`, `infisical export` / `infisical secrets`, `cat .env`, and `Read`/`Edit` on `.env`, `.env.local`, `.env.development`, `.env.staging`, `.env.production` at any depth. `.env.example` stays readable on purpose |
| `hooks` | Wires the scripts in `../hooks/` (see that module) |

## Install

```bash
./merge.sh            # merges into $CLAUDE_CONFIG_DIR/settings.json (default ~/.claude/settings.json)
```

`merge.sh` uses `jq` only. Objects merge recursively with the template winning on conflicting scalars, `permissions.allow`/`deny` and each `hooks.<Event>` list are unioned and deduplicated, and the deprecated `includeCoAuthoredBy` key is removed. Every other key already in the file (`model`, `defaultMode`, extra env, extra hooks, MCP settings) is preserved. A `settings.json.bak` is written only when the file actually changes, so re-running is a no-op.

If `CLAUDE_CONFIG_DIR` is set to a non-default location, `~/.claude` in the template's command paths is rewritten to that directory.

## Verify

```bash
jq . ~/.claude/settings.json >/dev/null && echo valid
jq -r '.permissions.deny[]' ~/.claude/settings.json | head
```

## Adjusting

Edit `settings.template.json`, commit, re-run `./merge.sh` on each machine. Removing a rule from the template does **not** remove it from a machine that already has it (union semantics); delete it from that machine's `settings.json` by hand.
