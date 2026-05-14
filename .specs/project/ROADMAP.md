# silverfox — Roadmap

Features in flight, queued, and parked. Updated as decisions are made.

---

## Current

- **`nix+nh` (revived 2026-05-13)** — Declarative user config via nix + nh. Determinate installer on first boot, `/nix` persists via `/var/lib/nix` bind-mount. `nh home switch` substitui home-manager. `nh clean` pra GC. Starter flake.nix em `/etc/skel` como stow package. 33 requirements. Spec em `.specs/features/nix/`.

- **`fox-enhancements` (in flight, 2026-05-11)** — port useful ujust recipes to fox, ship silverfox-owned motd display script, and remove the inherited `ublue-os-just` RPM. `fox` gains `toggle-banner`, `upgrade-firmware`, expanded `upgrade` (ostree + flatpak + distrobox), expanded `cleanup` (podman + flatpak + ostree). `silverfox-shell-ux` gains `/etc/profile.d/silverfox-motd.sh`. `ublue-os-just` pruned from image build. 17 testable requirements. Spec at `.specs/features/fox-enhancements/`.

## Previous (shipped)

- **`fox`** — silverfox-owned operator CLI (~20-line bash dispatcher around `just`) replacing the ujust extension slot, paired with a `/etc/skel`-seeded user-domain dotfile model and the retirement of `silverfox-stow-defaults` + the gdrive integration. Two new modules (`fox/`, `home/`), one narrowed (`shell-ux/`), one retired (`dotfiles/`). 47 testable requirements, 18 locked decisions. Spec preserved at `.specs/features/fox/`.
- **`chezmoi-home`** — replaced `nix-home`. Drops nix entirely; user-config layer is chezmoi (Fedora-packaged Go binary) + RPM-layered CLI tools. 23 requirements, 9 locked decisions. Source-tree changes landed 2026-05-01 (T01–T14); CI-validated continuously since.
- **`silverfox-rpms`** — package silverfox customizations into 8 sub-packages (now organized under `os/modules/<capability>/rpm/<spec>` post 2026-05-02 refactor; spec names kept stable for upgrade safety). Inline build inside the Containerfile (no Copr, no token, no external service). Renamed from `silverfox-copr` on 2026-04-29; Phase R landed 2026-04-30 (CI run 25188178498, sha `e06bc39`). 26 requirements; ACR-29 (signed-rebase README cutover) and ACR-38 (drift-detection CI) deferred and non-blocking.
- **`silverfox`** — fork from Hyprland lineage into GNOME + tiling-shell on silverblue-main:43. 27 requirements. ATH-04 amended 2026-05-01 → 2026-05-02: 5 → 4 enabled extensions (bazaar-integration retired with original Bazaar→GNOME-Software swap; the later 2026-05-02 GNOME-Software→Bazaar reversion did NOT bring it back — Bazaar is a flatpak now, not an in-shell integration).

## Considered, dropped

