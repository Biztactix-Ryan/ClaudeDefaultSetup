---
description: Security and correctness review of the current changes with an MSP lens (input validation, secrets, auth boundaries, tenant isolation)
argument-hint: [branch|commit|path|PR number] (default: working tree vs HEAD)
allowed-tools: Bash(git diff:*), Bash(git log:*), Bash(git show:*), Bash(git status:*), Bash(gh pr diff:*), Bash(gh pr view:*), Read, Grep, Glob
---

Review the changes for **security and correctness only**. Style, naming, and formatting are out of scope (the format hook handles formatting).

## Target

- No argument: `git diff HEAD` plus untracked files from `git status --short`.
- Branch or commit: `git diff <base>...<target>`; a bare branch name means that branch vs `main`.
- Path: only that file or directory, current state.
- A number: `gh pr diff <n>` and `gh pr view <n>`.
$ARGUMENTS

Read enough surrounding code to judge each change in context. Do not review the whole repo.

## Lens

This is code that runs for managed-service clients. Think like the person who gets paged when it goes wrong. For every hunk ask:

**Trust boundaries**
- Every input from a request, queue, webhook, file, or env var: validated for type, length, range, and encoding before use? Rejected, not "cleaned", when malformed?
- SQL, shell, LDAP, path, header, HTML, and log injection: parameterised or encoded at the sink?
- Deserialisation of untrusted data, mass assignment, over-posting into entity models.

**Auth boundaries**
- Is every new endpoint, handler, page, or job behind the right `[Authorize]` / policy / middleware? Any default-allow?
- Object-level checks: does the caller own or have rights to the specific record (IDOR)? In multi-tenant code, is the tenant ID taken from the authenticated principal and never from the request body?
- Role or scope escalation, admin paths reachable by ordinary users, background jobs running with more privilege than needed.

**Secrets and data**
- Hardcoded credentials, tokens, connection strings, or keys. Anything read from `.env` or Infisical logged, returned, or serialised?
- PII in logs, error responses, telemetry, or URLs. Stack traces reaching clients.
- Crypto: home-rolled algorithms, weak hashing for passwords, static IVs, disabled TLS validation.

**Correctness**
- Off-by-one, null/None paths, unchecked casts, integer overflow, timezone and DST handling, culture-sensitive parsing.
- Async: missing awaits, fire-and-forget without error handling, cancellation tokens dropped, shared state without locks.
- Error handling that swallows exceptions or retries non-idempotent operations. Transactions spanning the right set of writes.
- Migrations: idempotent, reversible, safe on a populated table (locks, defaults, nullability).
- Tests changed to pass rather than code fixed.

## Report

Findings first, ordered by severity, each as: **severity** (critical / high / medium / low), `file:line`, one sentence on the defect, one sentence on the concrete failure (input → outcome), and the fix. Confirmed problems only; say "possible" when you could not verify. End with a one-line verdict: ship, ship after fixes, or do not ship. If there are no findings, say so in one line. Do not pad with praise or a summary of the diff.
