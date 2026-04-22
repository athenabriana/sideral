# athens-os — Project State

Persistent memory: decisions, blockers, lessons, todos, deferred ideas.

## Current feature
- `athens-os` — fork from `fedora-athens`/Hyprland lineage into GNOME + tiling-shell on `silverblue-main:43`. 28 requirements across 5 user stories. See `.specs/features/athens-os/spec.md`.

## Locked decisions
See `.specs/features/athens-os/context.md` (9 decisions). Highlights:
- Desktop: GNOME + tiling-shell, Hyprland dropped entirely.
- Browser: `helium-bin` via `imput/helium` COPR (COPR kept enabled for updates).
- Editor: `code` from Microsoft's repo (vscode.repo kept enabled for updates).
- Container: `docker-ce` + `containerd.io` from docker-ce-stable repo.
- mise: user-level install via first-login systemd unit; no `/usr` mise binary.
- Shell: bash only; `/etc/skel/.bashrc` activates starship+mise+atuin+direnv.
- Fonts: Source Serif 4 + Source Sans 3 built from Adobe GitHub at image time; cascadia-code, jetbrains-mono, adwaita, opendyslexic from Fedora.
- Flatpaks: 7 curated refs via systemd oneshot on first boot.
- No distrobox pre-bake (DistroShelf flatpak available on demand).
- No brew (user declined; mise + flatpak + docker cover the gaps).

## Known blockers
None yet.

## Lessons
- **docker-ce repo is both shipped AND registered at build time.** Shipped file (`/etc/yum.repos.d/docker-ce.repo`) is for `rpm-ostree upgrade` to see. Inline `dnf5 config-manager addrepo --from-repofile=<URL>` in `build.sh` is for the build itself — the shipped copy isn't available during the RUN step because `COPY system_files/etc /etc` happens *after* `build.sh`.
- **`--allowerasing` is required** on the dnf5 install that adds `containerd.io`, because Fedora's `containerd` is already present in `silverblue-main:43` and dnf can't swap it without explicit permission.
- **GNOME-extension download at build time** needs the real `gnome-shell --version` of the running container — we call it inside the container (since silverblue-main ships gnome-shell), then query `extensions.gnome.org/extension-info/?uuid=<uuid>&shell_version=<N>`. `glib2-devel`/`jq`/`unzip` are installed and removed in the same script so they don't bloat the final layer.
- **`dconf update` must run after `COPY system_files/etc /etc`.** The Containerfile now has a second RUN step for that, followed by the final `ostree container commit`.
- **flatpak-install service is system-level, not user.** System-wide flatpaks live under `/var/lib/flatpak`, which is mutable on atomic. User-level would require a per-user unit, which we already use for `mise` and `vscode-setup`.
- **imput/helium COPR is left enabled** after build so `rpm-ostree upgrade` pulls new Helium releases between image builds. Same applies to Microsoft's vscode repo and docker-ce repo.
- **Dev host shell used here had no podman / just / shellcheck**, so the final gate was limited to `bash -n` on shell scripts, YAML parse, and INI parse on dconf files. The real `just build` gate runs in CI.

## Deferred
- Tailscale daemon + GNOME indicator.
- ISO / QCOW2 / bootc-image-builder outputs.
- Matrix builds (aarch64).
