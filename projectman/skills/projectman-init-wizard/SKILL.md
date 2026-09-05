---
name: projectman-init-wizard
description: ProjectMan six-doc context wizard — fills VISION, ARCHITECTURE, PROJECT, INFRASTRUCTURE, SECURITY and DECISIONS in .project/ by interviewing the user (new project) or scanning the codebase and asking about gaps (existing project). Use for "/pm init", "set up project docs", "describe this project to ProjectMan", or when pm_docs reports empty/template docs.
user_invocable: true
args: "[project-name]"
---

# ProjectMan init wizard

You are filling in the six context documents ProjectMan keeps in `.project/`.
Everything downstream (scoping, sprint planning, audits, `/pm-do`) reads these,
so specific beats complete: a short doc with real facts is better than a long
one with placeholders.

| # | doc key (`pm_update_doc`) | File | Answers |
|---|---------------------------|------|---------|
| 1 | `vision` | VISION.md | Why this exists, who it is for, principles, roadmap |
| 2 | `architecture` | ARCHITECTURE.md | How the pieces fit: service map, contracts, cross-cutting standards |
| 3 | `project` | PROJECT.md | Tech stack, components, data flow, dependencies, dev setup |
| 4 | `infrastructure` | INFRASTRUCTURE.md | Environments, CI/CD, hosting, monitoring, env vars, backup |
| 5 | `security` | SECURITY.md | AuthN/AuthZ, data protection, API security, secrets, risks, incident response |
| 6 | `decisions` | DECISIONS.md | Decision log: title, date, status, context, decision, consequences |

If a `project-name` argument is given, pass it as `project` to every
`pm_docs` / `pm_update_doc` call (hub mode). Otherwise operate on the current
repo's `.project/`.

## Step 0: Preconditions

1. If `.project/` does not exist, stop and tell the user to run
   `projectman init --name <name> --prefix <PREFIX>` first (or `/pm init` will
   do it when asked). Do not create `.project/` by hand.
2. Call `pm_docs()` (no `doc` arg) for the summary of all six. Note which are
   still template text (HTML comments, empty tables, "Principle 1").
3. Read the existing content of any doc that already has real content. You are
   updating, not replacing: keep what is correct, fix what is stale, fill gaps.

## Step 1: Detect mode

Look at the repo root for source markers: `*.sln`, `*.csproj`, `package.json`,
`pyproject.toml`, `Cargo.toml`, `go.mod`, `pom.xml`, `Gemfile`, `composer.json`,
or `src/`, `lib/`, `app/`, `cmd/`.

- Code present → **Import mode** (scan first, then ask about gaps).
- No code → **Wizard mode** (interview, then write).

Tell the user which mode you are in and roughly how many questions to expect.

## Wizard mode (new project)

Interview in the doc order above. Ask in batches of 3-5 related questions, not
one at a time and not all at once. Adapt: skip anything already answered, drill
into anything vague. Offer a sensible default when the user shrugs
("Coolify on a Hetzner VPS with Traefik, dev + prod, GitHub Actions?").

**Vision:** what problem, for whom, what does success look like in 6-12 months,
2-4 principles that settle arguments (e.g. "boring tech", "MSP-safe defaults").

**Architecture:** monolith or services, list the deployable units, how they
talk (HTTP, queue, DB), what contracts cross boundaries, the shared standards
for auth, logging, errors, and testing.

**Project:** language + framework + versions, database, key libraries and
SaaS dependencies (auth, email, payments), how data flows, how to run it
locally (prereqs, env vars by name only, seed data, test command).

**Infrastructure:** hosting, environments and their URLs, CI/CD tool and
pipeline stages, deploy and rollback procedure, monitoring and alerting,
env var names per environment, backup and recovery.

**Security:** how users authenticate, session/token lifetime, MFA, roles and
how they are enforced, encryption at rest and in transit, PII and retention,
API protections (rate limits, CORS, input validation), where secrets live
(Infisical, env, vault), known risks, who gets paged.

**Decisions:** anything the user justified during the interview becomes an
entry ("Postgres over SQL Server: licensing cost, team familiarity"). Ask for
any decisions already made that you have not heard yet.

## Import mode (existing project)

### Scan
Read, do not guess. Look at:
- **Stack:** manifest files above, `global.json`, `Directory.Build.props`,
  `tsconfig.json`, framework configs, lockfiles for versions.
- **Infra:** `Dockerfile*`, `docker-compose*.yml`, `.github/workflows/`,
  `.gitlab-ci.yml`, `terraform/`, `fly.toml`, `coolify*`, Traefik labels,
  `nginx.conf`, `Caddyfile`, `.env.example` (names only, never values).
- **Security:** auth middleware and guards, `[Authorize]`, JWT/OAuth config,
  CORS, rate limiting, hashing libs, secrets loading (Infisical, env).
- **Architecture:** directory layout, README, route/controller lists,
  migrations, message/queue clients, cross-project references.
- **History:** `git log --oneline -40` and any ADR/docs folder for decisions.

### Present
Summarise findings per doc in a compact table with a confidence column
(high / medium / low). Flag concerns plainly: secrets committed, no auth on a
route, no CI, no backups, migrations that are not idempotent.

### Ask
Only ask what the scan could not settle. Typical:
- "JWT middleware is present. Is that the only auth path, or is there SSO?"
- "Dockerfile but no pipeline. How does this get deployed today?"
- "What are the real environment URLs?"
- "Monitoring: I found nothing. Is there any?"
- "Backups: where, how often, last tested?"

## Step 2: Write

Write all six with `pm_update_doc(doc, content, project?)`, one call per doc,
in the table order. Rules:

- Keep the section headings from the existing template so `pm_audit` and
  `pm_context` keep working. Replace the HTML comment hints with content.
- Be specific: ".NET 9 / ASP.NET Core Minimal APIs, EF Core 9, PostgreSQL 16 on
  Coolify" not "a .NET web app".
- Tables for environments, env vars, roles, service map, roadmap.
- Env var **names** only. Never write a secret value into any doc.
- Mark unknowns as `TBD (ask: <who/what>)` rather than inventing.
- DECISIONS.md: newest first. Each entry has Title, Date, Status, Context,
  Decision, Consequences. Date decisions you heard today as today.

After writing, call `pm_docs()` once more and show the user the one-line
status of each doc.

## Step 3: Hand off

Suggest next steps in this order and stop:
1. `pm_commit` (or `/pm commit`) to commit `.project/` if the user wants it
   tracked now.
2. `/pm create epic "<first initiative>"` for the biggest thing discussed.
3. `/pm-autoscope` if this is an existing codebase with an obvious backlog.

Do not create epics, stories, or tasks yourself inside this skill.
