# StatuslineUpdate

Install or update my Claude Code status line. Do exactly the following, in order, and don't modify the script content.

## 1. Write the script

Copy `statusline.sh` from this directory of the repo **verbatim** to `$CLAUDE_CONFIG_DIR/statusline.sh` (fall back to `~/.claude/statusline.sh` if `CLAUDE_CONFIG_DIR` is unset). Create the directory if needed. If a file already exists there, back it up to `statusline.sh.bak` first. Then `chmod +x` it.

Use `cp`, not a rewrite, so the file is byte-identical to the repo copy. Confirm with `cmp` (or `diff`) against the repo file.

## 2. Check dependencies

Confirm `bash`, `jq`, `git`, and `awk` are on PATH. If `jq` is missing, stop and tell me the install command for this OS (`brew install jq`, `apt install jq`, `winget install jqlang.jq`, etc.) rather than trying to substitute it.

## 3. Wire up settings.json

Edit the **user** settings file (`$CLAUDE_CONFIG_DIR/settings.json`, default `~/.claude/settings.json`) so it contains:

```json
"statusLine": {
  "type": "command",
  "command": "~/.claude/statusline.sh"
}
```

Rules:
- If the file exists, **merge** this key in and preserve every other existing key (hooks, permissions, env, model, etc.). Use `jq` to do the merge, not a text rewrite. Back up to `settings.json.bak` first.
- If the file doesn't exist, create it with just this key.
- If `CLAUDE_CONFIG_DIR` is set to a non-default location, use that absolute path in `command` instead of `~/.claude/...`.
- Don't add a `padding` key unless I ask.

## 4. Verify

Run the script with a fake payload and show me the output:

```bash
printf '%s' '{"model":{"display_name":"Opus 4.8 (1M context)"},"effort":{"level":"high"},"workspace":{"project_dir":"'"$PWD"'","current_dir":"'"$PWD"'"},"context_window":{"used_percentage":42.3,"total_input_tokens":80000,"total_output_tokens":5000,"context_window_size":200000},"cost":{"total_cost_usd":1.2345},"rate_limits":{"seven_day":{"used_percentage":63,"resets_at":'"$(( $(date +%s) + 7200 ))"'}}}' | ~/.claude/statusline.sh
```

Expected: one line showing `Opus 4.8·high │ <project> │ <branch> │ ctx 85.0k/200k 42% │ $1.23 │ 7d ██████░░░│░ 63%·1h -2.4d` with colours. The weekly segment is a ten-cell bar of usage; `│` marks where even burn over the 7-day window would be right now; fill past the marker is yellow (or red when more than 10 points over). After the percentage and the under-48h reset countdown comes the pace gap in days: `+0.8d` means usage is 0.8 days ahead of even pace (over budget), `-2.4d` means under. Also run it with an empty object (`echo '{}' | ~/.claude/statusline.sh`) and confirm it prints `claude │ $0.00` with no errors and no literal `null`.

Then run `jq . ~/.claude/settings.json` to confirm the file is valid JSON and the `statusLine` key is present.

## 5. Report

Tell me: the paths written, whether backups were created, dependency status, and the verification output. Remind me to restart Claude Code (or open a new session) for the status line to take effect. Note that the git segment uses a Nerd Font glyph (``); if it renders as a box, I need a Nerd Font in the terminal.
