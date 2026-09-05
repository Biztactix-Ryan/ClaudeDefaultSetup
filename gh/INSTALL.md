# GitHub CLI

Several pieces of this setup shell out to `gh`: `/review` and `/deploy-check` on pull requests, `projectman git-status`, and the ProjectMan pin lookup. `install.sh` makes sure it is present.

## What it does

1. If `gh` is already on PATH: report the version and skip.
2. Otherwise install with the first available method: Homebrew, the official GitHub apt repo (Debian/Ubuntu), dnf (Fedora/RHEL), pacman (Arch), apk (Alpine). Without a package manager or without sudo it downloads the latest release tarball from `github.com/cli/cli` into `~/.local/bin`. Force that path with `GH_INSTALL_METHOD=binary`.
3. Checks `gh auth status`. Login is interactive and is **never** run by the script; if it is missing you are told to run `gh auth login`.

Windows: `install.ps1` uses `winget install GitHub.cli`.

## Run

```bash
./install.sh        # from this directory, or ../install.sh --only gh
gh --version && gh auth status
```
