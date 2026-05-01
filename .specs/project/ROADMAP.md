# sideral — Roadmap

Features in flight, queued, and parked. Updated as decisions are made.

---

## Current

- **`chezmoi-home`** — replaces `nix-home`. Drops nix entirely; user-config layer becomes chezmoi (Fedora-packaged Go binary) + RPM-layered CLI tools. 23 requirements, 9 locked decisions. See `.specs/features/chezmoi-home/`. Source-tree changes landed 2026-05-01 via `/spec-run chezmoi-home` (T01–T14); `just build` verification (T15) pending on a host with podman + shellcheck.

## Previous (shipped)

- **`sideral-rpms`** — package sideral customizations into 8 sub-packages, build them inline inside the Containerfile (no Copr, no token, no external service). Renamed from `sideral-copr` on 2026-04-29; Phase R landed 2026-04-30 (CI run 25188178498, sha `e06bc39`). 26 requirements; ACR-29 (signed-rebase README cutover) and ACR-38 (drift-detection CI) deferred and non-blocking. See `.specs/features/sideral-rpms/`.
- **`sideral`** — fork from Hyprland lineage into GNOME + tiling-shell on silverblue-main:43. 27 requirements. ATH-17, ATH-23, ATH-24, ATH-26 superseded by `nix-home`; partially restored by `chezmoi-home` (ATH-14/15 yes, ATH-23/24/26 no — those move to user-managed chezmoi). ATH-04 amended 2026-05-01: 5 → 4 enabled extensions (bazaar-integration removed alongside Bazaar→GNOME-Software app-store swap; flatpak preferred over rpm via `org.gnome.software.packaging-format-preference` dconf default).

## Considered, dropped

