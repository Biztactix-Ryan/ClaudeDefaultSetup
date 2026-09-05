---
name: setup-project
description: Set up a repo for Claude Code — detect stack and deploy target (Coolify, Docker, Proxmox, systemd, k8s, cloud), locate deploy scripts, write or refresh a concise project CLAUDE.md, wire a project-level SessionStart hook that injects ProjectMan status, and run projectman init plus the six-doc wizard if .project/ is missing. Use for "/setup-project", "set up this repo for Claude", "create a CLAUDE.md for this project", "onboard this project".
user_invocable: true
args: "[--no-pm] [--refresh]"
---

# /setup-project

Onboard the current repo so every future session starts with the right
context. Work from the repo root (`git rev-parse --show-toplevel`). Read before
you write, and keep the result short: a project `CLAUDE.md` is loaded on every
turn, so aim for under 80 lines.

Flags: `--no-pm` skips ProjectMan entirely. `--refresh` re-detects and rewrites
only the managed block in `CLAUDE.md` without asking questions.

Do not commit anything. Do not print secret values, ever; refer to env vars by
name.

## 1. Detect the project

Collect facts, do not guess. If something cannot be determined, ask one
batched question at the end of this step rather than several as you go.

**Identity and stack**
- Name: repo directory name, or `name` in `package.json` / `pyproject.toml` /
  `*.csproj` `AssemblyName` / `.project/config.yaml` if present.
- Stack markers: `*.sln`, `*.csproj` (TargetFramework), `global.json`,
  `package.json` (framework from deps: next, vite, react, express, nest),
  `pyproject.toml`, `go.mod`, `Cargo.toml`, `Gemfile`, `composer.json`.
- Commands: build, test, lint, run, migrate. Sources: `package.json` scripts,
  `Makefile`/`justfile`/`Taskfile.yml` targets, `*.csproj` + `dotnet` defaults,
  `pyproject` scripts, existing README "getting started".
- Layout: top two directory levels, ignoring `node_modules`, `bin`, `obj`,
  `.git`, `dist`.

**Deploy target** — check in this order and record every match, with the file
that proves it:

| Target | Evidence |
|--------|----------|
| Coolify | `coolify.json`, `.coolify/`, `coolify` in CI or compose labels, `SERVICE_FQDN_*` / `SERVICE_URL_*` env references, Traefik labels alongside a compose file, `nixpacks.toml` |
| Docker / Compose | `Dockerfile*`, `docker-compose*.y*ml`, `compose.y*ml`, `.dockerignore` |
| Proxmox | scripts calling `qm`, `pct`, `pvesh`, `pveam`; Terraform providers `bpg/proxmox` or `telmate/proxmox`; Ansible `community.general.proxmox*`; cloud-init or `*.pkr.hcl` with a proxmox builder |
| Kubernetes / Helm | `k8s/`, `deploy/*.yaml` with `kind:`, `Chart.yaml`, `kustomization.yaml`, `skaffold.yaml` |
| systemd / bare metal | `*.service` files, `install.sh` that copies to `/etc/systemd`, `deploy.sh` using `ssh`/`rsync`/`scp` |
| Cloud PaaS | `fly.toml`, `render.yaml`, `Procfile`, `app.yaml`, `vercel.json`, `netlify.toml`, `azure-pipelines.yml` + `*.bicep`, `serverless.yml`, `cdk.json` |
| Windows service / IIS | `web.config`, `*.pubxml`, `sc create`, `New-Service` in scripts |

**Deploy scripts** — find and list with path and a one-line purpose:
`deploy*`, `publish*`, `release*`, `scripts/**`, `.github/workflows/*`,
`.gitlab-ci.yml`, `Makefile` targets containing deploy/publish/release,
`package.json` scripts with the same words, `*.ps1` doing publish or copy.
Open each one long enough to say what it targets (host, service name, compose
project, Coolify app) and whether it needs a secret or a VPN.

**Environment** — where config comes from: `.env.example`, compose
`env_file`, `appsettings*.json` sections, Infisical (`infisical` in scripts or
CI), Coolify-managed env, `secrets.*` in CI. Names only.

**ProjectMan** — does `.project/config.yaml` exist? Note `name`, `prefix`,
`hub`.

## 2. ProjectMan (unless `--no-pm`)

If `.project/` is missing:
1. Confirm `projectman` is on PATH. If not, say to run the ClaudeDefaultSetup
   installer (`projectman/install.sh`) and continue with the rest of this skill.
