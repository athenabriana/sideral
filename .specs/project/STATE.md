# athens-os — Project State

Persistent memory: decisions, blockers, lessons, todos, deferred ideas.

## Current feature
- `nix-home` — migrates user-level config to nix + home-manager, collapses `/etc/skel` to a single `home.nix`, moves mise from RPM to nix. 40 requirements across 7 user stories. See `.specs/features/nix-home/spec.md`.

## Roadmap
- See `.specs/project/ROADMAP.md` for queued (`image-ops`) and backlog (`gnome-extras`, `ublue-adopt`, `nix-extras-v2`, hardware, security) features.

## Previous feature
- `athens-os` — fork from `fedora-athens`/Hyprland lineage into GNOME + tiling-shell on `silverblue-main:43`. 27 requirements across 5 user stories. See `.specs/features/athens-os/spec.md`. Requirements ATH-17, ATH-23, ATH-24, ATH-26 are superseded by `nix-home` (see that feature's spec.md → Supersedes table).

## Locked decisions
See `.specs/features/athens-os/context.md` (9 decisions, some now superseded) and `.specs/features/nix-home/context.md` (15 decisions). Highlights:
- Desktop: GNOME + tiling-shell, Hyprland dropped entirely.
- Browser: Zen Browser via flatpak (`app.zen_browser.zen`). helium-bin dropped 2026-04-23 due to imput/helium COPR's `/opt/helium` unpack conflict with Silverblue's tmpfiles-managed `/opt`; supersedes earlier "helium via COPR" decision.
- Editor: `vscode` via `programs.vscode` in home.nix (with `ms-vscode-remote.remote-ssh` + `remote-containers`); supersedes ATH-14, ATH-15, ATH-17 (VS Code RPM + athens-vscode-setup.service removed; vscode.repo file deleted).
- Container: `docker-ce` + `containerd.io` from docker-ce-stable repo.
- **User layer:** nix + home-manager is the sole source of user-level config. `/etc/skel` reduced to one file: `~/.config/home-manager/home.nix`.
- **Nix:** upstream CppNix via `NixOS/experimental-nix-installer`, baked binary at `/usr/libexec/nix-installer`, first-boot `ostree` planner, `/nix` bind-mounted from `/var/lib/nix`, `restorecon` post-install, default NixOS behavior (flakes off, channels).
- **home-manager:** channels-based (release-24.11), bootstrapped on first login via user systemd unit, starter `home.nix` declares bash/starship/git/atuin + `pkgs.mise` + inlined mise config.
- **mise:** moved from RPM to nix (via `home.packages`); `mise.jdx.dev/rpm/` repo and `athens-mise-install.service` removed.
- **Dropped:** `direnv` (user declined), `act` (on-demand via `nix profile install`), `atuin`/`starship`/`mise` from `/etc/skel/.bashrc` (now home-manager-managed).
- Shell: bash only; `~/.bashrc` now home-manager-managed (was `/etc/skel/.bashrc`).
- Fonts: Source Serif 4 + Source Sans 3 built from Adobe GitHub at image time; cascadia-code, jetbrains-mono, adwaita, opendyslexic from Fedora.
- Flatpaks: 7 curated refs via systemd oneshot on first boot.
- No distrobox pre-bake (DistroShelf flatpak available on demand).
- **Host-only:** mise and nix are both host-only; `host + distrobox` invariant dropped.
- No brew (user declined; nix via flakes + nix profile covers ad-hoc CLI tooling, mise covers language runtimes).

## Known blockers
None yet.

## nix-home implementation status (Apr 2026)
All 9 tasks implemented locally. Local gate limited to `bash -n` + INI parse + grep invariants
(shellcheck/podman/just not on this dev host). Full `just build` + `bootc container lint` runs in
CI. Runtime criteria (NXH-06/27/28) require VM rebase to verify.

**Spec deviation**: NXH-01 URL/asset text is stale. Upstream renamed
`experimental-nix-installer` → `nix-installer`; x86_64 asset is `nix-installer-x86_64-linux`
(dropped the `-unknown-linux-gnu` suffix). Using `2.34.5` pin. Spec intent (upstream CppNix via
installer's ostree planner, per D-01) unchanged. See `.specs/features/nix-home/tasks.md`
SPEC-DEV-01. Update spec.md NXH-01 text when promoting to Verified.

## Lessons
- **docker-ce repo is both shipped AND registered at build time.** Shipped file (`/etc/yum.repos.d/docker-ce.repo`) is for `rpm-ostree upgrade` to see. Inline `dnf5 config-manager addrepo --from-repofile=<URL>` in `build.sh` is for the build itself — the shipped copy isn't available during the RUN step because `COPY system_files/etc /etc` happens *after* `build.sh`.
- **`--allowerasing` is required** on the dnf5 install that adds `containerd.io`, because Fedora's `containerd` is already present in `silverblue-main:43` and dnf can't swap it without explicit permission.
- **GNOME-extension download at build time** needs the real `gnome-shell --version` of the running container — we call it inside the container (since silverblue-main ships gnome-shell), then query `extensions.gnome.org/extension-info/?uuid=<uuid>&shell_version=<N>`. `glib2-devel`/`jq`/`unzip` are installed and removed in the same script so they don't bloat the final layer.
- **`dconf update` must run after `COPY system_files/etc /etc`.** The Containerfile now has a second RUN step for that, followed by the final `ostree container commit`.
- **flatpak-install service is system-level, not user.** System-wide flatpaks live under `/var/lib/flatpak`, which is mutable on atomic. User-level would require a per-user unit, which we already use for `mise` and `vscode-setup`.
- **Persistent COPR pattern**: repos enabled during build.sh + kept enabled in the shipped image let `rpm-ostree upgrade` pull new releases without touching the image. Currently used for `ublue-os/packages` (bazaar). Same applies to docker-ce.repo (Docker Inc's official dnf repo, shipped as /etc/yum.repos.d/docker-ce.repo).
- **Dev host shell used here had no podman / just / shellcheck**, so the final gate was limited to `bash -n` on shell scripts, YAML parse, and INI parse on dconf files. The real `just build` gate runs in CI.

## Deferred
- Tailscale daemon + GNOME indicator.
- ISO / QCOW2 / bootc-image-builder outputs.
- Matrix builds (aarch64).
