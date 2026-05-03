# Testing — sideral

This project has no unit/e2e test suite. The gate checks are:

## Quick gate (per task touching shell scripts)
```
just lint
```
Runs `shellcheck os/lib/*.sh os/modules/*/*.sh` — non-zero exit stops the task.

## Full gate (end-of-phase + pre-commit for image-touching tasks)
```
just build
```
Runs `podman build` with `os/Containerfile`. The final step is `bootc container lint`, which must pass. Exit 0 is required.

CI runs the same gate per-PR via `.github/workflows/build.yml` against the matrix `{silverblue-main:43, silverblue-nvidia:43}`, ending in `bootc container lint` for both variants.

## Manual verification (VM / rebase)
Only run when explicitly validating a full pass:
1. `just rebase` on a disposable VM or scratch deployment.
2. `systemctl reboot`.
3. Log in, dismiss the `/etc/user-motd` welcome banner, then check:
   - `gnome-extensions list --enabled` → 4 UUIDs (appindicator, dash-to-panel, tilingshell, rounded-window-corners)
   - `flatpak list --app` → 11 refs (Zen, Bazaar, Flatseal, Extension Manager, Podman Desktop, DistroShelf, Resources, Smile, Web App Hub, Pika Backup, Junction)
   - `flatpak remotes` → exactly one entry: `flathub`
   - `which code` → `/usr/bin/code` (Microsoft RPM via persistent vscode.repo)
   - `which hx` → `/usr/bin/hx` (Helix; default `$EDITOR`)
   - `which starship && starship --version` → upstream binary baked into `/usr/bin`
   - `mise --version` → resolves; user picks toolchain in their chezmoi'd `~/.config/mise/config.toml`
   - `chezmoi --version` → resolves
   - `which docker` → `/usr/bin/docker` (podman-docker shim wrapper)
   - `systemctl --user is-active podman.socket` → `active` (auto-enabled by sideral-services)
   - `kubectl version --client` + `kind version` + `helm version` → all resolve
   - On nvidia variant: `cat /usr/lib/bootc/kargs.d/00-nvidia.toml` → 4 kargs incl. `nvidia-drm.modeset=1`; `gsettings get org.gnome.mutter experimental-features` → contains `kms-modifiers`
   - `rpm-ostree status` → sideral current, previous deployment preserved (ATH-08)
   - `ujust chsh fish && exec fish -l` → fish init script loads; starship + atuin + zoxide + mise + fzf integrations active
   - `ujust chsh zsh && exec zsh -l` → zsh init script loads; same integrations + zsh-syntax-highlighting + zsh-autosuggestions
   - **Distrobox check**: `distrobox create --image fedora:42 t && distrobox enter t -- echo hello` → succeeds (no `/nix` mount expectation post chezmoi-home)

## Task-level gate matrix
| Task touches | Gate |
| --- | --- |
| `os/lib/*.sh` or `os/modules/*/*.sh` | `just lint` |
| `os/Containerfile` / any `os/modules/*/{packages.txt,src/,rpm/}` content | `just build` |
| `Justfile` / `README` / workflow YAML / specs only | none — text only |

## Known hazards
- RPM name typos fail `dnf5 install` with a clear error — surface the failing package.
- `extensions.gnome.org` build-time download can fail if the uuid/shell version no longer resolves — check the returned URL before curling.
- `bootc container lint` is the last step of `just build`; reading failures earlier (dnf, post-install) is faster than waiting for lint.
- File-conflict errors during the inline `rpm -Uvh --replacefiles` step usually mean a sideral spec ships a path that the base image already owns and `--replacefiles` couldn't reconcile — the conflicting package is in the error message; either remove it from the base via the prune step in `os/lib/build.sh` or drop the conflicting file from the sideral spec.
- `set -o pipefail` + `var=$(... | grep ...)` is a hidden landmine if grep finds nothing. Capture the response into a variable, then `grep ... || true`, then validate.
- `rpm -e --nodeps ublue-os-signing` MUST run before the inline RPM install — sideral-signing.spec declares `Conflicts:` against it and `--replacefiles` doesn't bypass package-level Conflicts.
