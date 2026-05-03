# sideral — Roadmap

Features in flight, queued, and parked. Updated as decisions are made.

---

## Current

- **No feature in flight.** `chezmoi-home` is treated as shipped — every commit since the 2026-05-01 source-tree landing has gone through the `build-sideral` CI matrix (amd64 × {open, nvidia}, ending in `bootc container lint`), and the major post-spec waves (module refactor, docker→podman, NVIDIA variant, kubernetes module, flatpak grow-out, multi-shell parity, ujust extension slot) all required CI passes to merge. T15's "needs a host with podman + shellcheck" gate is met by CI for every push.

## Previous (shipped)

- **`chezmoi-home`** — replaced `nix-home`. Drops nix entirely; user-config layer is chezmoi (Fedora-packaged Go binary) + RPM-layered CLI tools. 23 requirements, 9 locked decisions. Source-tree changes landed 2026-05-01 (T01–T14); CI-validated continuously since.
- **`sideral-rpms`** — package sideral customizations into 8 sub-packages (now organized under `os/modules/<capability>/rpm/<spec>` post 2026-05-02 refactor; spec names kept stable for upgrade safety). Inline build inside the Containerfile (no Copr, no token, no external service). Renamed from `sideral-copr` on 2026-04-29; Phase R landed 2026-04-30 (CI run 25188178498, sha `e06bc39`). 26 requirements; ACR-29 (signed-rebase README cutover) and ACR-38 (drift-detection CI) deferred and non-blocking.
- **`sideral`** — fork from Hyprland lineage into GNOME + tiling-shell on silverblue-main:43. 27 requirements. ATH-04 amended 2026-05-01 → 2026-05-02: 5 → 4 enabled extensions (bazaar-integration retired with original Bazaar→GNOME-Software swap; the later 2026-05-02 GNOME-Software→Bazaar reversion did NOT bring it back — Bazaar is a flatpak now, not an in-shell integration).

## Considered, dropped

