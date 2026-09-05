# ClaudeDefaultSetup

Baseline Claude Code configuration for a new machine: status line, git attribution suppression, and whatever else gets added over time.

## Usage

Open Claude Code on the new machine and paste:

```
Clone https://github.com/Biztactix-Ryan/ClaudeDefaultSetup.git into a temp directory, read SETUP.md, and follow it.
```

Claude works through each module in [SETUP.md](SETUP.md) in order and reports back.

To run a single module instead, point Claude at that module's `INSTALL.md`, for example:

```
Clone https://github.com/Biztactix-Ryan/ClaudeDefaultSetup.git into a temp directory and follow statusline/INSTALL.md.
```

## Layout

```
SETUP.md                 master instructions Claude follows (module order + rules)
statusline/
  statusline.sh          the status line script (copied verbatim to ~/.claude/)
  INSTALL.md             install/verify steps
attribution/
  commit-msg             global git commit-msg hook (copied to ~/.git-hooks/)
  INSTALL.md             install/verify steps
```

## Adding a module

1. Create `<module>/INSTALL.md` with the exact instructions Claude should follow.
2. Put any files to be installed alongside it, so they can be `cp`'d rather than retyped.
3. Add a row to the table in `SETUP.md`.

## Requirements

`bash`, `jq`, `git`, `awk`. The status line's git segment uses a Nerd Font glyph; install a Nerd Font in the terminal if it renders as a box.