- **`nix-home`** — retired pre-VM-verification 2026-05-01. Composefs vs ostree planner ([nix-installer#1445](https://github.com/DeterminateSystems/nix-installer/issues/1445)) + SELinux mislabel ([#1383](https://github.com/DeterminateSystems/nix-installer/issues/1383)) + post-upgrade-survival reports on F42+ make nix fragile on Fedora atomic 43. Replaced by `chezmoi-home`. Spec preserved at `.specs/features/nix-home/spec.md`.
- **`niri-shell`** — niri scrollable-tiling compositor + Noctalia shell + SDDM/SilentSDDM + matugen. Implemented through 2026-05-04 and reverted 2026-05-10. User decision: keep stock GNOME inherited from `silverblue-main`. The compositor swap was carrying too much surface area (Terra repo, full GNOME conflict-removal, kanata Super-tap-vs-hold, fcitx5 IME wiring, NVIDIA niri-specific tweaks, three-island Quickshell deferred work) for a single-user image; vanilla GNOME is "good enough" without the maintenance tax. Feature spec dir + `niri-islands` backlog item retired with it. ghostty terminal (the one Terra package worth keeping) was relocated to `silverfox-cli-tools`.
- **`chezmoi` for dotfile seeding** — replaced with GNU stow on 2026-05-10. Both `chezmoi-home` (CLI tool layer) and `chezmoi-dotfiles` (image-default dotfile seeding via chezmoi) features were superseded. Reasons: stow's symlink-farm model lines up with atomic Fedora's own immutable-source pattern (`/usr/etc` symlinks to ostree commits); zero state machine to drift; one verb (`stow`) instead of chezmoi's `dot_*`/`run_onchange_*`/`executable_*` source-format vocabulary; ancient/ubiquitous Perl tool with no breaking-change risk; cleaner `stow -D` rollback. Cost paid: lost the dual-source diff-prompt UX (image defaults + personal repo no longer auto-reconcile — manual conflict resolution if both touch the same path) and the `run_onchange` script hook (the nushell vendor-autoload regen disappeared with nushell itself, so this cost was zero in practice). Spec preserved at `.specs/features/chezmoi-home/` and `.specs/features/chezmoi-dotfiles/` for historical reference. nushell removed in the same pass.
- **stow-on-first-login dotfile seeding** — superseded 2026-05-11 by the `fox` feature's `/etc/skel` + useradd model. Reason: stow-on-first-login still left `~/.bashrc` as a symlink into a read-only ostree path (`/usr/share/silverfox/stow/…`), making in-place edits require a "break the symlink, copy out, edit, on next apply stow leaves it alone" dance. The `/etc/skel` approach copies real files into new user homes once at useradd time (cp -a preserves the symlink-into-stow-subtree topology), making dotfiles directly user-editable and removing the read-only-ostree friction. Cost: existing users don't auto-update on image rebuild — opt-in via `fox home factory-reset` (destructive) or manual cp from `/etc/skel`. Spec preserved at `.specs/features/fox/`.

---

## Queued — next 1–2 features

### `image-ops` — CI & image-delivery hardening

**Scope**: everything in Tier 1 of the April 2026 research synthesis. All independent of the user layer.

| Item | Why | Source |
|---|---|---|
| Rechunk in CI | ~85% reduction in `rpm-ostree upgrade` delta sizes; standard across Bluefin/Aurora/Bazzite | [hhd-dev/rechunk](https://github.com/hhd-dev/rechunk) |
| Ship trust policy files | `os/modules/signing/src/etc/containers/policy.json` already exists as a permissive placeholder; the full schema lives in `os/modules/signing/UPGRADE.md` | [rpm-ostree #4272](https://github.com/coreos/rpm-ostree/issues/4272) |
| Drop `COSIGN_EXPERIMENTAL=true` env var | Obsolete since cosign v2 | `.github/workflows/build.yml` |
| Renovate config | Dependabot doesn't parse Containerfile `ARG` patterns; Renovate tracks base image tag + upstream repos | [renovatebot docs](https://docs.renovatebot.com/modules/manager/dockerfile/) |
| `fedora-multimedia` swap | `dnf5 swap ffmpeg-free ffmpeg --allowerasing` via RPMFusion → hardware-accelerated H.264/HEVC | Bluefin pattern |
| Actions cache for `/var/lib/containers` | Cuts base-image pull time; keeps builds under 12 min | [ublue-os/container-storage-action](https://github.com/ublue-os/container-storage-action) |

**Entry criterion**: independent of other features; can run any time.

---

## Backlog — enhancement features (unscheduled)

### `fox-home-sync` (v2 of the fox feature)

**Scope**: declarative user-level config — silverfox's home-manager equivalent, without the nix substrate. v1's `fox home factory-reset` is the imperative counterpart; v2 introduces reconciliation.

- **Manifests**: TOML files under `~/.config/silverfox/manifests/` (user-domain only — no system-level `/etc/silverfox/` reservation, per fox D-17). First backend likely flatpaks (`flatpaks.toml` enumerating desired remotes + refs); follow-ups: dconf snapshots, systemd-user units, optional VS Code / Zed extensions.
- **Verb**: `fox home sync` reads manifests, diffs current state, applies. The reconciliation contract (`SyncCommand<T>` or equivalent) is intentionally NOT shipped in v1 — designing it without a real backend risks getting the type shape wrong. v2 lands it alongside the first backend so the abstraction emerges from real use.
- **Substrate (open)**: bash + jq, Bun + TypeScript, Rust + clap, or Go + cobra. v1's bash dispatcher leaves the choice genuinely free — the v2 Justfile recipe for `home::sync` can swap `bash /usr/libexec/silverfox/sync.sh` for a compiled binary without touching `/usr/bin/fox`. Reach for a typed runtime *only* when v2's substance warrants the cost.
- **Generations / rollback**: NOT replicated inside fox. Users `git init` in `~/.config/silverfox/manifests/`; selective rollback is `git checkout <path>`; full revert to image defaults is `fox home factory-reset`.

See `.specs/features/fox/context.md` D-16 (home-manager framing) and D-17 (manifests location).

**Entry criterion**: v1 fox shipped and stable; a concrete backend need surfaces (e.g., flatpak set diverges from `os/modules/flatpaks/flatpak-list` enough that a one-shot reconciler beats manual `flatpak install`/`uninstall`).

### `gnome-extras`

**Scope**: curated GNOME extension + flatpak additions from Tier 3 research that did NOT land in the 2026-05-02 manifest grow-out.

- **Extensions still pending**: Caffeine (suspend control during builds/docker), Vitals (CPU/RAM/temp/net in top bar), Just Perfection (shell tweaker), Blur my Shell, GSConnect (KDE Connect for GNOME), Pano (visual clipboard history) — skip Flameshot (Wayland broken), Forge (seeking maintainer), Pop-shell (lags upstream).
- **Already-landed flatpaks** (dropped from this list 2026-05-02): Pika Backup ✓, Junction ✓, Web App Hub ✓, Bazaar ✓.
- **Flatpaks still pending**: Apostrophe (markdown writing), Text Pieces (text transforms / scratchpad), Foliate (EPUB + OpenDyslexic reflow), Kooha (screen recorder), Dialect (translator), Ulauncher (fast Wayland app launcher).
- **Accessibility defaults for dyslexia-friendly env**: `cursor-blink=false`, key repeat 250ms/30Hz, surface Color Filters toggle in Quick Settings.

### `ublue-adopt`

**Scope**: selectively borrow opinionated patterns from ublue-os ecosystem.

- ~~**`ublue-os-signing`** package~~ — silverfox-signing is intentionally Conflicts: against it; not adopting.
- ~~**`ujust` recipe fragment layout**~~ — retired 2026-05-11 with the `fox` feature. silverfox now owns its operator CLI at `/usr/bin/fox` (silverfox-fox RPM); 60-custom.just deleted. Plain `just` (stock Fedora) is retained as fox's dispatch backend.
- ✓ **Welcome script** — *replaced by `/etc/user-motd`* (every-login banner via inherited `ublue-os-just`'s `/etc/profile.d/user-motd.sh`). Per-user opt-out via `~/.config/no-show-user-motd`. Content rewritten 2026-05-11 to use `fox` verbs.
- ✓ **bootc-image-builder ISO** — landed 2026-04-30 (`build-iso.yml`). qcow2 / raw still skipped.

### Hardware support

- Tailscale preinstall + systemd unit (when actually used)
- `fwupd-refresh.timer` explicitly enabled (verify state)
- ✓ **NVIDIA variant** — *landed 2026-05-02*. Separate `silverfox-nvidia` ghcr image; ISO installer reads `lspci` and rebases to the matching variant.

### `bootloader-swap` — drop GRUB

**Scope**: replace inherited GRUB2 with systemd-boot (sd-boot), Limine, or rEFInd. User preference flagged 2026-05-02 — GRUB is the friction. Atomic Fedora's bootloader story is GRUB2 + BLS managed by rpm-ostree via bootupd; swapping means rewriting bootupd integration, anaconda-hook.sh ISO logic, and any kargs.d consumers (`os/build/nvidia/kargs.d/00-nvidia.toml` would need to verify cross-bootloader compatibility). Spec deferred to its own feature dir when promoted.

### Security hardening (selective, from secureblue)

- Sysctl: `kernel.kptr_restrict`, `kernel.dmesg_restrict`
- Modprobe blacklist for firewire + uncommon filesystems
- **Skip**: USBGuard (too dev-hostile), hardened_malloc (breaks docker/some runtimes)

---

## Explicit non-goals (re-confirmed April 2026 after research; updated 2026-05-02)

- **Nix as user-level package manager** — *revived 2026-05-13*. The three historical blockers (composefs, SELinux, post-upgrade) are all addressable: Determinate installer handles SELinux, systemd `.mount` unit handles composefs, `--persistence /var/lib/nix` handles post-upgrade survival. Spec at `.specs/features/nix/`. nh wraps the workflow.
- **Flake-based workflow by default** — *revived 2026-05-13*. Starter flake.nix ships in the nix stow package. `nh home switch` applies it.
- **`direnv` / `nix-direnv`** — dropped per user preference.
- **`devenv`** — required flakes + nix-command; n/a.
- **Determinate Nix fork** — n/a.
- **bootc migration** — premature in 2026; F45 will ship compat shims; one-line swap later.
- **Docker (rootful) as the container runtime** — *added 2026-05-02*. Replaced by rootless podman + `podman-docker`/`podman-compose` shims. Avoids the docker group footgun, the `--allowerasing` containerd swap, and the ostree-unfriendly `/var/lib/docker` storage. `DOCKER_HOST` points at the per-user podman socket so testcontainers / IDE plugins / docker-compose binaries that consult `$DOCKER_HOST` all see the rootless engine.
- **gnome-software as the app store** — *added 2026-05-02*. Bazaar (Flathub) is canonical. Reverses the brief 2026-05-01 detour where bazaar was dropped for gnome-software; matches bluefin's current direction and removes the gnome-software-shell-extension dependency.
- **KDE / gaming / Bazzite-style additions** — out of scope for dev-focused personal image.
- **CachyOS / Xanmod kernel swap** — too risky on atomic; no concrete need.
- **USBGuard, hardened_malloc** — dev-hostile.
- **qcow2 / raw disk outputs** — rebase-only workflow for daily use; revisit if VM-style images become relevant. (ISO output landed 2026-04-30; see `.github/workflows/build-iso.yml`.)
- **Matrix builds (aarch64, OS variants beyond NVIDIA)** — single amd64 image (× 2 GPU variants) for personal use.
- **Public distribution** — personal use only. (chezmoi-home D-02 weighs community fit but does not change this non-goal.)
- **`nix-extras-v2` backlog feature** — *retired 2026-05-01* alongside `nix-home`. Equivalents under chezmoi: tmux/neovim configs are user-managed dotfiles; secrets via Bitwarden CLI helpers or chezmoi's `bitwarden` template func; multi-host via chezmoi's `.chezmoi.osRelease.variantId` templating.

---

## How to use this file

- **Picking the next feature**: work top-down through Queued, then Backlog.
- **Adding a backlog item**: one bullet with a one-line rationale. Promote to Queued when a concrete trigger appears.
- **Retiring a backlog item**: move to "Explicit non-goals" with a dated rationale.
- **Starting a feature**: move from Queued to Current, create `.specs/features/<name>/`, run `/spec-create`.
- **Dropping a current feature**: move to "Considered, dropped" with a dated rationale + link to the replacement (if any) and to the relevant context.md decision.

Last research sweep: April 2026 — findings preserved in this file; re-sweep when it's been >6 months.
