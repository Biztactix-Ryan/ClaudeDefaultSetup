# AttributionFix

Set up permanent suppression of all Claude Code git attribution on this machine. Do the following, then show me the final state of each file so I can verify.

1. Edit `~/.claude/settings.json` (create it if missing, preserve any existing keys):
   - Remove the deprecated `"includeCoAuthoredBy"` key if present.
   - Set exactly:
     ```json
     "attribution": { "commit": "", "pr": "", "sessionUrl": false }
     ```
   - Use `jq` for the edit, not a text rewrite. Back up to `settings.json.bak` first if the file exists.

2. Search for any project-level overrides that would beat the user setting:
   ```bash
   grep -rl '"attribution"\|includeCoAuthoredBy' ~/.claude/ ~/projects ~/src ~/repos 2>/dev/null
   ```
   (also check the current repo's `.claude/settings.json` and `.claude/settings.local.json`).
   Report anything found; do not modify project files without asking.

3. Create a global commit-msg hook as a backstop:
   - `mkdir -p ~/.git-hooks`
   - Copy `commit-msg` from this directory of the repo to `~/.git-hooks/commit-msg` (it is portable sh, uses `grep -v` and `mv`, no `sed -i`). Its content is:
     ```sh
     #!/bin/sh
     tmp="$1.tmp"
     grep -v -e '^Co-Authored-By: Claude' \
             -e '^Claude-Session:' \
             -e 'Generated with \[Claude Code\]' "$1" > "$tmp"
     mv "$tmp" "$1"
     ```
   - `chmod +x ~/.git-hooks/commit-msg`
   - `git config --global core.hooksPath ~/.git-hooks`

4. Warn me if `core.hooksPath` was already set to something else (e.g. Husky), and don't overwrite it. Tell me what it was instead.

5. Verify: `cat ~/.claude/settings.json`, `cat ~/.git-hooks/commit-msg`, and `git config --global core.hooksPath`.

Do not commit anything to any repo as part of this.
