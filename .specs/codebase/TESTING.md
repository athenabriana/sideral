# Testing — sideral

This project has no unit/e2e test suite. The gate checks are:

## Quick gate (per task touching shell scripts)
```
just lint
```
Runs `shellcheck build_files/*.sh` — non-zero exit stops the task.

## Full gate (end-of-phase + pre-commit for image-touching tasks)
```
just build
```
Runs `podman build` with the current `Containerfile`. The final step is `bootc container lint`, which must pass. Exit 0 is required.

## Manual verification (VM / rebase)
Only run when explicitly validating a full pass:
1. `just rebase` on a disposable VM or scratch deployment.
2. `systemctl reboot`.
3. Log in, wait for first-shell bootstrap UX banner to disappear, then check:
   - `gnome-extensions list --enabled` → 5 UUIDs (ATH-04)
   - `flatpak list --app` → 7 refs (ATH-13, post-2026-05-01 count; browser is RPM)
   - `which helium` → `/usr/bin/helium` (Helium browser via imput/helium COPR)
   - `home-manager generations | head -1` → at least one generation present (NXH-12)
   - `which code` → `~/.nix-profile/bin/code` (VS Code via home.nix, supersedes ATH-17)
   - `code --list-extensions` → `ms-vscode-remote.remote-ssh` + `ms-vscode-remote.remote-containers` (declarative via `programs.vscode.extensions`; user can add more via UI)
   - `mise ls` → 12 declared tools, all lazy (ATH-27 still valid; ATH-26 superseded — no eager-install service)
   - `which nix && which nix-shell` → both resolve (NXH-06)
   - `nix-shell -p hyperfine --run 'hyperfine --version'` → succeeds (NXH-27, validates daemon + store)
   - `rpm-ostree status` → sideral current, previous deployment preserved (ATH-08)
   - **Distrobox check** (NXH+distrobox.conf): `distrobox create --image fedora:42 t && distrobox enter t -- nix --version` → succeeds, proves /nix is mounted and bashrc sources daemon profile

## Task-level gate matrix
| Task touches | Gate |
| --- | --- |
| *.sh scripts | `just lint` |
| Containerfile / build_files / system_files / home | `just build` |
| Justfile / README / workflow YAML / specs only | none — text only |

## Known hazards
- RPM name typos fail `dnf5 install` with a clear error — surface the failing package.
- extensions.gnome.org build-time download can fail if the uuid/shell version no longer resolves — check the returned URL before curling.
- `bootc container lint` is the last step of `just build`; reading failures earlier (dnf, post-install) is faster than waiting for lint.