2. Propose a prefix: 3 or 4 upper-case letters from the project name
   (`SuccessionSafe` → `SSF`, `LinkCollector` → `LC` → pad to `LNK`). Show it
   with the name and run `projectman init --name "<name>" --prefix <PREFIX>`
   unless the user objects.
3. Run the `projectman-init-wizard` skill to fill the six docs (it detects
   import vs wizard mode itself). If that skill is not installed, do the short
   version: write PROJECT.md and INFRASTRUCTURE.md from what you detected in
   step 1 via `pm_update_doc`, and tell the user the full wizard is available
   from ClaudeDefaultSetup.

If `.project/` exists: call `pm_docs()` and note which docs are still template
text; offer the wizard for those but do not run it unasked.

If the `pm_*` MCP tools are not available in this session, say so and tell the
user to run `projectman setup-claude --global` and restart. Keep going.

## 3. Project-level SessionStart hook

Goal: every session in this repo opens with the ProjectMan status summary, for
anyone who clones it, not only machines with the global setup.

1. `mkdir -p .claude/hooks`
2. Source script, in order of preference:
   - copy `~/.claude/hooks/session-start.sh` (installed by ClaudeDefaultSetup)
   - else `curl -fsSL https://raw.githubusercontent.com/Biztactix-Ryan/ClaudeDefaultSetup/main/hooks/session-start.sh`
   to `.claude/hooks/pm-context.sh`, then `chmod +x`. The script prints
   epics/stories/tasks by status, points, in-progress tasks, active sprint, and
   the last handoff, and it dedupes itself when the global hook also fires.
3. Merge into `.claude/settings.json` (project scope, shared) with `jq`, never
   a text rewrite; create it if missing; preserve every existing key. Skip if
   an equivalent SessionStart entry is already there:
   ```json
   {
     "hooks": {
       "SessionStart": [
         { "hooks": [ { "type": "command",
             "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/pm-context.sh",
             "timeout": 20 } ] }
       ]
     }
   }
   ```
4. Test: `echo '{"cwd":"'"$PWD"'","session_id":"test"}' | .claude/hooks/pm-context.sh`
   should print the summary (or nothing if `.project/` is still missing).

## 4. Write CLAUDE.md

Keep or create `CLAUDE.md` at the repo root. Everything you generate goes
between two markers so re-running replaces only that block and leaves any
hand-written content untouched:

```
<!-- setup-project:start -->
...
<!-- setup-project:end -->
```

If the file exists without markers, append the block at the end. If it exists
with markers, replace the block. If a `CLAUDE.md` already documents something
you detected, do not repeat it inside the block; reference it in one line.

Block contents, in this order, terse, tables where they fit:

```
# <Name>
One sentence: what it is and who uses it.

## Stack
Language/framework/versions · database · key libs · package manager.

## Commands
| Task | Command |   (build, test, lint, run, migrate, format — only ones that exist)

## Layout
3-8 lines: top-level dirs and what lives in each.

## Deploy
Target: <Coolify | Docker Compose on <host> | Proxmox (<qm/pct/terraform>) | ...> with the evidence file.
Scripts: path — what it does — what it needs (secret name, VPN, host).
How a normal deploy happens, in 2-4 numbered steps. What NOT to run casually (force pushes to the deploy branch, migrations against prod, `terraform apply`).
Health check URL/port if found.

## Config & secrets
Where env comes from (Infisical / Coolify / .env). `.env.example` is the source of variable names. Never read or print real `.env*` files.

## ProjectMan
Prefix <PREFIX>. `.project/` holds epics/stories/tasks; use `/pm` for status, `/pm board` to pick work, `/pm-do <id>` to execute, `/handoff` before ending a long session. Branch names carry the task ID (`US-<PREFIX>-n-m`) so `/commit` can reference it.

## Conventions
Only what is evidenced: commit style from `git log`, formatter config present, test naming, branch naming from `git branch -r`. Never invent rules.
```

Omit any section with nothing real to say. No marketing tone, no
"this project aims to".

## 5. Report

Print, in this order:
1. Files written or updated: `CLAUDE.md`, `.claude/settings.json`,
   `.claude/hooks/pm-context.sh`, `.project/` (if created).
2. Deploy target and the evidence, in one line.
3. Anything uncertain you left as `TBD` in `CLAUDE.md`, as questions.
4. Suggested commit: `git add CLAUDE.md .claude/settings.json .claude/hooks/pm-context.sh .project && /commit` (the user runs it; you do not).
5. Remind the user to restart the session so the hook and `CLAUDE.md` load.
