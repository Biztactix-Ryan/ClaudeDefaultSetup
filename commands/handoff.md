---
description: Write a session handoff to .project/ so the next session (or the next agent) can resume without re-discovery
argument-hint: [one-line note on where things stand]
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git stash list:*), Bash(ls:*), Bash(mkdir:*), Bash(date:*), Read, Write, Glob
---

Write a handoff for this session. It is for a reader with no memory of this conversation: me tomorrow, or an agent picking up the same task.

## Where

- If `.project/` exists: write `.project/handoffs/<YYYY-MM-DD-HHMM>-<short-slug>.md` and overwrite `.project/HANDOFF.md` with the same content (latest pointer; the SessionStart hook surfaces it).
- Otherwise: write `HANDOFF.md` in the repo root and say that the repo is not a ProjectMan project.
- Do not commit. Do not modify anything else.

## Gather first

`git branch --show-current`, `git status --short`, `git log --oneline -10`, `git stash list`, and anything in this conversation about goals, decisions, and dead ends. If the branch name or the conversation names a ProjectMan ID (`US-…`, `EPIC-…`, `US-…-n`), include it.

## Content, in this order, terse

```
# Handoff — <project> — <date time> — <branch>

## Goal
What I was trying to achieve this session, in one or two sentences. ProjectMan IDs.

## State
- Done: bullet per completed thing, with file paths.
- In progress: what is half-finished, exactly where it stops, what is broken right now.
- Uncommitted: summary of git status (files, not diffs). Stashes.

## Decisions
Choices made and why. Alternatives rejected and why. One line each.

## Gotchas
Things that cost time: flaky tests, env quirks, misleading errors, commands that must run in a specific order.

## Next
Numbered steps, most specific first. The first step should be runnable immediately.

## Resume
Exact commands to get back to the working state (checkout, restore, build, test).
```

$ARGUMENTS, if given, goes at the top of **State** as my own note.

Keep it under a page. No prose paragraphs, no restating the codebase. When done, print the path written and remind me to `/pm done` or `/pm update` any tasks whose status changed this session.