- **`nix-home`** — designed and implemented locally (40 requirements, 15 locked decisions, 9 tasks complete) but **retired before VM verification on 2026-05-01**. Reason: composefs vs nix-installer ostree planner ([nix-installer#1445](https://github.com/DeterminateSystems/nix-installer/issues/1445)), SELinux mislabel of /nix store paths ([#1383](https://github.com/DeterminateSystems/nix-installer/issues/1383), open since 2023), and `/nix` + nix-daemon disappearing after `rpm-ostree upgrade` on F42+ (multiple Universal Blue forum reports). silverblue-main:43 was in the impact zone for all three. Replaced by `chezmoi-home`. Spec preserved at `.specs/features/nix-home/spec.md` for historical reference. See `.specs/features/chezmoi-home/context.md` D-01 for full rationale.

---

## Queued — next 1–2 features

### `image-ops` — CI & image-delivery hardening

**Scope**: everything in Tier 1 of the April 2026 research synthesis. All independent of the user layer.

| Item | Why | Source |
|---|---|---|
| Rechunk in CI | ~85% reduction in `rpm-ostree upgrade` delta sizes; standard across Bluefin/Aurora/Bazzite | [hhd-dev/rechunk](https://github.com/hhd-dev/rechunk) |
| Ship trust policy files | `system_files/etc/containers/policy.json` + `registries.d/ghcr.io.yaml` → users rebase via `ostree-image-signed:` instead of `ostree-unverified-registry:` | [rpm-ostree #4272](https://github.com/coreos/rpm-ostree/issues/4272) |
| Drop `COSIGN_EXPERIMENTAL=true` env var | Obsolete since cosign v2 | `.github/workflows/build.yml` |
| Renovate config | Dependabot doesn't parse Containerfile `ARG` patterns; Renovate tracks base image tag + COPRs + upstream repos | [renovatebot docs](https://docs.renovatebot.com/modules/manager/dockerfile/) |
| `fedora-multimedia` swap | `dnf5 swap ffmpeg-free ffmpeg --allowerasing` via RPMFusion → hardware-accelerated H.264/HEVC in Helium/apps | Bluefin `build_files/` |
| Actions cache for `/var/lib/containers` | Cuts base-image pull time; keeps builds under 12 min | [ublue-os/container-storage-action](https://github.com/ublue-os/container-storage-action) |

**Entry criterion**: `chezmoi-home` shipped AND `sideral-rpms` Phase R landed (was: `nix-home` Verified). The latter is met; the former is the new gate.

---

## Backlog — enhancement features (unscheduled)

### `gnome-extras`

**Scope**: curated GNOME extension + flatpak additions from Tier 3 research.

- **Extensions**: Caffeine (suspend control during builds/docker), Vitals (CPU/RAM/temp/net in top bar), Just Perfection (shell tweaker), Blur my Shell, GSConnect (KDE Connect for GNOME), Pano (visual clipboard history) — skip Flameshot (Wayland broken), Forge (seeking maintainer), Pop-shell (lags upstream).
- **Flatpaks to add**: Pika Backup (Borg GUI), Apostrophe (markdown writing), Text Pieces (text transforms / scratchpad), Foliate (EPUB + OpenDyslexic reflow), Kooha (screen recorder), Dialect (translator), Ulauncher (fast Wayland app launcher).
- **Accessibility defaults for dyslexia-friendly env**: `cursor-blink=false`, key repeat 250ms/30Hz, surface Color Filters toggle in Quick Settings.

### `ublue-adopt`

**Scope**: selectively borrow opinionated patterns from ublue-os ecosystem.

- **`ublue-os-signing`** package — ships `/etc/containers/policy.json` correctly out of the box (partial overlap with `image-ops`; decide whether to reuse the package or hand-roll).
- **`ujust` recipe fragment layout** — `/etc/ublue-os/just/*.just` aggregated into `/etc/justfile`. One fragment per concern. Strong fit since sideral already ships a Justfile.
- **Welcome script** — minimal `just onboard` invoking a first-run wizard (prompt for git identity, offer to log into `gh`, optionally run `chezmoi init`).
- **bootc-image-builder recipes** — ~~`just build-qcow2`~~ / `build-iso` for when installable ISOs become useful. Promoted out of backlog 2026-04-30: `.github/workflows/build-iso.yml` builds an Anaconda ISO from `ghcr.io/<owner>/sideral:<tag>` and publishes to GitHub Releases (workflow_dispatch + push of `v*` tags). qcow2 / raw still skipped (rebase-only workflow).

### Hardware support

- Tailscale preinstall + systemd unit (when actually used)
- `fwupd-refresh.timer` explicitly enabled (verify state)
- NVIDIA variant — only if NVIDIA hardware is involved

### Security hardening (selective, from secureblue)

- Sysctl: `kernel.kptr_restrict`, `kernel.dmesg_restrict`
- Modprobe blacklist for firewire + uncommon filesystems
- **Skip**: USBGuard (too dev-hostile), hardened_malloc (breaks docker/some runtimes)

---

## Explicit non-goals (re-confirmed April 2026 after research; updated 2026-05-01)

- **Nix as user-level package manager** — *added 2026-05-01*. Considered and dropped via `nix-home` → `chezmoi-home` pivot. Reason: composefs vs ostree planner ([nix-installer#1445](https://github.com/DeterminateSystems/nix-installer/issues/1445)) + SELinux mislabel ([#1383](https://github.com/DeterminateSystems/nix-installer/issues/1383)) + post-upgrade-survival reports on F42+ make nix fragile on Fedora atomic 43. User-config layer is chezmoi + RPMs. Revisit if upstream resolves all three issues. See `.specs/features/chezmoi-home/context.md` D-01.
- **Flake-based workflow by default** — n/a now that nix is gone.
- **`direnv` / `nix-direnv`** — dropped per user preference.
- **`devenv`** — required flakes + nix-command; n/a now.
- **Determinate Nix fork** — n/a now.
- **bootc migration** — premature in 2026; F45 will ship compat shims; one-line swap later.
- **KDE / gaming / Bazzite-style additions** — out of scope for dev-focused personal image.
- **CachyOS / Xanmod kernel swap** — too risky on atomic; no concrete need.
- **USBGuard, hardened_malloc** — dev-hostile.
- **qcow2 / raw disk outputs** — rebase-only workflow for daily use; revisit if VM-style images become relevant. (ISO output landed 2026-04-30; see `.github/workflows/build-iso.yml`.)
- **Matrix builds (aarch64, variants)** — single amd64 image for personal use.
- **Public distribution** — personal use only. (chezmoi-home D-02 weighs community fit but does not change this non-goal.)
- **`nix-extras-v2` backlog feature** — *retired 2026-05-01* alongside `nix-home`. The `programs.tmux` / `programs.neovim` / `programs.carapace` / `sops-nix` / Nixpkgs overlays / multi-host home.nix ideas are gone. Equivalents under chezmoi: tmux/neovim configs are user-managed dotfiles; secrets via Bitwarden CLI helpers or chezmoi's `bitwarden` template func; multi-host via chezmoi's `.chezmoi.osRelease.variantId` templating.

---

## How to use this file

- **Picking the next feature**: work top-down through Queued, then Backlog.
- **Adding a backlog item**: one bullet with a one-line rationale. Promote to Queued when a concrete trigger appears.
- **Retiring a backlog item**: move to "Explicit non-goals" with a dated rationale.
- **Starting a feature**: move from Queued to Current, create `.specs/features/<name>/`, run `/spec-create`.
- **Dropping a current feature**: move to "Considered, dropped" with a dated rationale + link to the replacement (if any) and to the relevant context.md decision.

Last research sweep: April 2026 — findings preserved in this file; re-sweep when it's been >6 months.
