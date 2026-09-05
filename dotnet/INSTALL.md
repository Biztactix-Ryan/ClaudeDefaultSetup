# .NET SDKs

Installs the current **LTS** SDK and the newest **other supported** SDK channel (STS, or an older LTS still in maintenance). Preview, RC, go-live, alpha and beta builds are never selected.

## How channels are chosen

`install.sh` fetches Microsoft's `releases-index.json`, keeps channels whose `support-phase` is `active` or `maintenance`, takes the highest `lts` one as the LTS, and the highest remaining one as the other. Today that resolves to 10.0 and 9.0; when the next STS goes GA it becomes the other automatically. Override with `DOTNET_CHANNELS="10.0 9.0"`.

## Where it installs

- An existing `dotnet` on PATH: into that same root so every SDK is visible to one host (with `sudo` if the root is not writable).
- Otherwise `~/.dotnet`, and `DOTNET_ROOT` + `PATH` lines are appended once to `~/.bashrc` / `~/.zshrc`.
- Override with `DOTNET_INSTALL_DIR=/opt/dotnet`.

## Run

```bash
./install.sh            # from this directory, or ../install.sh --only dotnet
dotnet --list-sdks
```

Idempotent: an SDK whose exact version is already listed is skipped; re-running after a patch release installs the patch alongside.

## Notes

- Uses the official `https://dot.net/v1/dotnet-install.sh` (Windows: `dotnet-install.ps1` via `install.ps1`).
- If a preview SDK is already on the machine the script warns but does not remove it. Repos should pin with `global.json` (`"rollForward": "latestFeature"`) so a preview is never picked up by accident.
- Linux distro packages (`apt install dotnet-sdk-10.0`) are an alternative; this script does not touch apt.
