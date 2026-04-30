# athens-os — Roadmap

Features in flight, queued, and parked. Updated as decisions are made.

---

## Current

- **`nix-home`** — migrate user-level config to nix + home-manager, collapse `/etc/skel` to a single `home.nix`, move mise from RPM to nix. Implementation done locally; runtime verification pending VM rebase. 40 requirements, 15 locked decisions. See `.specs/features/nix-home/`.

## Previous (shipped)

- **`athens-rpms`** — package athens-os customizations into 8 sub-packages, build them inline inside the Containerfile (no Copr, no token, no external service). Renamed from `athens-copr` on 2026-04-29; Phase R landed 2026-04-30 (CI run 25188178498, sha `e06bc39`). 26 requirements; ACR-29 (signed-rebase README cutover) and ACR-38 (drift-detection CI) deferred and non-blocking. See `.specs/features/athens-rpms/`.
- **`athens-os`** — fork from Hyprland lineage into GNOME + tiling-shell on silverblue-main:43. 27 requirements. Four requirements (ATH-17, ATH-23, ATH-24, ATH-26) superseded by `nix-home`.

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

**Entry criterion**: `nix-home` Verified AND `athens-rpms` Phase R landed.

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
- **`ujust` recipe fragment layout** — `/etc/ublue-os/just/*.just` aggregated into `/etc/justfile`. One fragment per concern. Strong fit since athens-os already ships a Justfile.
- **Welcome script** — minimal `just onboard` invoking a first-run wizard (prompt for git identity, offer to log into `gh`, optionally run `home-manager switch`).
- **bootc-image-builder recipes** — `just build-qcow2` / `build-iso` for when installable ISOs become useful. Skip for now (personal rebase-only workflow).

### `nix-extras-v2`

**Scope**: next-layer home.nix additions once the base nix-home is proven in daily use.

- `programs.tmux` with declarative plugins
- `programs.neovim` with declarative plugins (or continue via VS Code only)
- `programs.carapace` — multi-shell completion engine
- `sops-nix` — secrets management (SSH keys, GPG keys, API tokens) once actually needed
- Nixpkgs overlays directory for personal packages not yet upstream
- Multi-host home.nix structure (`modules/cli.nix`, `modules/dev.nix`, `hosts/athens.nix`) for future Mac/NixOS portability

### Hardware support

- Tailscale preinstall + systemd unit (when actually used)
- `fwupd-refresh.timer` explicitly enabled (verify state)
- NVIDIA variant — only if NVIDIA hardware is involved

### Security hardening (selective, from secureblue)

- Sysctl: `kernel.kptr_restrict`, `kernel.dmesg_restrict`
- Modprobe blacklist for firewire + uncommon filesystems
- **Skip**: USBGuard (too dev-hostile), hardened_malloc (breaks docker/some runtimes)

---

## Explicit non-goals (re-confirmed April 2026 after research)

- **Flake-based workflow by default** — decision D-02 in nix-home; user can enable per-user via one line in `~/.config/nix/nix.conf`
- **`direnv` / `nix-direnv`** — decision D-08; dropped per user preference
- **`devenv`** — requires flakes + nix-command; conflicts with D-02
- **Determinate Nix fork** — decision D-01; upstream CppNix chosen for portability + community alignment
- **bootc migration** — premature in 2026; F45 will ship compat shims; one-line swap later
- **KDE / gaming / Bazzite-style additions** — out of scope for dev-focused personal image
- **CachyOS / Xanmod kernel swap** — too risky on atomic; no concrete need
- **USBGuard, hardened_malloc** — dev-hostile
- **ISO / qcow2 / raw disk outputs** — rebase-only workflow; revisit if bare-metal reinstall becomes relevant
- **Matrix builds (aarch64, variants)** — single amd64 image for personal use
- **Public distribution** — personal use only

---

## How to use this file

- **Picking the next feature**: work top-down through Queued, then Backlog.
- **Adding a backlog item**: one bullet with a one-line rationale. Promote to Queued when a concrete trigger appears.
- **Retiring a backlog item**: move to "Explicit non-goals" with a dated rationale.
- **Starting a feature**: move from Queued to Current, create `.specs/features/<name>/`, run `/spec-create`.

Last research sweep: April 2026 — findings preserved in this file; re-sweep when it's been >6 months.
