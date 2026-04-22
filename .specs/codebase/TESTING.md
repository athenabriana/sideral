# Testing — athens-os

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
3. Log in, check:
   - `gnome-extensions list --enabled` → 5 UUIDs (ATH-04)
   - `flatpak list --app` → 7 refs (ATH-13)
   - `code --list-extensions` → 3 UUIDs (ATH-17)
   - `mise ls` → act/atuin/direnv installed, others lazy (ATH-26/27)
   - `rpm-ostree status` → athens-os current, previous deployment preserved (ATH-08)

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
