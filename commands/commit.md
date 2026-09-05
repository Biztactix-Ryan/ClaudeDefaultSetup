---
description: Conventional commit from the staged diff, referencing the ProjectMan ID in the branch name
argument-hint: [optional extra context for the message]
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git commit:*), Bash(git rev-parse:*)
---

Create one conventional commit from what is **already staged**. Do not stage anything yourself; if nothing is staged, list the unstaged changes and stop.

## Gather

```
git status --short
git diff --cached --stat
git diff --cached
git branch --show-current
git log --oneline -5
```

## Rules

- Format: `type(scope): summary` on the first line, under 72 characters, imperative mood, no trailing period.
  Types: feat, fix, refactor, perf, test, docs, build, ci, chore, style. Scope is the project or area touched (e.g. `api`, `web`, `infra`, `pm`); omit when the change is global.
- Body (optional, wrapped at 72): what changed and why, not how. Bullet points if there are several distinct changes. Never restate the diff line by line.
- **ProjectMan reference:** if the branch name contains an ID matching `(EPIC|US|CS)-[A-Z0-9]+-[0-9]+(-[0-9]+)?` (e.g. `US-APP-12`, `US-APP-12-3` for a task, `EPIC-APP-2`), add a trailer line `Refs: <ID>`. If the staged changes complete that task, use `Closes: <ID>` instead and say so in the summary of your reply.
- Breaking change: add `!` after the type/scope and a `BREAKING CHANGE:` footer.
- Match the style of the last five commits when they are conventional; otherwise use these rules.
- No Co-Authored-By, Signed-off-by, "Generated with", or any other attribution line. Ever.
- $ARGUMENTS, if given, is extra context from me. Use it to inform the message; do not paste it verbatim.

## Commit

Run `git commit` with the message via a heredoc so quoting is safe. Then show `git log -1 --stat` and, if a ProjectMan ID was found, remind me to mark the task with `/pm done <ID>` when appropriate.
