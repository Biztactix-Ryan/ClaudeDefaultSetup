---
description: Coolify/Traefik pre-flight for this repo — env vars present, healthcheck defined, migrations idempotent, container basics sane
argument-hint: [service or compose project name]
allowed-tools: Bash(ls:*), Bash(find:*), Bash(git diff:*), Bash(git status:*), Bash(docker compose config:*), Bash(dotnet ef migrations list:*), Bash(dotnet --version), Read, Grep, Glob
---

Pre-flight this repo for a Coolify deployment behind Traefik. Read-only: report, do not fix, unless I say so afterwards. Never print the value of a secret; names only.

Target: $ARGUMENTS (default: every deployable service found in the repo).

## 1. What deploys

Find `Dockerfile*`, `docker-compose*.y*ml`, `.coolify/`, `nixpacks.toml`, `Procfile`. Identify each service, its image or build context, exposed port, and start command. If nothing is found, stop and say so.

## 2. Environment variables

Build the set of variables the code **reads**:
- .NET: `Configuration["…"]`, `GetConnectionString`, `Environment.GetEnvironmentVariable`, `IOptions<T>` bound sections, `appsettings*.json` keys that have no default.
- Node: `process.env.X`. Python: `os.environ`, `os.getenv`, pydantic settings.
Compare against what is **provided**: compose `environment:`/`env_file:`, `.env.example`, Dockerfile `ENV`, Coolify config if present.
Report: read but not provided anywhere (will crash or silently default), provided but never read (cruft), and any `.env` file committed to git (`git ls-files | grep -i '\.env'`). Flag secrets that are hardcoded in compose or Dockerfile instead of injected.

## 3. Healthcheck

Each service needs one of: Dockerfile `HEALTHCHECK`, compose `healthcheck:`, or a Coolify health path. Verify the endpoint exists in code (`MapHealthChecks`, `/health`, `/healthz`, an express route) and that it does not require auth or a DB when used only for liveness. Traefik: check labels or Coolify settings for the correct internal port; mismatched port is the most common "502 after deploy".

## 4. Migrations

- EF Core: list migrations (`dotnet ef migrations list` if the tooling is present, otherwise read `Migrations/`). Check how they run on deploy: `Database.Migrate()` on startup, a migration bundle, or an idempotent SQL script (`dotnet ef migrations script --idempotent`). Multiple replicas + startup migrate = race; call it out.
- Raw SQL in migrations: `CREATE TABLE` without `IF NOT EXISTS`, `ALTER TABLE ADD COLUMN` without a guard, data backfills that are not re-runnable, destructive steps (drop column/table) without a preceding release that stopped using them.
- Prisma / knex / alembic: equivalent checks on the migration directory and the deploy command.

## 5. Container basics

Non-root user, pinned base image tag (not `latest`), `.dockerignore` excludes `.env`, `.git`, `node_modules`/`bin`/`obj`; `restart: unless-stopped`; logs to stdout, not files; timezone and culture set explicitly if the app formats dates; volumes for anything that must persist; resource limits if compose defines them for siblings.

## Report

A table per service: check, status (pass / warn / fail), one-line detail with `file:line`. Then a short **Blockers** list (fails that would break the deploy) and **Should fix** list. End with a one-line go / no-go. Nothing else.