- **`nix-home`** — retired pre-VM-verification 2026-05-01. Composefs vs ostree planner ([nix-installer#1445](https://github.com/DeterminateSystems/nix-installer/issues/1445)) + SELinux mislabel ([#1383](https://github.com/DeterminateSystems/nix-installer/issues/1383)) + post-upgrade-survival reports on F42+ make nix fragile on Fedora atomic 43. Replaced by `chezmoi-home`. Spec preserved at `.specs/features/nix-home/spec.md`.

---

## Queued — next 1–2 features

### `nushell` — replace fish with nushell + inshellisense

**Scope**: drop fish, add nushell (Fedora main `nu` package) as the third interactive shell option alongside bash and zsh. Wire full sideral tool suite into `/usr/share/nushell/vendor/autoload/sideral-cli-init.nu` (starship, atuin, zoxide, mise, fzf, eza/bat aliases, agent detection, Ctrl-P/Alt-S/Ctrl-G keybindings). Add a systemd user service (`sideral-nushell-seed`) that seeds `~/.config/nushell/{env.nu,config.nu}` on every session if missing. Add inshellisense (`nodejs` + `npm install -g @microsoft/inshellisense` at build time) and wire Ctrl-I keybinding in bash, zsh, and nushell.

**Locked decisions**:
- D-01 = nushell replaces fish entirely; no parallel fish support
- D-02 = config seeding is an always-check idempotent user service (same pattern as flatpak self-heal)
- D-03 = inshellisense delivered via `nodejs` (Fedora main) + npm global install at build time; no standalone binary exists
- D-04 = carapace rejected (not in Fedora main or Terra)

**Spec**: `.specs/features/nushell/spec.md` — 18 requirements, ready for `/spec-run`.

**Entry criterion**: spec complete 2026-05-02. Small/Medium feature — skip `/spec-design`, go straight to `/spec-run nushell`.

### `niri-shell` — migrate off GNOME to niri + Wayland shell + matugen

**Scope**: replace the current GNOME + tiling-shell + Mutter desktop with a niri-based scrollable-tiling Wayland session and **Noctalia** (Quickshell-based shell from Terra), themed dynamically from wallpaper via matugen. Includes: SDDM + SilentSDDM theme, niri compositor (Fedora main), Noctalia + noctalia-qs (Terra), ghostty terminal (Terra), kanshi multi-monitor, fcitx5 IME, grim/slurp/wl-clipboard/cliphist for screenshot+clipboard, bluefin/bazzite-grade NVIDIA hardening on the nvidia variant, and the wiring to make sideral's existing chezmoi-driven dotfile / sideral-cli-tools / ujust / motd surface still work the same. Final repo set: Fedora main + Terra. No third-party COPRs.

**Locked decisions** (see `.specs/features/niri-shell/context.md`):
- D-01 = full GNOME replacement on `sideral:latest` + `sideral-nvidia:latest`.
- D-02 = SDDM + SilentSDDM theme.
- D-04 = ship stock **Noctalia** via Terra's `noctalia-shell` RPM. Noctalia handles bar/notifications/launcher/lock/control-center/wallpaper out of the box. Three-island aesthetic deferred to `niri-islands` (Backlog below) — Noctalia chosen partly for its minimalist architecture as a cleaner base to bar-replace.
- D-07 = ghostty via Terra's `ghostty` package.
- D-13 = niri ships on both variants (open-source GPU and NVIDIA) from day 1. No frozen GNOME-NVIDIA fallback. Bluefin/bazzite-grade NVIDIA hardening.
- D-15 = silent swap on `:latest`. **No GNOME image shipped at all** — no `:gnome-final` preservation tag. Users use `rpm-ostree rollback` or fork at pre-niri SHA for opt-out.
- D-03 = niri from Fedora main. D-10 = matugen via `rust-matugen` from Fedora main. D-14 = retired (Noctalia uses noctalia-qs, not upstream Quickshell).

**Final repo set**: Fedora main + Terra (`terra-release`). No third-party COPRs.

All decisions locked. Spec ready for `/compact` then `/spec-design`.

**Entry criterion**: all decisions locked (2026-05-02). Ready for `/compact` then `/spec-design` — this is unambiguously a Large/Complex feature even with Noctalia doing the QML-shaped heavy lifting.

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

**Entry criterion**: independent of `niri-shell`; can run in parallel.

---

## Backlog — enhancement features (unscheduled)

### `gnome-extras`

> Status note (2026-05-02): if `niri-shell` ships as a full replacement, this backlog item retires entirely; if it ships as a parallel variant, this item still applies to the GNOME variant only.

**Scope**: curated GNOME extension + flatpak additions from Tier 3 research that did NOT land in the 2026-05-02 manifest grow-out.

- **Extensions still pending**: Caffeine (suspend control during builds/docker), Vitals (CPU/RAM/temp/net in top bar), Just Perfection (shell tweaker), Blur my Shell, GSConnect (KDE Connect for GNOME), Pano (visual clipboard history) — skip Flameshot (Wayland broken), Forge (seeking maintainer), Pop-shell (lags upstream).
- **Already-landed flatpaks** (dropped from this list 2026-05-02): Pika Backup ✓, Junction ✓, Web App Hub ✓, Bazaar ✓.
- **Flatpaks still pending**: Apostrophe (markdown writing), Text Pieces (text transforms / scratchpad), Foliate (EPUB + OpenDyslexic reflow), Kooha (screen recorder), Dialect (translator), Ulauncher (fast Wayland app launcher).
- **Accessibility defaults for dyslexia-friendly env**: `cursor-blink=false`, key repeat 250ms/30Hz, surface Color Filters toggle in Quick Settings.

### `ublue-adopt`

**Scope**: selectively borrow opinionated patterns from ublue-os ecosystem.

- ~~**`ublue-os-signing`** package~~ — sideral-signing is intentionally Conflicts: against it; not adopting.
- ✓ **`ujust` recipe fragment layout** — *landed 2026-05-02*. `/usr/share/ublue-os/just/60-custom.just` ships from `sideral-shell-ux` (chsh, chezmoi-init, gdrive-setup, gdrive-remove, tools).
- ✓ **Welcome script** — *replaced by `/etc/user-motd`* (every-login banner via inherited `ublue-os-just`'s `/etc/profile.d/user-motd.sh`). Per-user opt-out via `~/.config/no-show-user-motd`.
- ✓ **bootc-image-builder ISO** — landed 2026-04-30 (`build-iso.yml`). qcow2 / raw still skipped.

### Hardware support

- Tailscale preinstall + systemd unit (when actually used)
- `fwupd-refresh.timer` explicitly enabled (verify state)
- ✓ **NVIDIA variant** — *landed 2026-05-02*. Separate `sideral-nvidia` ghcr image; ISO installer reads `lspci` and rebases to the matching variant.

### `niri-islands` — three-pill Dynamic-Island bar (DEFERRED FROM `niri-shell`)

**Scope**: replace Noctalia's stock bar with a sideral-authored three-island Quickshell layout — left island = niri-IPC-driven spatial task list (sorted left→right by column index, top→bottom within column), center island = clock/date, right island = tray + audio + network + battery. Each island is a separately-positioned floating pill modeled visually on Apple's iOS Dynamic Island. matugen-themed. Replacement scope: only the bar QML; rest of Noctalia (notifications, launcher, lock, control center, wallpaper) keeps working unchanged.

**Promotion criteria**:
- `niri-shell` shipped and stable for ~3 months of daily use.
- Three-island aesthetic still feels load-bearing in practice (not just "wouldn't it be cool").
- noctalia-qs (Quickshell fork) API surface stable enough that vendoring iNiR's NiriService.qml against it is realistic; OR fall back to vendoring upstream Quickshell alongside noctalia-qs (would require resolving noctalia-qs's `Conflicts: quickshell` declaration).

**Reference reads** (already cloned to `/tmp/research-repos/` from the 2026-05-02 research sweep):
- iNiR's `services/NiriService.qml` — most-documented public niri-IPC-to-QML pattern; vendorable.
- DMS's `Modules/DankBar/` — single-PanelWindow with three-internal-section layout that we'd refactor into three independent PanelWindows. (Even though DMS isn't shipped, its bar architecture is a useful reference.)
- caelestia's `services/*.qml` singletons — clean decompositor-agnostic Time/Audio/Battery/Network patterns.
- Noctalia's stock bar QML at `/etc/xdg/quickshell/noctalia-shell/` (in the running v1 image) — shows the integration points we'd swap.

**Cost estimate**: ~400 LOC of sideral-authored QML + matugen template additions + ongoing audit when Noctalia or matugen update.

### `bootloader-swap` — drop GRUB

**Scope**: replace inherited GRUB2 with systemd-boot (sd-boot), Limine, or rEFInd. User preference flagged 2026-05-02 — GRUB is the friction. Atomic Fedora 43's bootloader story is GRUB2 + BLS managed by rpm-ostree via bootupd; swapping means rewriting bootupd integration, anaconda-hook.sh ISO logic, and any kargs.d consumers (`os/modules/nvidia/kargs.d/00-nvidia.toml` would need to verify cross-bootloader compatibility). Spec deferred to its own feature dir when promoted; NOT bundled with niri-shell. Likely promotes to Queued AFTER `niri-shell` ships.

### `base-bump-f44` — rebase silverblue-main:43 → :44

**Scope**: bump the inherited base from `silverblue-main:43` to `silverblue-main:44` (and `silverblue-nvidia:43` → `:44`). Routine F-release hygiene — newer kernel, mesa, podman, Qt stack, etc. Verify that the niri + Noctalia + Terra + matugen pipeline builds and boots cleanly on F44. **NOT bundled with niri-shell** — bundling would conflate "niri broke" vs "F44 broke" in the post-rebase failure mode.

**Why deferred**: F44 doesn't unlock anything for niri-shell specifically. Upstream Quickshell landing in f44 main is moot — we ship `noctalia-qs` (the upstream-mandated fork) from Terra regardless of which Quickshell is in Fedora main. Everything else we need (niri, rust-matugen, sddm, kanshi, fcitx5, grim/slurp/wl-clipboard/cliphist, libva-nvidia-driver) is already in f43 main. Hygiene-only.

**Promotion criteria**:
- `niri-shell` shipped and stable (~1 month of daily use without compositor regressions).
- ublue-os has published `silverblue-main:44` and `silverblue-nvidia:44` tags (verify before promoting).
- Terra noctalia-shell, noctalia-qs, ghostty all have current f44 RPMs (verify in `terrapkg/packages` before promoting).

**Risks to flag during /spec-design**:
- NVIDIA: F44 typically ships a newer kernel; verify nvidia-driver akmod has F44 builds in the ublue-os pipeline before flipping the nvidia variant.
- bootupd / kargs.d schema cross-version compatibility (low risk, but verify against any `bootloader-swap` work that may have landed first — interaction order matters).
- If `image-ops` Renovate config landed first, add the F44 tag to the tracked base-image patterns.

### Security hardening (selective, from secureblue)

- Sysctl: `kernel.kptr_restrict`, `kernel.dmesg_restrict`
- Modprobe blacklist for firewire + uncommon filesystems
- **Skip**: USBGuard (too dev-hostile), hardened_malloc (breaks docker/some runtimes)

---

## Explicit non-goals (re-confirmed April 2026 after research; updated 2026-05-02)

- **Nix as user-level package manager** — *added 2026-05-01*. Considered and dropped via `nix-home` → `chezmoi-home` pivot. User-config layer is chezmoi + RPMs. Revisit if upstream resolves all three composefs/SELinux/post-upgrade issues. See `.specs/features/chezmoi-home/context.md` D-01.
- **Flake-based workflow by default** — n/a (nix retired).
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
