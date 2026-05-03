# niri-shell — Decision Context

> Status: **ALL LOCKED 2026-05-02.** Every D-XX has either an explicit user-locked decision, a default-locked recommendation, auto-resolves by way of an upstream lock (D-04 = stock Noctalia resolves D-05/D-06/D-08/D-11/D-16/D-17), or has been retired (D-14, since Noctalia uses noctalia-qs not upstream Quickshell). Three-island aesthetic deferred to `niri-islands` follow-up feature spec (ROADMAP backlog). **Final repo set: Fedora main + Terra (`terra-release`) — no third-party COPRs.** Spec is ready for `/compact` then `/spec-design`.

The spec at `spec.md` references these IDs in its acceptance criteria. Conditional language ("D-XX dependent") was retired during the 2026-05-02 review pass once all decisions locked.

---

## D-01 — Full replacement vs. parallel variant ✅ LOCKED 2026-05-02

**Decision**: **A (full replacement).** `sideral:latest` becomes niri; `sideral-nvidia:latest` becomes niri+nvidia. `os/modules/desktop/` retires; `os/modules/desktop-niri/` replaces it. **No frozen `:gnome-final` preservation tag** (D-15 locked separately) — atomic-purist swap.

Implications:
- 2 ghcr tags instead of 4; CI matrix stays at 2 builds per push.
- The `gnome-extras` backlog item retires entirely.
- The gnome-software prune in `os/lib/build.sh` is **expanded** to also remove: `gdm`, `gnome-shell`, `gnome-session`, `mutter`, `gnome-control-center`, `gnome-settings-daemon`, plus the gnome-shell-extension RPMs (`gnome-shell-extension-appindicator`, `gnome-shell-extension-dash-to-panel`). Each gated on `rpm -q $pkg` so dnf5 remove doesn't fail on already-absent packages.
- D-13 locked: niri ships on both `sideral` (silverblue-main:43 base, no kmod-nvidia) and `sideral-nvidia` (silverblue-nvidia:43 base, with kmod-nvidia) from day 1.

---

## D-02 — Greeter ✅ LOCKED 2026-05-02

