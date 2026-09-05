#!/usr/bin/env bash
# PreToolUse guard for Bash. Reads the hook payload on stdin and denies a short
# list of commands that are never worth an accidental keystroke. Anything not
# matched here falls through to the normal permission flow.
#
# Deny format (Claude Code hooks): JSON on stdout, exit 0.
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)
[ -z "$cmd" ] && exit 0

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

# Collapse whitespace/newlines so patterns are simple.
c=$(printf '%s' "$cmd" | tr -s '[:space:]' ' ')

# Read-only front commands: searching for "DROP TABLE" in a migration is fine.
readonly_prefix='^(grep|rg|ag|cat|bat|less|more|head|tail|sed -n|awk|find|ls|git (log|show|diff|grep|blame)) '

# --- 1. force push (--force-with-lease is allowed) ---------------------------
if printf '%s' "$c" | grep -Eq '(^|[;&|] *)(sudo )?git( -C [^ ]+)? push( [^ ]+)* (--force|-f|--force=[a-z]*)( |$)'; then
  deny "Force push is blocked by ~/.claude/hooks/bash-guard.sh. If a rewrite is really intended, use 'git push --force-with-lease' and run it yourself."
fi

# --- 2. recursive rm on root / home / parent ---------------------------------
if printf '%s' "$c" | grep -Eq '(^|[;&|] *)(sudo )?rm( -[A-Za-z]*[rR][A-Za-z]*| --recursive)+( -[A-Za-z]+| --no-preserve-root| --force)* (/|/\*|~|~/|~/\*|\$HOME|\$HOME/|\$\{HOME\}|\$\{HOME\}/|\.\.|\.\./)( |$)'; then
  deny "Recursive delete of /, \$HOME or a parent directory is blocked by ~/.claude/hooks/bash-guard.sh. Name the exact directory to remove instead."
fi
if printf '%s' "$c" | grep -Eq -- '--no-preserve-root'; then
  deny "--no-preserve-root is blocked by ~/.claude/hooks/bash-guard.sh."
fi

# --- 3. destructive SQL ------------------------------------------------------
if ! printf '%s' "$c" | grep -Eiq "$readonly_prefix"; then
  if printf '%s' "$c" | grep -Eiq '\bDROP +(TABLE|DATABASE|SCHEMA)\b|\bTRUNCATE +(TABLE +)?[a-z_"`\[]'; then
    deny "DROP/TRUNCATE is blocked by ~/.claude/hooks/bash-guard.sh. Write it as a reviewed migration and run it by hand."
  fi
  # EF Core / Prisma / knex full-database resets
  if printf '%s' "$c" | grep -Eiq '\bdotnet ef database drop\b|\bprisma migrate reset\b|\bknex migrate:rollback --all\b'; then
    deny "Database reset commands are blocked by ~/.claude/hooks/bash-guard.sh. Run them yourself if this is a throwaway database."
  fi
fi

# --- 4. secrets ---------------------------------------------------------------
if printf '%s' "$c" | grep -Eq '(^|[;&|] *)infisical +(export|secrets( +get| +ls| +list)?)( |$)'; then
  deny "Dumping Infisical secrets is blocked by ~/.claude/hooks/bash-guard.sh. Refer to secrets by name; the app loads them at runtime."
fi
# Reading a real .env (examples/samples/templates are fine).
if printf '%s' "$c" | grep -Eq '(^|[;&|] *)(cat|bat|less|more|head|tail|source|\.) +([^ ]*/)?\.env(\.(local|development|dev|staging|production|prod))?( |$)'; then
  deny "Reading .env files is blocked by ~/.claude/hooks/bash-guard.sh. Use .env.example for variable names."
fi

exit 0
