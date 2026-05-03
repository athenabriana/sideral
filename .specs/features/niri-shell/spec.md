# niri-shell Specification

> Status: **DRAFT — all gray areas locked 2026-05-02.** D-01 (full replacement), D-02 (SDDM + SilentSDDM), **D-04 (Noctalia via Terra's `noctalia-shell` RPM)**, **D-07 (ghostty via Terra)**, D-12 (motd structure preserved + new `ujust niri` cheatsheet), D-13 (niri on both variants + bluefin/bazzite-grade NVIDIA hardening), D-15 (silent swap, no preservation tag) all locked. D-03 (niri) and D-10 (matugen) lock to **Fedora main**; **D-14 retires** (Noctalia uses `noctalia-qs` — the Quickshell fork that `Conflicts: quickshell, Provides: quickshell` — so no Quickshell COPR needed); D-09 defaults to /etc/xdg + /etc/skel. D-05/D-06/D-08/D-11/D-16/D-17 auto-resolve to "Noctalia handles it." **Final repo set: Fedora main + Terra (`terra-release`) — no third-party COPRs.** Three-island aesthetic deferred to follow-up `niri-islands` feature spec (ROADMAP backlog) — Noctalia's minimalist shell architecture chosen partly because it's a cleaner base to bar-replace when `niri-islands` ships. **Ready for `/compact` then `/spec-design`.**

## Problem Statement

sideral currently runs GNOME + tiling-shell on top of `silverblue-main:43`. The tiling-shell extension is a band-aid over a Mutter session that fundamentally wants to float windows; the result is a tiling experience that's "good enough" but always ~80% of what a native scrollable-tiling compositor delivers. The user has a documented preference for tiling workflows (the original `sideral` lineage forked from a Hyprland setup before the GNOME pivot) and is now circling back, this time looking at niri — YaLTeR's Rust-based scrollable-tiling Wayland compositor inspired by PaperWM.

niri itself is **only a compositor**: it has no bar, no notification daemon, no launcher, no lock screen, no idle handler, no wallpaper, no screenshot UI, no greeter, no configuration GUI, no IME wiring, and no multi-monitor profile manager. Standing up a daily-driver niri desktop means assembling ~10 cooperating Wayland tools and then theming them coherently. **Noctalia** (https://github.com/noctalia-dev/noctalia-shell) — a minimal Quickshell-based shell native to niri/hyprland/sway/scroll/labwc/MangoWC — bundles the missing pieces (bar, notifications, launcher, control center, lock, idle, wallpaper) with matugen-driven dynamic theming from wallpaper. Its "shell, not DE" philosophy makes it a clean base to bar-replace later when the deferred `niri-islands` feature ships. (DMS, end-4/illogical-impulse, and snowarch/iNiR were surveyed; rationale lives in `context.md` D-04.)

This feature delivers a sideral image where the user logs in, gets a fully-configured niri session with one of those shells running, and can re-theme the whole desktop by changing a wallpaper — all without composing the stack from scratch. Sideral's existing surfaces (`chezmoi-cli-tools` Requires graph, three-shell parity, ujust 60-custom slot, `/etc/user-motd` welcome banner, `rclone-gdrive.service` user unit, NVIDIA variant) carry over identically; the desktop layer underneath is the only thing that changes.

**D-01 + D-13 + D-15 locked: full GNOME replacement on both variants, no preservation tag.** `sideral:latest` becomes niri+Noctalia on `silverblue-main:43`; `sideral-nvidia:latest` becomes niri+Noctalia on `silverblue-nvidia:43`. **No GNOME image ships at all**, including no frozen `:gnome-final-YYYYMMDD` tag — atomic-purist migration. Users who want to roll back use `rpm-ostree rollback` (single-deployment fallback) or fork the repo at the pre-niri SHA. `os/modules/desktop/` retires; `os/modules/desktop-niri/` replaces it.

**D-04 is locked: ship stock Noctalia via Terra's `noctalia-shell` RPM** (current 4.7.6, packaged by `terra@willowidk.dev`; spec at github.com/terrapkg/packages/tree/master/anda/desktops/noctalia-shell). Noctalia is a Quickshell-based shell native to niri/hyprland/sway/scroll/labwc/MangoWC; minimal, "shell not DE" philosophy. Handles bar, notification overlay, app launcher, lock screen, control center, idle, and wallpaper. Built on `noctalia-qs` (https://github.com/noctalia-dev/noctalia-qs), a Quickshell hard-fork by the same upstream that `Conflicts: quickshell, Provides: quickshell` — so we cannot mix it with upstream Quickshell, and don't need to (Noctalia is the only consumer of the Quickshell runtime in this image).

**Three-island aesthetic — deferred.** The Apple-Dynamic-Island-style three-pill bar (left = niri-IPC-driven spatial task list, center = clock, right = tray + system) is moved to a separate follow-up feature: **`niri-islands`** (backlog entry in `.specs/project/ROADMAP.md`). Promote that feature to current after the user has lived with Noctalia for ~3 months and the islands aesthetic still feels load-bearing. **Noctalia chosen over DMS partly because its minimalist shell architecture is a cleaner base to bar-replace** — when `niri-islands` ships, sideral replaces only Noctalia's bar QML; the rest of Noctalia (notifications, launcher, lock, control center, wallpaper) keeps working unchanged. DMS's denser feature set would have produced a v1 win on the spatial-sort `RunningApps` widget but no permanent post-`niri-islands` win since the bar is replaced regardless.

## Goals

- [ ] niri runs as the Wayland compositor on `sideral:latest` (silverblue-main:43) and `sideral-nvidia:latest` (silverblue-nvidia:43), fully wired (SDDM+SilentSDDM → niri session → Noctalia bar/notifications/launcher/lock/idle/wallpaper/control-center stack + grim/slurp/wl-clipboard for screenshots + cliphist for clipboard history + fcitx5 IME + kanshi multi-monitor) on first login with **zero user configuration**.
- [ ] Noctalia is system-installed via Terra's `noctalia-shell` RPM. The QML files install to `/etc/xdg/quickshell/noctalia-shell/` (per noctalia-shell.spec). Noctalia's bar, notification overlay, launcher, lock screen, idle handler, control center, and wallpaper all render at session start. Quickshell runtime is `noctalia-qs` (Quickshell fork at v0.0.12, also from Terra; the only Quickshell-runtime consumer in the image).
- [ ] SDDM is the active display manager. SilentSDDM theme is fetched + sha256-verified from `uiriansan/SilentSDDM` upstream releases at image build, extracted to `/usr/share/sddm/themes/silent/`. `gdm` is removed from the inherited base.
- [ ] ghostty is the default terminal (via Terra's `ghostty` package; spec verifies upstream's minisign signature). niri config binds `Mod+T → /usr/bin/ghostty`.
- [ ] Terra repository is bootstrapped at image build via `terra-release` RPM (ships `/etc/yum.repos.d/terra.repo` + `/etc/pki/rpm-gpg/RPM-GPG-KEY-terra`).
- [ ] matugen is shipped + wired so the user can run a single `ujust theme <wallpaper>` (or use Noctalia's built-in wallpaper picker) and the Noctalia bar/launcher/notifications, the ghostty palette, and the helix editor theme all re-render to a Material 3 palette derived from that image.
- [ ] All `sideral-cli-tools` Requires graph contents stay present and work the same — chezmoi, mise, atuin, fzf, bat, eza, ripgrep, zoxide, gh, git-lfs, gcc/make/cmake, helix, fish, zsh, rclone, code, starship.
- [ ] Three-shell parity is preserved: bash + fish + zsh init scripts under `/etc/profile.d/`, `/etc/fish/conf.d/`, `/etc/zsh/`. `ujust chsh` still works.
- [ ] ujust extension slot keeps the existing recipes (chsh, chezmoi-init, gdrive-setup, gdrive-remove, tools, update) and gains two new ones: `theme <wallpaper>` and `niri` (cheatsheet).
- [ ] `/etc/user-motd` keeps existing structure; gains exactly one new row pointing at `ujust niri`.
- [ ] The image still survives `bootc container lint`, builds in <12 min on CI, and rebases atomically from the current GNOME-flavored sideral.
- [ ] NVIDIA variant ships niri+Noctalia identically. `nvidia-drm.modeset=1` karg already lives in `os/modules/nvidia/kargs.d/00-nvidia.toml` and carries over. The mutter-specific `os/modules/nvidia/dconf/50-sideral-nvidia` (kms-modifiers gsetting) retires — niri's smithay backend handles modifiers natively.
- [ ] Existing chezmoi-driven user dotfile flow is unaffected. Sideral's niri-shell defaults ship at both `/etc/xdg/` (system-default fallback) and `/etc/skel/.config/` (per-user seed) per locked D-09; chezmoi templates can override either layer per-user.

## Out of Scope

| Feature | Reason |
|---|---|
| Migrating existing GNOME extensions to niri | Different paradigm; niri has no extension API. tiling-shell, dash-to-panel, appindicator, rounded-window-corners are all GNOME-specific and will not be carried over. Tray comes from Noctalia; tiling/scrolling is native to niri; rounded corners are a niri-config knob. |
| Hyprland as a fallback compositor | This feature commits to niri. Users wanting hyprland fork. |
| KDE / Sway / River variants | Same — niri-only. |
| Sideral-authored Quickshell QML in v1 | Reversed back 2026-05-02 — D-04 locked as ship stock Noctalia (third lock; was DMS in earlier locks). Three-island aesthetic deferred to a future `niri-islands` feature spec. |
| Forking Noctalia upstream | Ship stock Noctalia via Terra's `noctalia-shell` RPM (which packages upstream's signed release tarball without patches). If Noctalia upstream blocks something we need, file an issue; don't fork. |
| Replacing matugen with a hand-rolled palette generator | matugen is the canonical Material 3 generator and Noctalia integrates it via its `Recommends:` graph. |
| GNOME parallel variant on `sideral:latest` | D-01 locked as full replacement. |
| nvidia-Wayland regressions specific to niri | D-13 locked: niri ships on the nvidia variant from day 1. Document any niri+nvidia quirks (cursor lag on legacy KMS, smithay backend selection) in `os/modules/desktop-niri/README.md` with workarounds; revisit at first verified regression. No GNOME-NVIDIA fallback. |
| Remote desktop / RDP / xrdp | Out of scope; no current sideral story for it. |
| Touch-screen / tablet gestures | Out of scope — desktop-class workflow only. |
| Per-monitor fractional scaling beyond what niri ships natively | niri's stock behavior is the contract. |

## User Stories

> P-tier indicates implementation priority within this feature. P1 must work for the feature to ship; P3 may slip to a follow-up.

### P1: niri session boots ⭐ MVP

**Story**: User rebases their atomic Fedora install to `ghcr.io/<owner>/sideral[-niri][-nvidia]:latest`, reboots, picks the niri session at the greeter, logs in, and lands in a working niri compositor with at least: a status bar, a clock, a working keybind to launch a terminal, a working keybind to launch the application launcher, and a wallpaper.

**Acceptance**:
1. **NIR-01** — SDDM is the active display manager (`systemctl is-enabled sddm.service` returns `enabled` after rebase). Greeter renders the SilentSDDM theme on first boot. The niri session entry at `/usr/share/wayland-sessions/niri.desktop` (`Exec=niri-session`) appears in the SDDM session picker and starts cleanly when selected.
2. **NIR-02** — niri binary is on `$PATH` at `/usr/bin/niri`, sourced from **Fedora main** (`rpms/niri`, in f43; verified 2026-05-02). Shipped via `os/modules/desktop-niri/packages.txt`. `rpm-ostree upgrade` pulls Fedora-main point releases (current: `niri-26.04`).
3. **NIR-03** — Default `config.kdl` ships at both `/etc/xdg/niri/config.kdl` (system-default fallback that niri reads when no user config exists) AND `/etc/skel/.config/niri/config.kdl` (per-user seed populated on user creation). Locked D-09: both layers ship; chezmoi templates can override either per-user.
4. **NIR-04** — niri-session bootstraps systemd's `graphical-session.target` per niri upstream's documented systemd integration. Socket-activated user services that depend on `graphical-session.target` (Noctalia, kanshi, fcitx5) come up correctly.
5. **NIR-05** — Noctalia launches at session start. niri config spawns Quickshell pointing at Noctalia's QML at `/etc/xdg/quickshell/noctalia-shell/` (the path Terra's `noctalia-shell` spec installs to). noctalia-qs (Quickshell runtime, also Terra-shipped) is the binary that loads it.
6. **NIR-06** — Wallpaper renders from a system-default sideral wallpaper at first boot via Noctalia's built-in wallpaper backend. User can swap via the theming pipeline (NIR-18) or Noctalia's wallpaper picker.
7. **NIR-07** — ghostty binary on `$PATH` at `/usr/bin/ghostty`, sourced from **Terra** (the `ghostty` package; spec verifies upstream's minisign key `RWQlAjJC23149WL2sEpT/l0QKy7hMIFhYdQOFy0Z7z7PbneUgvlsnYcV` from `ghostty-org/ghostty/PACKAGING.md`). niri config binds `Mod+T → /usr/bin/ghostty`. ghostty launches in <300ms cold.
8. **NIR-08** — `bootc container lint` passes for both `sideral` and `sideral-nvidia` variants. Image build completes in <12 min on the CI matrix.

### P1: Out-of-the-box Noctalia shell experience ⭐ MVP

**Story**: A user who has never seen niri logs in and sees Noctalia's bar with clock, app indicator, system tray, audio, network, and battery; opening the launcher, seeing notifications, and locking the screen each have discoverable keybinds; a wallpaper is set; nothing requires editing a config file to discover.

**Acceptance**:
1. **NIR-09** — Noctalia's bar renders at session start on every output. Includes clock, system tray, audio (PipeWire), network (NetworkManager), and on laptops, battery.
2. **NIR-10** — System tray works for both Wayland-native (KStatusNotifierItem) and XWayland legacy apps (libappindicator → SNI bridge).
3. **NIR-11** — Noctalia's notification overlay is active at session start (test: `notify-send "hello"` renders an overlay). noctalia-qs `Provides: desktop-notification-daemon` so this is the system D-Bus notification daemon.
4. **NIR-12** — Noctalia's app launcher binding (default per Noctalia docs, customizable via niri config bind) opens the launcher. Apps from flatpak + RPM both appear.
5. **NIR-13** — Noctalia's lock screen + idle handler are wired. `Mod+L` triggers immediate lock; idle timeout triggers automatic lock; `loginctl suspend` triggers lock-on-resume.
6. **NIR-14** — Multi-monitor: kanshi runs as a user-systemd-unit and applies any user-configured profile from `~/.config/kanshi/config`. niri handles hot-plug correctly (compositor concern). Noctalia bar instantiates per output.
7. **NIR-15** — Audio: PipeWire up (inherited), volume keys mapped in niri config (`XF86AudioRaiseVolume` etc.), Noctalia audio widget reflects state in real time.
8. **NIR-15a** — Spatial-sorted task list is **NOT shipped in v1**. Noctalia's stock bar shows a workspace + window indicator without column-position sorting. This widget is what `niri-islands` will replace; the spatial-sort approximation is deferred to that follow-up feature. (DMS's NiriService.sortWindowsByLayout was the only existing implementation; chose Noctalia for cleaner v1→niri-islands transition over the interim spatial-sort win.)
9. **NIR-15b** — Wallpaper is set on every output at session start using Noctalia's built-in wallpaper backend.
10. **NIR-15c** — Screenshot capture is wired. niri config binds `Print → grim -g "$(slurp)" - | wl-copy` (region) and `Shift+Print → grim - | wl-copy` (full screen). `grim`, `slurp`, `wl-clipboard` are Fedora main and ship in `os/modules/desktop-niri/packages.txt`. (Whether Noctalia surfaces a screenshot button in its control center is a v2 concern.)
11. **NIR-15d** — Clipboard history via `cliphist` (Fedora main; also recommended by `noctalia-shell` spec) wired as a niri spawn-rule listening to `wl-paste --watch cliphist store`. Optional binding `Mod+V → cliphist list | fuzzel …` deferred to user customization.
12. **NIR-15e** — IME: `fcitx5` + `fcitx5-configtool` (Fedora main) installed; spawned in the niri config as `spawn-at-startup "fcitx5"`. `XMODIFIERS=@im=fcitx`, `GTK_IM_MODULE=fcitx`, `QT_IM_MODULE=fcitx` exported via `/etc/profile.d/sideral-niri-ime.sh` shipped by `sideral-niri-defaults`. Verifiable via `fcitx5-diagnose` post-rebase.

### P1: matugen wallpaper-to-theme pipeline ⭐ MVP

**Story**: User runs `ujust theme ~/Pictures/wallpaper.jpg`. The wallpaper changes, the bar's accent color shifts to match, the launcher recolors, the notifications recolor, and the terminal palette updates. No reboot, no compositor restart.

**Acceptance**:
1. **NIR-16** — matugen binary on `$PATH` at `/usr/bin/matugen`, sourced from **Fedora main** (`rust-matugen` package; verified 2026-05-02 in packages.fedoraproject.org). Shipped via `os/modules/desktop-niri/packages.txt`. No COPR.
2. **NIR-17** — Sideral ships matugen templates at both `/etc/xdg/matugen/templates/` and `/etc/skel/.config/matugen/templates/` (D-09 dual-layer) for: Noctalia's color/theme file (path per Noctalia upstream contract — typically `~/.config/noctalia/colors.json` or similar; verify against noctalia-shell upstream README during `/spec-design`), ghostty (`~/.config/ghostty/config` palette stanza), and helix (`~/.config/helix/themes/sideral.toml`). Notifications/launcher/lock are themed by Noctalia's matugen integration; sideral does NOT ship templates for mako/fuzzel/swaync — they aren't installed (Noctalia replaces them).
3. **NIR-18** — A `ujust theme <path-to-image>` recipe runs matugen, writes outputs to the templated paths, signals each component to reload (Noctalia picks up its color file via Quickshell's `FileView { watchChanges: true }`; ghostty reloads on SIGUSR1; helix on next-launch — explicit reload via `ujust theme` calls `pkill -USR1 ghostty` after matugen succeeds), and updates the wallpaper via Noctalia's wallpaper backend.
4. **NIR-19** — Theming changes are persistent across logout/login.

### P2: Sideral surfaces preserved

**Story**: Everything the GNOME sideral image gave a user — chezmoi, mise, multi-shell, ujust recipes, motd, gdrive mount, podman/k8s — works identically on niri.

**Acceptance**:
1. **NIR-20** — `sideral-cli-tools` Requires graph is unchanged from the GNOME image. All listed binaries are on `$PATH` after rebase.
2. **NIR-21** — `/etc/profile.d/sideral-cli-init.sh` + `/etc/fish/conf.d/sideral-cli-init.fish` + `/etc/zsh/sideral-cli-init.zsh` are unchanged. The Ctrl+P / Alt+S / Ctrl+G keybinds work in any terminal launched in the niri session.
3. **NIR-22** — `ujust chsh [bash|fish|zsh]` still switches login shell. `ujust chezmoi-init <repo>` still works. `ujust gdrive-setup` / `ujust gdrive-remove` still work.
4. **NIR-22a** — New `ujust niri` recipe (in `60-custom.just`) prints a behavior cheatsheet for the niri+Noctalia desktop. Modeled on the existing `ujust tools` shape (libformatting.sh, OSC-8 Urllinks, B/D/R styling). Covers default keybinds (Mod+D launcher, Mod+T ghostty, Mod+L lock, Mod+Q close, Mod+Left/Right scroll-axis navigation, Mod+Shift+Left/Right move-column, workspace switching), `ujust theme <wallpaper>`, and chezmoi override path for niri config.
5. **NIR-23** — `/etc/user-motd` keeps its existing structure (chsh / chezmoi-init / gdrive-setup / tools / update rows) and gains exactly one new row pointing at `ujust niri`. Still shows on every interactive login; per-user opt-out via `~/.config/no-show-user-motd` still works.
6. **NIR-24** — `rclone-gdrive.service` (systemd user unit) still mounts `~/gdrive` and is enabled by `ujust gdrive-setup` the same way.
7. **NIR-25** — Rootless podman + podman-docker shim + podman-compose still work. `systemctl --user is-active podman.socket` reports active. Podman Desktop flatpak still works (it's an Electron app — runs fine under XWayland or natively where the upstream supports Wayland).
8. **NIR-26** — Kubernetes module is unaffected (kubectl/kind/helm + sideral-kind-podman.sh env vars).
9. **NIR-27** — chezmoi user-config flow is unchanged: `chezmoi init --apply <repo>` clones to `~/.local/share/chezmoi/` and renders templates. Sideral's niri-shell defaults (`/etc/xdg/...` and `/etc/skel/.config/...`) are seed values — chezmoi templates can replace them per-user.

### P2: Theming the rest of the stack

**Story**: Beyond the bar/launcher/notifications, the user wants the terminal, helix, and Zen Browser to also pick up the matugen palette so the desktop looks coherent.

**Acceptance**:
1. **NIR-28** — Default helix theme is `sideral` (a matugen-rendered theme written to `~/.config/helix/themes/sideral.toml` by `ujust theme`). On first boot before any `ujust theme` invocation, `~/.config/helix/themes/sideral.toml` is seeded from `/etc/skel/...` with default-wallpaper-derived colors. matugen template ships at both `/etc/xdg/matugen/templates/helix.toml` and `/etc/skel/.config/matugen/templates/helix.toml`.
2. **NIR-29** — ghostty palette follows matugen output. matugen template at both /etc/xdg and /etc/skel renders the color stanza into `~/.config/ghostty/config`. Reload signal: `pkill -USR1 ghostty` (issued by `ujust theme` post-matugen).
3. **NIR-30** — VS Code: a sideral-themed VS Code extension or settings.json hint is NOT shipped (out of scope; user picks any VS Code theme via marketplace).
4. **NIR-31** — Zen Browser: a system theme override is NOT shipped (Zen handles its own theming).

### P2: NVIDIA parity

**Story**: NVIDIA-laptop user gets a niri+Noctalia session that's at parity with the open-source-GPU build for desktop workflows. Strictly-equivalent gaming/VR/DRM-leases parity vs. GNOME+Mutter is **not** promised — niri+nvidia is rougher for those specific edge cases as of mid-2026 — but every documented bug-prevention knob in the bluefin/bazzite/niri-wiki playbooks is baked in defensively.

**Acceptance**:
1. **NIR-32** — `sideral-nvidia:latest` (silverblue-nvidia:43 base) ships niri+Noctalia identically to `sideral:latest`. Both built in the same CI matrix.
2. **NIR-33** — `os/modules/nvidia/kargs.d/00-nvidia.toml` ships the bluefin-equivalent karg set (kargs are early-boot DRM/fbdev flags only — module options live in modprobe.d per NIR-33b):
   ```toml
   kargs = [
     "rd.driver.blacklist=nouveau",
     "modprobe.blacklist=nouveau",
     "nvidia-drm.modeset=1",
     "nvidia-drm.fbdev=1",
     "initcall_blacklist=simpledrm_platform_driver_init",
   ]
   ```
   - `rd.driver.blacklist=nouveau` + `modprobe.blacklist=nouveau` — prevent nouveau load in initramfs (race with nvidia.ko bind). Source: bluefin `build_files/base/03-install-kernel-akmods.sh`.
   - `nvidia-drm.modeset=1` — required for Wayland DRM/KMS path (already shipped pre-niri).
   - `nvidia-drm.fbdev=1` — fbdev emulation, required on kernel ≥6.11 to avoid TTY black-screens; default since driver 570 but explicit is safer.
   - `initcall_blacklist=simpledrm_platform_driver_init` — stops simpledrm grabbing the framebuffer before nvidia.ko binds (root-cause of "boots to black screen on first display").
3. **NIR-33a** — `os/modules/nvidia/dconf/50-sideral-nvidia` (mutter `kms-modifiers=true` gsetting) is **deleted** alongside the rest of the GNOME stack. **This is not a regression** — niri's smithay backend handles modifiers natively; the gsetting was Mutter-only and has no equivalent in niri. `os/modules/nvidia/apply.sh` is updated to drop the `install` line for that file.
4. **NIR-33b** — New `/usr/lib/modprobe.d/sideral-nvidia.conf` ships under sideral-niri-defaults (`/usr/lib/modprobe.d/`, NOT `/etc/modprobe.d/` — atomic-image immutability convention from bazzite Containerfile):
   ```
   options nvidia NVreg_PreserveVideoMemoryAllocations=1
   options nvidia NVreg_TemporaryFilePath=/var/tmp
   options nvidia NVreg_EnableGpuFirmware=1
   options nvidia NVreg_DynamicPowerManagement=0x02
   ```
   - `NVreg_PreserveVideoMemoryAllocations=1` — saves full VRAM to disk on suspend/hibernate; without it, suspend/resume corrupts open GL surfaces and kills the compositor. Source: NVIDIA driver README `powermanagement.html`.
   - `NVreg_TemporaryFilePath=/var/tmp` — default `/tmp` is tmpfs; hibernating an 8 GB VRAM pool overflows it.
   - `NVreg_EnableGpuFirmware=1` — GSP firmware default-on for proprietary; defensive.
   - `NVreg_DynamicPowerManagement=0x02` — Optimus laptop fine-grained Runtime D3; harmless on desktops.
5. **NIR-33c** — niri-specific VRAM-leak mitigation: ship `/usr/share/nvidia/nvidia-application-profiles-rc.d/50-niri.json` (per niri wiki `Nvidia.md`):
   ```json
   {
     "rules": [
       { "pattern": { "feature": "procname", "matches": "niri" },
         "profile": "Limit Free Buffer Pool On Wayland Compositors" }
     ],
     "profiles": [
       { "name": "Limit Free Buffer Pool On Wayland Compositors",
         "settings": [ { "key": "GLVidHeapReuseRatio", "value": 0 } ] }
     ]
   }
   ```
   Without this, niri pins ~1 GiB VRAM instead of ~100 MiB on NVIDIA. Source: niri wiki Nvidia.md citing NVIDIA/egl-wayland#126.
6. **NIR-33d** — niri config (`/etc/xdg/niri/config.kdl`) ships `debug { disable-cursor-plane }` block. niri's equivalent of `WLR_NO_HARDWARE_CURSORS` for the cursor-stuttering-on-VRR-with-NVIDIA bug class (niri-wm/niri#3095, "Laggy cursor/session with NVIDIA 590.48.01"). Conditional inclusion — only shipped on the nvidia variant via the `os/modules/nvidia/apply.sh` gate.
7. **NIR-33e** — Wayland+NVIDIA env vars shipped via `/usr/lib/environment.d/90-sideral-niri-nvidia.conf` (NOT `profile.d`; environment.d covers both login shells and graphical sessions without shell dependency):
   ```
   __GL_GSYNC_ALLOWED=1
   __GL_VRR_ALLOWED=1
   LIBVA_DRIVER_NAME=nvidia
   NVD_BACKEND=direct
   MOZ_DISABLE_RDD_SANDBOX=1
   ```
   - `__GL_GSYNC_ALLOWED=1` / `__GL_VRR_ALLOWED=1` — Wayland G-Sync/VRR plumbing.
   - `LIBVA_DRIVER_NAME=nvidia` + `NVD_BACKEND=direct` — VAAPI hardware decode via libva-nvidia-driver (Fedora main; `NVD_BACKEND=direct` because the EGL backend has been broken since driver 525).
   - `MOZ_DISABLE_RDD_SANDBOX=1` — Firefox/Zen RDD process needs unsandboxed access to the NVDEC ioctl. Source: bazzite `system_files/desktop/shared/usr/libexec/bazzite-flatpak-manager`. **Do not** ship `WLR_NO_HARDWARE_CURSORS=1` — niri is not wlroots, that var is ignored.
8. **NIR-33f** — `libva-nvidia-driver` + `libva-utils` are installed on the nvidia variant via `os/modules/nvidia/packages.txt` (Fedora main; ublue's `nvidia-install.sh` already pulls libva-nvidia-driver transitively, but listing explicitly so we don't depend on the transitive). Verifiable post-rebase via `vainfo` showing the nvidia driver and supported codecs.
9. **NIR-33g** — systemd services (verify-only, no action needed): `nvidia-powerd.service`, `nvidia-suspend.service`, `nvidia-resume.service`, `nvidia-hibernate.service`, `nvidia-suspend-then-hibernate.service` are all auto-enabled by the `nvidia-driver` RPM presets shipped in the silverblue-nvidia:43 base. Verify with `systemctl is-enabled nvidia-powerd nvidia-suspend nvidia-resume nvidia-hibernate` — all should return `enabled` post-rebase.
10. **NIR-33h** — udev rules (verify-only, no action needed): `/usr/lib/udev/rules.d/60-nvidia-extra-devices-pm.rules` ships from `ublue-os-nvidia-addons` (transitive from silverblue-nvidia:43); handles power management for the audio/USB/Type-C functions of the GPU on Optimus. Verifiable via `ls /usr/lib/udev/rules.d/60-nvidia*` post-rebase.
11. **NIR-34** — `os/modules/desktop-niri/README.md` includes a "NVIDIA known issues + workarounds" section pinned to the niri version we ship at build time. Pulled from niri upstream's wiki `Nvidia.md` (https://github.com/YaLTeR/niri/wiki/Nvidia) and tested against the workflows sideral cares about (terminal, browser, VS Code, Noctalia rendering, video playback). Gaming/VR/DRM-leases workflows are flagged as "if you need GNOME+Mutter parity for those, fork at the pre-niri SHA."
12. **NIR-34a** — NVK Mesa interaction documented: NVK is the open Vulkan driver shipping in F43 Mesa; sideral's nvidia variant uses the proprietary nvidia driver and explicitly does NOT enable NVK. README documents the env var opt-in path (`__GLX_VENDOR_LIBRARY_NAME=mesa`) for users who want to test NVK without rebasing.

### P3: Discoverability and migration

**Story**: A user on a current GNOME sideral install can read sideral's docs and understand: what's changing, why, what they need to do, and how to roll back if niri doesn't fit them.

**Acceptance**:
1. **NIR-35** — `README.md` documents the niri session: what it is, what shell ships (Noctalia, via Terra), what the default keybinds are, how to change the wallpaper (`ujust theme`), and how to roll back via `rpm-ostree rollback` to the previous deployment.
2. **NIR-36** — `os/modules/desktop-niri/README.md` documents the niri / noctalia-qs / Noctalia stack: pinned versions, where matugen templates live (`/etc/xdg/matugen/templates/` and `/etc/skel/.config/matugen/templates/`), where the niri config is (`/etc/xdg/niri/config.kdl`), where Noctalia's QML lives (`/etc/xdg/quickshell/noctalia-shell/`), and how to extend any of those via chezmoi.
3. **NIR-37** — README has a "what changed from the GNOME-era image" section. **No** "rebase to a frozen GNOME tag" instruction — D-15 locked: no preservation tag exists. Rollback is `rpm-ostree rollback` (single-deployment) or fork-the-repo at the pre-niri SHA. README documents both.
4. **NIR-38** — `niri --version`, `matugen --version`, and `rpm -q noctalia-shell noctalia-qs ghostty sddm` output is captured in the build banner (matches the existing `starship --version` printout in `os/modules/shell-tools/starship-install.sh`). Noctalia is QML-only and ships no CLI version flag, so the RPM-NEVRA query is the substitute.

## Cross-cutting acceptance

- All shell scripts under `os/modules/desktop-niri/` pass `shellcheck`.
- `just lint` exit 0 with no shell-script changes elsewhere.
- `just build` exit 0; `bootc container lint` exit 0.
- The image still rebases via `ostree-unverified-registry:` (no signed-rebase flip in this feature).
- Build artifacts in CI: same shape as today (ghcr.io/<owner>/<image-name>:{latest,YYYYMMDD,sha-…}). Image names unchanged (`sideral`, `sideral-nvidia`); contents flipped from GNOME to niri+Noctalia. No `:gnome-final` preservation tag; `:latest` is the only canonical tag.
- Boot to first niri-session login on a clean disposable VM is <60 seconds.
- **`os/modules/desktop/` is removed from the tree** (`git status` shows the directory deleted; `os/lib/build.sh` `MODULES` array no longer references `desktop`).
- **`os/lib/build.sh` GNOME prune step expanded**: the `to_remove` package list adds `gdm`, `gnome-shell`, `gnome-session`, `mutter`, `gnome-control-center`, `gnome-settings-daemon`, plus the gnome-shell-extension RPMs (`gnome-shell-extension-appindicator`, `gnome-shell-extension-dash-to-panel`). Each is gated on `rpm -q $pkg` so the dnf5 remove call doesn't fail on already-absent packages.
- **`rpm -qa | grep -E '^gnome-(shell|session|control-center|settings-daemon)|^mutter|^gdm'` returns empty** in the built image.
- **SDDM is the active display manager**: `systemctl is-enabled sddm.service` returns `enabled` and `gdm.service` is absent (or disabled) in the built image. `systemctl get-default` returns `graphical.target` (inherited; unchanged).

## Dependencies

| Component | Source | Notes |
|---|---|---|
| niri (compositor) | **Fedora main** (`rpms/niri`, in f42/f43/rawhide; current `niri-26.04`) | D-03 — verified 2026-05-02 in Fedora dist-git. No COPR needed. |
| Quickshell runtime | **Terra** as `noctalia-qs` (Quickshell hard-fork by noctalia-dev; v0.0.12; `Conflicts: quickshell, Provides: quickshell`) | D-14 retired — Noctalia uses noctalia-qs, no upstream Quickshell needed. |
| Noctalia (shell) | **Terra** as `noctalia-shell` (current 4.7.6; spec at github.com/terrapkg/packages/tree/master/anda/desktops/noctalia-shell, packaged by `terra@willowidk.dev`) | D-04 — replaces the DMS-via-Terra plan after the user noted that the host-shell choice is overwritten by `niri-islands` anyway, so minimalism + dropping the Quickshell COPR is the permanent win. Pulls noctalia-qs, brightnessctl, dejavu-sans, qt6-qtmultimedia, xdg-desktop-portal as Requires; recommends matugen, cliphist, cava, ddcutil, power-profiles-daemon, wlsunset, gpu-screen-recorder. |
| matugen (theming) | **Fedora main** as `rust-matugen` (binary: `matugen`) | D-10 — verified 2026-05-02 in `packages.fedoraproject.org`. solopasha/matugen COPR retired. (Terra also has matugen 4.1.0 but Fedora main is preferred.) |
| ghostty (terminal) | **Terra** as `ghostty` (stable stream; spec verifies upstream minisign key from `ghostty-org/ghostty/PACKAGING.md`) | D-07 — replaces `scottames/ghostty` (COPR with no spec-level upstream signature verification) and `pgdev/ghostty` (archived/defunct since 01/2025). Stronger trust; multi-maintainer; same repo Bazzite/Aurora pre-ship. |
| SDDM (greeter) | Fedora main | D-02 |
| SilentSDDM (theme) | Upstream tarball + sha256 verification, extracted to `/usr/share/sddm/themes/silent/` | D-02 |
| kanshi (multi-monitor) | Fedora main | NIR-14 |
| fcitx5 + fcitx5-configtool (IME) | Fedora main | NIR-15e |
| grim, slurp, wl-clipboard, cliphist (screenshot/clipboard) | Fedora main (cliphist also `Recommends:`-pulled by Terra's `noctalia-shell`) | NIR-15c, NIR-15d |
| PipeWire / NetworkManager / UPower | Inherited from silverblue-main | Noctalia consumes via Quickshell.Services.* |
| Notification daemon / app launcher / lock+idle / wallpaper | Noctalia handles internally (`noctalia-qs Provides: desktop-notification-daemon`) | D-05 / D-06 / D-08 / D-11 auto-resolved |

## Implementation notes (high-level)

**Module structure** (post 2026-05-02 module refactor):
- New `os/modules/desktop-niri/` containing:
  - `packages.txt` — Fedora main + Terra packages: `niri`, `rust-matugen`, `kanshi`, `fcitx5`, `fcitx5-configtool`, `grim`, `slurp`, `wl-clipboard`, `cliphist`, `sddm`, `noctalia-shell` (Terra), `noctalia-qs` (Terra; Quickshell runtime), `ghostty` (Terra). No COPRs.
  - `terra-bootstrap.sh` — installs `terra-release` at image build before the per-module `dnf5 install` pass (one-shot bootstrap with `--nogpgcheck --repofrompath`; subsequent installs use the now-trusted GPG key shipped by `terra-release`).
  - ~~`niri-install.sh`~~ — not needed; niri in Fedora main
  - ~~`quickshell-install.sh`~~ — not needed; noctalia-qs from Terra
  - ~~`dms-install.sh`~~ — n/a; Noctalia replaces DMS
  - ~~`matugen-install.sh`~~ — not needed; `rust-matugen` in Fedora main
  - `sddm-silent-install.sh` — fetch SilentSDDM release tarball (https://github.com/uiriansan/SilentSDDM), sha256-verify, extract to `/usr/share/sddm/themes/silent/`. Same pattern as starship's upstream-binary install. (SilentSDDM not in Terra or Fedora main.)
  - `src/etc/skel/.config/niri/config.kdl` — sideral default niri config (Noctalia spawn rule, kanshi spawn, fcitx5 spawn, sane keybinds, `Mod+T → ghostty`)
  - `src/etc/xdg/niri/config.kdl` — same content; system-default fallback per D-09
  - `src/etc/xdg/quickshell/noctalia-shell/sideral-overrides.json` — sideral's Noctalia-config overrides if any (Noctalia is JSON-config-driven per its docs)
  - `src/etc/sddm.conf.d/sideral-silent.conf` — `[Theme] Current=silent`
  - `src/usr/share/wayland-sessions/niri.desktop` — niri session entry for SDDM (`Exec=niri-session`)
  - Noctalia's systemd user service (if upstream ships one) is RPM-owned by `noctalia-shell`; sideral layers a `*.service.d/sideral.conf` drop-in only if needed.
  - `src/usr/lib/systemd/user/niri-session.target.wants/*` — enablement symlinks
  - `rpm/sideral-niri-defaults.spec` — owns the above; `Conflicts: gdm gnome-shell gnome-session mutter gnome-control-center gnome-settings-daemon`
- `os/modules/desktop/` is **retired entirely** (D-01 locked).
- `MODULES` list in `os/lib/build.sh` updates: `desktop` → `desktop-niri`.
- New ujust recipes in `60-custom.just` (`os/modules/shell-init/src/usr/share/ublue-os/just/60-custom.just`):
  - `ujust theme <wallpaper>` — runs matugen → re-themes Noctalia (via its matugen-watch path; Noctalia's QML uses Quickshell's `FileView { watchChanges: true }` to pick up changes reactively), ghostty (signal `pkill -USR1 ghostty` after matugen succeeds), helix (next-launch). Notification overlay / launcher / lock are part of Noctalia and recolor automatically with the rest of the shell. Falls back to direct `matugen image …` invocation if Noctalia exposes no higher-level reload trigger.
  - `ujust niri` — niri/Noctalia keybind cheatsheet. Modeled on the existing `ujust tools` recipe shape (uses ublue's `libformatting.sh`, OSC-8 hyperlinks via Urllink, `B/D/R` styling). Documents at minimum: `Mod+D` launcher (Noctalia), `Mod+T` ghostty, `Mod+L` lock (Noctalia), `Mod+Q` close window, `Mod+Left/Right` scroll axis navigation, `Mod+Shift+Left/Right` move-column-left/right, workspace switching, `ujust theme <wallpaper>` for matugen re-theme, where to override niri config via chezmoi.
- `/etc/user-motd` (in `sideral-shell-ux`) gets ONE new row pointing at `ujust niri`. The existing rows (chsh, chezmoi-init, gdrive-setup, tools, update) stay unchanged. NIR-23 acceptance: motd structure is preserved; user discovers niri-specific tips via the new ujust recipe rather than via a rewritten banner.

**RPM packaging**:
- `sideral-niri-defaults` sub-package owns the niri config files, the SDDM theme conf, the niri.desktop wayland-session entry, the IME profile.d snippet, any Noctalia config overrides under `/etc/xdg/quickshell/noctalia-shell/`, and wallpaper assets in `/usr/share/wallpapers/sideral/`. **Noctalia + noctalia-qs (Quickshell runtime) come from Terra RPMs** — sideral does not vendor or build any shell code.
- Conflicts unconditional: against `gnome-shell`, `gnome-session`, `mutter`, `gdm`, `gnome-control-center`, `gnome-settings-daemon`.

**Persistent third-party repos** (same pattern as `mise.repo`, `vscode.repo`, `kubernetes.repo`):
- **Terra** via `terra-release` RPM — installs `/etc/yum.repos.d/terra.repo` + `/etc/pki/rpm-gpg/RPM-GPG-KEY-terra` in one shot. Layered at image build via `dnf5 install terra-release` (or `--repofrompath` bootstrap; same pattern Bazzite/Aurora use). Sources: `noctalia-shell`, `noctalia-qs` (Quickshell runtime), `ghostty`. Used in this image **enabled** by default (Bazzite/Aurora ship Terra `enabled=0`; sideral wants it active).
- All shipped via `sideral-niri-defaults` (or sideral-base — `/spec-design` decides); kept enabled so `rpm-ostree upgrade` pulls package point releases between sideral rebuilds.
- **No COPRs.** D-14 retired with the Noctalia swap.

**Bootstrap order in `os/lib/build.sh`:**
1. Bootstrap Terra at image build: `dnf5 install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release` (one-shot; subsequent installs use the now-trusted GPG key shipped by `terra-release`).
2. Per-module `dnf5 install` passes that hit Fedora main + Terra can now resolve everything.

**In Fedora main, no third-party repo needed** (verified 2026-05-02):
- niri (`rpms/niri`, current `niri-26.04` on f42/f43/rawhide)
- matugen (`packages.fedoraproject.org/pkgs/rust-matugen/`, installs the `matugen` binary)
- cliphist, kanshi, fcitx5, grim, slurp, wl-clipboard, sddm, libva-nvidia-driver — all Fedora main

## Open questions — see context.md

| ID | Question | Status |
|----|----------|--------|
| **D-01** | Full GNOME replacement vs parallel `sideral-niri` variant? | ✅ Locked: full replacement |
| **D-02** | Greeter | ✅ Locked: SDDM + SilentSDDM theme (https://github.com/uiriansan/SilentSDDM). `sddm` from Fedora main; SilentSDDM fetched from upstream tarball + sha256-verified at image build into `/usr/share/sddm/themes/silent/`. `gdm` retires alongside GNOME. |
| **D-03** | niri install source | ✅ Locked: **Fedora main** (`rpms/niri`, in f42/f43/rawhide — verified 2026-05-02; current `niri-26.04`). No COPR. Lock updated from "yalter/niri COPR" once the Fedora-main package was confirmed. |
| **D-04** | Shell pick — DMS vs Noctalia vs sideral-authored? | ✅ Locked: **ship stock Noctalia via Terra's `noctalia-shell` RPM** (third lock — was originally git-clone-and-build DMS, then Terra DMS, now Noctalia after the user noted the host-shell choice is overwritten by `niri-islands` anyway, so minimalism + dropping the Quickshell COPR is the permanent win). |
| **D-05** | Notification daemon | ✅ Auto-resolved: Noctalia handles |
| **D-06** | App launcher | ✅ Auto-resolved: Noctalia handles |
| **D-07** | Default terminal | ✅ Locked: ghostty via **Terra** (`ghostty` package; spec verifies upstream minisign signature). Updated 2026-05-02 from `scottames/ghostty` (and earlier `pgdev/ghostty` which was archived). matugen template renders `~/.config/ghostty/config`. niri keybind: `Mod+T → /usr/bin/ghostty`. |
| **D-08** | Lock + idle | ✅ Auto-resolved: Noctalia handles |
| **D-09** | niri/Quickshell defaults location | ✅ Locked default: /etc/xdg + /etc/skel (both — gives both first-login population and rebase-time updates; chezmoi can override either layer) |
| **D-10** | matugen install source | ✅ Locked: **Fedora main** (`rust-matugen` package). Updated 2026-05-02 from `solopasha/matugen` COPR after that COPR was confirmed personal/testing-only and Fedora main was confirmed to have the package. No COPR needed. |
| **D-11** | Wallpaper backend | ✅ Auto-resolved: Noctalia handles |
| **D-12** | Welcome motd | ✅ Locked: motd keeps current structure; gets one new row pointing at the new `ujust niri` cheatsheet recipe. The cheatsheet itself (Mod+D launcher, Mod+T ghostty, Mod+L lock, Mod+Q close, scroll-axis navigation, `ujust theme <wallpaper>`, etc.) is shipped as a new `ujust niri` recipe modeled on the existing `ujust tools` shape (in `/usr/share/ublue-os/just/60-custom.just`). |
| **D-13** | Niri+NVIDIA parity — both variants ship niri, or NVIDIA stays on GNOME? | ✅ Locked: niri on both variants. No frozen GNOME-NVIDIA fallback. |
| **D-14** | Quickshell install source | ✅ **RETIRED** with the Noctalia swap. Noctalia uses `noctalia-qs` (Quickshell hard-fork from Terra; `Conflicts: quickshell, Provides: quickshell`); upstream Quickshell is no longer in the image. No COPR needed. |
| **D-15** | Migration UX | ✅ Locked: silent swap on :latest, no `:gnome-final` preservation tag. No GNOME image shipped at all. Users use `rpm-ostree rollback` or fork at pre-niri SHA for opt-out. |
| **D-16** | niri IPC consumption pattern | ✅ Auto-resolved: Noctalia handles via its internal NiriService |
| **D-17** | Service singletons + Appearance/matugen wiring | ✅ Auto-resolved: Noctalia handles |

## Notes

- The user wrote "matugem" in the original request. matugem is not a known project; matugen (https://github.com/InioX/matugen) is the actual Material 3 wallpaper-to-theme tool that DMS/Noctalia integrate with. Treating "matugem" as a misspelling of "matugen" throughout this spec; if the user actually meant a different tool, D-10 captures the reconsideration.