**Decision**: **SDDM with the SilentSDDM theme** (https://github.com/uiriansan/SilentSDDM). Qt6-based — runs on the same Qt6 runtime stack that Noctalia/noctalia-qs already pull in via Quickshell. SilentSDDM is a customizable, modern Qt-based SDDM theme that pairs cleanly with Noctalia's matugen-driven Material 3 aesthetic.

Implications:
- `gdm` retires from the image alongside the rest of the GNOME stack.
- `sddm` (Fedora main) installed via `os/modules/desktop-niri/packages.txt`.
- SilentSDDM theme fetched at image build by `os/modules/desktop-niri/sddm-silent-install.sh` (no Fedora RPM or COPR — pin a release tag from `uiriansan/SilentSDDM` and extract to `/usr/share/sddm/themes/silent/`). Same pattern as starship's upstream-binary install. sha256-verify the tarball.
- Default theme set via `/etc/sddm.conf.d/sideral-silent.conf` (`[Theme] Current=silent`) shipped by `sideral-niri-defaults`.
- SilentSDDM has its own theme-config knobs (per its README); sideral's defaults file ships a sane starting set in `/usr/share/sddm/themes/silent/theme.conf` (or wherever SilentSDDM expects user overrides).
- niri session entry shipped at `/usr/share/wayland-sessions/niri.desktop` (`Exec=niri-session`).
- `sideral-niri-defaults.spec` Conflicts: against `gdm`.
- Open question for `/spec-design`: whether SilentSDDM exposes color tokens that matugen can write to (so the greeter palette tracks the desktop's matugen palette), or if it ships its own palette and sideral leaves the default. Not blocking ship; deferred.

---

## D-03 — niri install source ✅ LOCKED 2026-05-02

**Decision**: **Fedora main** (`rpms/niri`). Verified 2026-05-02 in Fedora dist-git: niri is branched on f42, f43, rawhide; current upstream version `niri-26.04` was submitted to bodhi 2026-05-02 by decathorpe (Fabio Valentini). Sideral on `silverblue-main:43` `dnf5 install`s niri directly. No COPR persistent-repo file needed; `rpm-ostree upgrade` pulls niri point releases via standard Fedora updates flow.

**Lock updated 2026-05-02** from earlier "default: yalter/niri COPR" — research had assumed niri was COPR-only; user pushed back ("isnt niri on dnf?"); dist-git lookup confirmed Fedora main.

(Original options surveyed before lock — kept here for reference.)

**Options**:

| Option | Source | Update path | Sideral pattern fit |
|---|---|---|---|
| **A. yalter/niri COPR** | https://copr.fedorainfracloud.org/coprs/yalter/niri/ | `rpm-ostree upgrade` pulls point releases | Same pattern as docker-ce (retired), mise, vscode, kubernetes — persistent `.repo` shipped in sideral-base |
| **B. Build-from-source at image build** | git clone + cargo build | Pinned commit per image; no between-rebuild updates | Same pattern as starship — pinned upstream binary baked into `/usr/bin` |
| **C. Fedora main (if/when available)** | dnf5 install niri | Fedora release cadence | Slow but zero-friction |

**Tradeoffs**:
- niri is a hot-churn project (~2025-2026 active development); point releases land monthly. Option A's between-rebuild update story matters more here than for, say, kubectl.
- Option B's "pinned per image" guarantee is appealing for atomic semantics but means users need to wait for the next sideral rebuild to get a niri patch.
- Option C is unrealistic in the short term — niri is unlikely to be in Fedora main before late 2026.

**Recommendation**: **A (yalter/niri COPR, persistent repo)** — matches sideral's established pattern for fast-moving third-party RPMs.

**Decision**: *unresolved*

---

## D-04 — Shell pick ✅ LOCKED 2026-05-02 (third lock 2026-05-02 — Noctalia)

**Decision**: **Ship stock Noctalia via Terra's `noctalia-shell` RPM** (current 4.7.6, packaged by `terra@willowidk.dev`; spec at github.com/terrapkg/packages/tree/master/anda/desktops/noctalia-shell). Built on `noctalia-qs` (also from Terra), a Quickshell hard-fork that `Conflicts: quickshell, Provides: quickshell`.

**Lock history (three locks across 2026-05-02):**
1. **First lock (early 2026-05-02):** ship stock DMS, git-clone-and-build at pinned SHA. (Original /spec-create discuss decision.)
2. **Second lock (after Terra audit):** ship DMS via Terra's `dank-material-shell` RPM. Drops the Go-toolchain build step; RPM ownership; transitive deps via Requires.
3. **Third lock (this one — after the user asked "could we do niri-islands using noctalia? if so lets swap"):** ship Noctalia via Terra. Reasoning below.

**Why Noctalia over DMS, given that we'd already locked DMS via Terra:**

The deferred `niri-islands` feature replaces the host shell's bar with sideral-authored three-pill QML — but **only the bar**. Notification overlay, launcher, lock, control center, wallpaper all stay from the host shell. Implications:
- The DMS-only "interim win" was its `RunningApps` widget that does spatial-sorted task list via `NiriService.sortWindowsByLayout`. That widget gets thrown away when `niri-islands` ships. So DMS's spatial-sort is interim-only.
- Noctalia's "shell not DE" minimalism is **permanent** — less host-shell chrome to coordinate against during niri-islands development.
- **Repo cleanup is permanent**: noctalia-qs `Conflicts: quickshell, Provides: quickshell`, so we drop the `errornointernet/quickshell` COPR entirely. Final repo set: Fedora main + Terra. No third-party COPRs at all. No F44-rebase cleanup item.
- niri-islands is largely host-shell-independent regardless: written in standard Quickshell QML semantics, vendoring iNiR's `NiriService.qml` (or equivalent) for niri IPC; either DMS or Noctalia can host it as a "swap the bar QML, keep the rest" replacement.

Tradeoffs accepted:
- noctalia-qs is at v0.0.12 (very early version; pinned by single contributor `noctalia-dev`). vs upstream Quickshell which is more mature and recommended by quickshell.org. If noctalia-qs diverges badly from upstream Quickshell semantics during niri-islands development, surface-level workaround: vendor a local Quickshell build instead of using noctalia-qs. Not blocking v1.
- DMS in Terra was more actively maintained (3-day cadence vs Noctalia's 2.5-week). If Terra's noctalia-shell maintenance lags meaningfully, contribute a bump.
- Noctalia's stock bar doesn't ship a spatial-sort widget. NIR-15a is restated in the spec to acknowledge this; spatial-sort approximation deferred entirely to `niri-islands`.

Rationale for picking a Quickshell-based shell at all (carries forward from earlier locks):
- Material 3 styling + matugen integration matches the desktop aesthetic the user wants.
- Quickshell is the only QML/Qt6 framework with first-class niri support among community shells (vs end-4 Hyprland-only, caelestia Hyprland-locked).
- Both DMS and Noctalia natively support niri.

Implications:
- **D-05 (notification daemon), D-06 (app launcher), D-08 (lock+idle), D-11 (wallpaper), D-16 (niri IPC pattern), D-17 (service singletons + Appearance):** all auto-resolve to "Noctalia handles." Specifically: noctalia-qs `Provides: desktop-notification-daemon`.
- **D-14 retires entirely** — no Quickshell COPR needed; noctalia-qs from Terra is the runtime.
- Noctalia's systemd user service is RPM-owned (if upstream ships one); sideral layers a `*.service.d/sideral.conf` drop-in only if needed.
- Three-island aesthetic deferred — promote `niri-islands` to current after ~3 months of daily-driving Noctalia, if the islands still feel load-bearing. Replacement scope: only the bar QML; rest of Noctalia keeps working unchanged.

(Original options surveyed before lock — kept here for reference / future `niri-islands` spec.)

**Research findings** (full notes in this conversation; key cites: [iNiR NiriService.qml](https://github.com/snowarch/iNiR/blob/main/services/NiriService.qml), [DMS NiriService](https://deepwiki.com/snowarch/quickshell-ii-niri/7.1-niriservice-and-window-management), [niri IPC wiki](https://github.com/YaLTeR/niri/wiki/IPC)):

1. **Quickshell ships no `Niri` namespace** — niri integration is hand-rolled via `Quickshell.Io.Socket` + a 2-socket pattern (one in EventStream mode for live state, one per-Action for requests). The community plugin `imiric/qml-niri` exists but production shells skip it and roll their own.
2. **The killer reusable file is iNiR's `NiriService.qml`** — 1376 lines, DeepWiki-indexed, the most thoroughly publicly-documented niri-IPC-to-QML pattern. It maintains the window list, sorts by `output → workspace → column → row`, exposes everything our left island needs.
3. **DMS's `sortWindowsByLayout`** uses niri's `pos_in_scrolling_layout` field directly; it's the same shape iNiR uses but in DMS's Go+QML hybrid. Either source works for the spatial sort.
4. **All five surveyed shells use a single PanelWindow** with three internal `Row` sections — none ship floating islands natively. But Quickshell's `PanelWindow` primitive instantiates trivially three times per screen via a `Repeater` over `Quickshell.screens` — refactor cost only, not from-scratch.
5. **matugen convention**: external process writes `~/.local/state/quickshell/user/generated/colors.json` + `.scss` + Qt `.colors`; QML side wraps a `FileView { watchChanges: true }` in an `Appearance` singleton exposing M3 tokens. Components recolor reactively. Known pitfall: matugen 4.0.0 broke `--dry-run` (DMS #1688) — pin matugen + surface stderr.

**Options** (revised after research):

| Option | Bar QML | Niri IPC | Notif / launcher / lock | What sideral authors |
|---|---|---|---|---|
| **A. Sideral-authored bar; vendor iNiR's NiriService; off-the-shelf rest** | Three independent `PanelWindow`s (sideral) | Vendored `NiriService.qml` (iNiR, pinned SHA) | mako + fuzzel + hyprlock + hypridle | Three island QMLs (~400 LOC) + Appearance singleton + matugen templates |
| **B. Sideral-authored bar; vendor iNiR NiriService + DMS Go IPC bridge; off-the-shelf rest** | Same as A | iNiR NiriService + DMS-style `dmsd`-equivalent in Go for matugen-queue + system D-Bus | Same as A | Three island QMLs + Go daemon + matugen queue + Appearance singleton |
| **C. Fork iNiR; replace its bar with three islands; keep iNiR's launcher/notifications/lock/wallpaper** | Replace iNiR's `BarContent.qml` only | Inherited from iNiR | iNiR-shipped (one styling system) | Three island QMLs replacing one file + ongoing iNiR-upstream tracking |
| **D. Fully sideral-authored Quickshell shell** | Sideral | Sideral (write own NiriService) | Sideral | Everything — including the parts everyone else has solved |

**Tradeoffs**:
- **A** is the smallest sideral surface and the cleanest separation of concerns. Vendor iNiR's NiriService.qml + caelestia's service-singleton pattern (Time/Audio/Battery/Network singletons that are decompositor-agnostic), build three pills against those, leave non-bar concerns to mako/fuzzel/hyprlock — all ~10-year-stable, Fedora-main or one COPR. matugen templates render configs for all three so they share a palette. Visual coherence ~85% (Material 3 islands; mako/fuzzel/hyprlock are themed but not pixel-matched).
- **B** copies DMS's architectural choice — Go for "anything that needs a child_process or D-Bus" (matugen queue, NetworkManager, BlueZ, brightness, polkit), QML for rendering only. Heavier scaffolding but solves real Quickshell limits (QML can't shell out without freezing the render thread). Worth it if we discover we need network/bluez/polkit interactions matugen-templates can't cover.
- **C** sounds attractive ("inherit iNiR's polish, skin our bar") but iNiR's `BarContent.qml` is 800+ lines tightly coupled to its `Looks` token system; replacing one file is misleading — we'd be auditing every iNiR update for breakage in the swap-point. Plus iNiR ships TWO bar families (ii + Waffle), each ~24 panels; we'd inherit both. Not a saving.
- **D** turns sideral into a Quickshell-shell project. Out of scope for a personal-image roadmap.

**Recommendation**: **A (sideral-authored bar; vendor iNiR's NiriService; off-the-shelf rest)** — minimal sideral surface, maximum reuse of the most-documented existing patterns, and the rest of the desktop reaches for the boring sway-ecosystem tools we know how to theme. Promote to **B** only if we discover during `/spec-design` that QML can't drive matugen / NetworkManager / polkit cleanly without a Go bridge.

**Decision**: *unresolved*

---

## D-05 — Notification daemon

**Question**: Which Wayland notification daemon implements the `org.freedesktop.Notifications` D-Bus surface?

**Options**:

| Option | Source | Pairing |
|---|---|---|
| **A. mako** | Fedora main | sway-style, lightweight, matugen-themable via `~/.config/mako/config` |
| **B. swaync** | Fedora main | feature-rich, has its own control-center, matugen-themable via CSS |
| **C. shell-built-in** | DMS / Noctalia QML overlay | only applies if D-04 = B/C |

**Recommendation**: **A (mako)** if D-04 = A. Lightest, fastest, matugen-friendly, ten years of stability. **C** if D-04 = B/C — borrowing the upstream's notif overlay keeps styling consistent.

**Decision**: *unresolved (resolves with D-04)*

---

## D-06 — App launcher

**Question**: Which application launcher binds to `Mod+D`?

**Options**:

| Option | Source | Pairing |
|---|---|---|
| **A. fuzzel** | Fedora main | sway-style, fast, drop-in; matugen template covers `~/.config/fuzzel/fuzzel.ini` |
| **B. walker** | upstream (https://github.com/abenz1267/walker) | newer Rust+Gtk4, modular |
| **C. anyrun** | upstream / COPR | hyprland-community-default; Rust+plugins |
| **D. tofi** | Fedora main | minimalist |
| **E. shell-built-in (DMS or Noctalia)** | n/a | only applies if D-04 = B/C |

**Recommendation**: **A (fuzzel)** if D-04 = A — drop-in, Fedora-main, matugen-friendly. **E** if D-04 = B/C.

**Decision**: *unresolved (resolves with D-04)*

---

## D-07 — Default terminal ✅ LOCKED 2026-05-02 (source re-updated 2026-05-02)

**Decision**: **ghostty** via **Terra** (the `ghostty` package; current 1.3.1 stable; spec at github.com/terrapkg/packages/tree/master/anda/devs/ghostty/stable).

**Lock updated twice on 2026-05-02:**
1. First update: from `pgdev/ghostty` (archived/defunct since 01/2025, "PROJECT ARCHIVED" in COPR description) to `scottames/ghostty` (upstream-recommended at the time).
2. Second update: from `scottames/ghostty` to **Terra**. Terra's ghostty spec verifies the upstream minisign key `RWQlAjJC23149WL2sEpT/l0QKy7hMIFhYdQOFy0Z7z7PbneUgvlsnYcV` from `ghostty-org/ghostty/PACKAGING.md` — stronger trust than scottames's no-spec-level-signature-verify model. Same source Bazzite/Aurora pre-ship. Multi-maintainer + signed builds + public CI.

Implications:
- Bootstrapped via `terra-release` RPM (one shot ships repo file + GPG key + key-trust).
- Terra ships `terra.repo` enabled by default once `terra-release` is installed.
- niri config: `Mod+T → /usr/bin/ghostty`.
- matugen template: `~/.config/ghostty/config` with palette mapped from M3 tokens (background = surface, foreground = on_surface, accent = primary, etc.).
- Bake JetBrains Mono Nerd Font glyphs into the default config so ligatures + powerline glyphs work out of the box.

---

## D-08 — Lock screen + idle handler

**Question**: Lock-on-suspend / lock-on-idle / Mod+L lock — implemented by what?

**Options**:

| Option | Source | Pairing |
|---|---|---|
| **A. hyprlock + hypridle** | `solopasha/hyprland` COPR | hyprland-stack tools; well-themed; widely used in niri community; matugen template covers both configs |
| **B. gtklock + swayidle** | Fedora main | classic sway stack |
| **C. swaylock + swayidle** | Fedora main | classic sway stack, less themable than gtklock |
| **D. shell-built-in (DMS)** | n/a | only applies if D-04 = B |

**Recommendation**: **A (hyprlock + hypridle)** if D-04 = A — most themable + most niri-community-aligned, despite the COPR dependency. **D** if D-04 = B.

**Decision**: *unresolved (resolves with D-04)*

---

## D-09 — Where do niri/Quickshell defaults ship

**Question**: niri and Quickshell read user config from `~/.config/`. To ship sideral defaults, sideral can write into:
- `/etc/skel/.config/<tool>/...` — copied to `~/.config/<tool>/...` only on user creation; pre-existing users don't get updates
- `/etc/xdg/<tool>/...` — system-default config consulted when `~/.config/<tool>/` doesn't exist; updates flow on rebase but user-config silently overrides
- `/usr/share/<tool>/sideral/...` — sideral-namespaced source-of-truth that user config can `include` from
- Both /etc/xdg and /etc/skel — belt-and-suspenders

**Options**:

| Option | Update flow | Override semantics | chezmoi fit |
|---|---|---|---|
| **A. /etc/skel only** | Pre-existing users ignored on rebase | User config wins permanently | chezmoi fully replaces sideral defaults |
| **B. /etc/xdg only** | Updates flow on rebase, but only when user has no override | User config wins; missing keys fall through to xdg | chezmoi can selectively override |
| **C. /etc/xdg + /etc/skel** | First-login users see both; rebases update xdg | Best of both | Most predictable for chezmoi |
| **D. /usr/share + include directive in user config** | Updates flow always; user config can `unset` keys | Cleanest semantically | Requires niri/Quickshell to support an include directive (niri: yes, partial; Quickshell: depends on shell) |

**Tradeoffs**:
- /etc/xdg matches niri's documented system-default convention (niri reads `/etc/xdg/niri/config.kdl` if `~/.config/niri/config.kdl` is missing).
- /etc/skel is what `useradd` consumes — fine for fresh users on a new sideral install but doesn't update existing users on rebase. Not great as a sole source.
- Option D is the cleanest but requires both tools to support config inclusion. niri supports `include` for partial config inclusion; Quickshell shells (DMS/Noctalia) generally don't.

**Recommendation**: **C (xdg + skel)** — gives both first-login population and ongoing rebase updates. chezmoi can override either layer.

**Decision**: *unresolved*

---

## D-10 — matugen install source ✅ LOCKED 2026-05-02 (updated source 2026-05-02)

**Decision**: **Fedora main** via `rust-matugen` package (installs the `matugen` binary to `/usr/bin/matugen`).

**Lock updated 2026-05-02** from earlier "default: solopasha/matugen COPR" after a COPR-trust audit found:
- The `rust-matugen` package is in Fedora main (`packages.fedoraproject.org/pkgs/rust-matugen/`) — verified 2026-05-02.
- `solopasha/matugen` COPR is a reputable-but-personal-testing repo (owner explicitly disclaims his COPRs as "personal repository for testing purpose, which you should not use" in Fedora discussion threads).
- matugen upstream (InioX) does not bless any specific Fedora packaging; the community-canonical COPR for those who do need a COPR is `heus-sueh/packages`, but `rust-matugen` in Fedora main supersedes both.

Sideral on `silverblue-main:43` `dnf5 install rust-matugen` directly. No COPR persistent-repo file. `rpm-ostree upgrade` pulls matugen point releases via standard Fedora updates.

(Original options surveyed before lock — kept here for reference.)

**Options**:

| Option | Source | Update path |
|---|---|---|
| **A. solopasha/matugen COPR** | https://copr.fedorainfracloud.org/coprs/solopasha/matugen/ | rpm-ostree upgrade |
| **B. Build-from-source / cargo binstall** | upstream | Image rebuild only |

**Recommendation**: **A (COPR)** — same pattern as D-03 niri.

**Decision**: *unresolved*

---

## D-11 — Wallpaper backend

**Question**: Who paints the wallpaper on the niri output?

**Options**:

| Option | Source | Capabilities |
|---|---|---|
| **A. swww** | `mat-h/swww` COPR or build-from-source | Animated transitions; lots of options |
| **B. swaybg** | Fedora main | Static; simple; reliable |
| **C. shell-built-in** | DMS or Noctalia handles it | n/a |
| **D. niri-built-in** | not available — niri does not paint wallpapers natively | n/a |

**Recommendation**: **C if D-04=A** (DMS handles wallpaper natively); else **A (swww)** for the transition animations.

**Decision**: *unresolved*

---

## D-12 — Welcome motd niri update

**Question**: How much of the current `/etc/user-motd` survives the niri pivot?

The current motd lists `ujust` recipes (chsh, chezmoi-init, gdrive-setup, tools). All of those still apply — they're shell-level, not desktop-level.

**Options**:
- **A. Append a "niri keybinds" row to the existing motd** — minimal change.
- **B. Rewrite top-to-bottom for the niri context** — flag this is a niri image, lead with the keybinds the user will care about on first login (Mod+D launcher, Mod+T terminal, Mod+L lock, `ujust theme <wallpaper>`).

**Recommendation**: **B** — the sideral identity changes substantially with niri; the motd should reflect that.

**Decision**: *unresolved*

---

## D-13 — niri+NVIDIA parity ✅ LOCKED 2026-05-02 (hardening expanded 2026-05-02)

**Decision**: **Ship niri on both `sideral` and `sideral-nvidia` variants from day 1.** No frozen GNOME-NVIDIA fallback.

**Hardening pulled from bluefin / bazzite / niri wiki research (2026-05-02)** — every documented bug-prevention knob is baked in defensively. See spec.md NIR-33 through NIR-33h for the full list. Summary:

- **kargs** (`/usr/lib/bootc/kargs.d/00-nvidia.toml`): `nvidia-drm.modeset=1` (kept), `nvidia-drm.fbdev=1` (added — kernel ≥6.11 TTY black-screen prevention), `rd.driver.blacklist=nouveau`, `modprobe.blacklist=nouveau` (initramfs nouveau blacklist), `initcall_blacklist=simpledrm_platform_driver_init` (simpledrm/nvidia framebuffer race fix). Source: bluefin `build_files/base/03-install-kernel-akmods.sh`.
- **modprobe.d** (NEW `/usr/lib/modprobe.d/sideral-nvidia.conf`): `NVreg_PreserveVideoMemoryAllocations=1`, `NVreg_TemporaryFilePath=/var/tmp`, `NVreg_EnableGpuFirmware=1`, `NVreg_DynamicPowerManagement=0x02`. Source: NVIDIA driver README + bazzite Containerfile (path under `/usr/lib/modprobe.d`, not `/etc/`).
- **NVIDIA app profile** (NEW `/usr/share/nvidia/nvidia-application-profiles-rc.d/50-niri.json`): `GLVidHeapReuseRatio=0` for `procname=niri` — prevents 1 GiB VRAM pin (default) vs ~100 MiB. Source: niri wiki `Nvidia.md` citing NVIDIA/egl-wayland#126.
- **niri config** (in nvidia-only): `debug { disable-cursor-plane }` block — cursor-stuttering-with-VRR-on-NVIDIA fix per niri-wm/niri#3095.
- **environment.d** (NEW `/usr/lib/environment.d/90-sideral-niri-nvidia.conf`): `__GL_GSYNC_ALLOWED=1`, `__GL_VRR_ALLOWED=1`, `LIBVA_DRIVER_NAME=nvidia`, `NVD_BACKEND=direct`, `MOZ_DISABLE_RDD_SANDBOX=1`. Source: bazzite + nvidia-vaapi-driver README.
- **VAAPI**: `libva-nvidia-driver` + `libva-utils` from Fedora main on the nvidia variant.
- **GNOME-only retired**: `os/modules/nvidia/dconf/50-sideral-nvidia` (mutter `kms-modifiers=true`) is **deleted** — niri's smithay backend handles modifiers natively.
- **systemd**: `nvidia-{powerd,suspend,resume,hibernate,suspend-then-hibernate}.service` are auto-enabled by the `nvidia-driver` RPM presets in silverblue-nvidia:43; verify-only, no action needed.

This brings the nvidia variant up to bluefin/bazzite parity for known niri+nvidia bug-prevention as of mid-2026.

---

## D-14 — Quickshell install source ✅ RETIRED 2026-05-02

**Decision**: **Retired with the D-04 third lock (Noctalia).** Sideral no longer ships upstream Quickshell. Noctalia uses `noctalia-qs` — a Quickshell hard-fork from Terra (`Conflicts: quickshell, Provides: quickshell`) — as its Quickshell runtime. The `errornointernet/quickshell` COPR persistent-repo file is not shipped.

The earlier "auto-retire on F44 rebase" cleanup item also retires (no COPR file to remove). The roadmap entry `quickshell-fedora-main` is closed without action.

**If `niri-islands` development surfaces noctalia-qs API divergence from upstream Quickshell:**
- Option A: vendor an upstream Quickshell build alongside noctalia-qs (would require resolving the `Conflicts:` declaration — non-trivial).
- Option B: write niri-islands QML against noctalia-qs's API surface specifically.
- Option C: revisit the shell pick.
Tracked as an open concern for `niri-islands` /spec-design when that feature promotes; not blocking v1.

(Original options surveyed before lock — kept here for reference.)

**Options**:

| Option | Source | Notes |
|---|---|---|
| **A. errornointernet/quickshell COPR** | https://copr.fedorainfracloud.org/coprs/errornointernet/quickshell/ | Persistent repo pattern |
| **B. Build-from-source at image build** | git clone + qmake/cmake + Qt6 build deps | Pinned commit; build deps removed in same RUN layer |
| **C. Flatpak** | not available — Quickshell isn't on Flathub | n/a |

**Recommendation**: **A (COPR)** if it's reliably packaged; **B (build-from-source)** as fallback. Quickshell is API-volatile enough that a per-image pin (B) reduces user-side breakage between sideral rebuilds.

**Decision**: *unresolved*

---

## D-15 — Migration UX ✅ LOCKED 2026-05-02

**Decision**: **Silent swap on `:latest`. No GNOME image shipped at all** — no `:gnome-final-YYYYMMDD` preservation tag, no `:v2` opt-in tag. Atomic-purist take: `:latest` is the canonical tag; the niri+Noctalia image is what ships there. Users who want to roll back use `rpm-ostree rollback` (single-deployment fallback to the previous deployment) or fork the repo at the pre-niri SHA and rebuild from their fork.

Operational steps before the swap:
1. Add a "niri migration coming" note to `/etc/user-motd` (one week before the swap commit lands on main).
2. Update README's "Quick start" + "What's in the image" sections to reflect niri+Noctalia.
3. Land the niri-shell PR.
4. CI runs the `build-sideral` matrix — both `sideral:latest` and `sideral-nvidia:latest` flip atomically.
5. ublue-os-update-services on existing user systems pulls the new image on its next nightly run.

Rationale: this is a personal image with one user. The user explicitly asked to drop GNOME entirely ("we wont ship any gnome, only niri (base) and niri (nvidia)"). Tag preservation has zero ongoing maintenance value when nobody else depends on the GNOME tag.

---

## D-16 — niri IPC consumption pattern (left island data source)

**Question**: How does the left island read niri's window state for the spatial task list?

**Research finding (2026-05-02)**: niri's `$NIRI_SOCKET` accepts the literal string `"EventStream"` to upgrade a connection from request/response to a persistent push stream of newline-delimited JSON deltas. niri sends a complete initial snapshot then incremental events — explicitly designed so consumers cannot desync. Schema is stable for JSON output (existing names retained, new fields additive).

**Production pattern (DMS, iNiR)**: TWO sockets — one held open in EventStream mode for state, one short-lived per-Action request. Quickshell's `Quickshell.Io.Socket` + `SplitParser` (newline-delimited) consume this directly. Event batching (~50ms) coalesces rapid window-move events for smooth UI updates.

**Options**:

| Option | Implementation | Latency | Source pattern |
|---|---|---|---|
| **A. Poll `niri msg --json windows` from QML** | Shell-out via `Process` | 100–500ms | None of the surveyed shells use this |
| **B. Two-socket EventStream pattern** | `Quickshell.Io.Socket` + `SplitParser`, vendored from iNiR's `NiriService.qml` | Sub-50ms | DMS, iNiR (battle-tested) |
| **C. imiric/qml-niri C++ plugin** | Use `Niri` QML object | Sub-50ms | imiric/quickshell-niri example only |

**Recommendation**: **B (two-socket EventStream, vendored from iNiR's NiriService)** — battle-tested production pattern in two of the most active niri Quickshell shells; no extra C++ build dep; documented at DeepWiki for reference reading.

**Decision**: *unresolved*

---

## D-17 — Service singleton pattern + Appearance/matugen wiring

**Question**: How are decompositor-agnostic services (Time, Audio, Battery, Network, Brightness) and the Material 3 palette exposed to the three islands?

**Research finding**: caelestia and end-4 both use the singleton-service pattern — each `services/Foo.qml` is `pragma Singleton` + `Singleton {}`, exposing properties via `Quickshell.Services.{Pipewire,UPower,Mpris,SystemTray,...}` or DBus wrappers. Components access them globally as `Audio.volume`, `Time.date`, etc. — no prop drilling. matugen output is consumed by an `Appearance` singleton wrapping `FileView { path: "~/.local/state/quickshell/user/generated/colors.json"; watchChanges: true; onFileChanged: reload() }` exposing Material 3 tokens as bindable QML properties.

**Options**:

| Option | What sideral ships |
|---|---|
| **A. Vendor caelestia's services + author Appearance ourselves** | services/Time.qml, Audio.qml, Battery.qml, Network.qml, Brightness.qml from caelestia (decompositor-agnostic); plus sideral-authored Appearance.qml + matugen templates |
| **B. Roll our own services** | Sideral writes everything from scratch using Quickshell.Services.* directly |
| **C. Vendor iNiR's MaterialThemeLoader + caelestia's services** | Same as A but reuse iNiR's matugen wiring instead of rewriting |

**Recommendation**: **C** — caelestia's services for everything decompositor-agnostic (the patterns are ~50 LOC each, well-tested), iNiR's MaterialThemeLoader for matugen wiring (reuses the proven file-watcher pattern). matugen templates are sideral-authored to render against our three-island palette taxonomy.

**Decision**: *unresolved*

---

## Summary table

| ID | One-line | Recommendation (provisional) | Blocks |
|----|----------|------------------------------|--------|
| D-01 | Full replace vs parallel variant | ✅ **A (full replace)** locked 2026-05-02 | — |
| D-02 | Greeter | ✅ Locked: SDDM + Pixie theme | — |
| D-03 | niri source | ✅ Locked: Fedora main (`rpms/niri`; no COPR) | NIR-02 |
| D-04 | Shell pick | ✅ Locked (third update): **Noctalia via Terra's `noctalia-shell` RPM** (drops the upstream Quickshell COPR entirely; cleaner base for the deferred `niri-islands` bar replacement) | — |
| D-05 | Notif daemon | ✅ Auto-resolved: Noctalia handles | — |
| D-06 | App launcher | ✅ Auto-resolved: Noctalia handles | — |
| D-07 | Default terminal | ✅ Locked: ghostty via **Terra** (verifies upstream minisign signature; superseded scottames/ghostty after Terra audit) | — |
| D-08 | Lock + idle | ✅ Auto-resolved: Noctalia handles | — |
| D-09 | Defaults location | /etc/xdg + /etc/skel | NIR-03 |
| D-10 | matugen source | ✅ Locked: Fedora main `rust-matugen` (no COPR; solopasha COPR retired as personal/testing) | NIR-16 |
| D-11 | Wallpaper backend | ✅ Auto-resolved: Noctalia handles | — |
| D-12 | Welcome motd | ✅ Locked: keep motd structure; add one row pointing at new `ujust niri` cheatsheet recipe | NIR-23 |
| D-13 | nvidia parity | ✅ Locked: niri on both variants; no frozen GNOME-NVIDIA fallback | — |
| D-14 | Quickshell source | ✅ **RETIRED** with D-04 Noctalia swap (noctalia-qs from Terra is the runtime; no upstream Quickshell shipped) | — |
| D-15 | Migration UX | ✅ Locked: silent swap, no preservation tag | — |
| D-16 | niri IPC pattern | ✅ Auto-resolved: Noctalia handles via its internal NiriService | — |
| D-17 | Service singletons + Appearance | ✅ Auto-resolved: Noctalia handles | — |
