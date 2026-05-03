# desktop-niri

Sideral's niri compositor + Noctalia shell module. Replaces `os/modules/desktop/` (retired 2026-05-02).

## Pinned versions

| Component | Source | Version pinned at module creation |
|---|---|---|
| niri | Fedora main (`rpms/niri`) | `niri-26.04` |
| noctalia-shell | Terra (`repo.terra.fyralabs.com`) | `4.7.6` |
| noctalia-qs | Terra | `v0.0.12` |
| ghostty | Terra | latest stable at build time |
| SilentSDDM | Upstream tarball (`uiriansan/SilentSDDM`) | `v1.4.2` (pinned in `sddm-silent-install.sh`) |
| matugen | Fedora main (`rust-matugen`) | latest at build time |

Bump `SDDM_TAG` in `sddm-silent-install.sh` manually when upgrading SilentSDDM. Update `SDDM_SHA256` alongside it (compute: `curl -fsSL <tarball-url> | sha256sum`). Other versions track Fedora main / Terra update cadence automatically via `rpm-ostree upgrade`.

## File layout

```
os/modules/desktop-niri/
├── packages.txt                      # Fedora-main + Terra packages (installed by build.sh)
├── sddm-silent-install.sh            # fetches SilentSDDM v1.4.2 at image build
├── src/
│   ├── etc/
│   │   ├── profile.d/
│   │   │   └── sideral-niri-ime.sh  # fcitx5 XMODIFIERS/GTK/QT env vars
│   │   ├── sddm.conf.d/
│   │   │   └── sideral-silent.conf  # points SDDM at the "silent" theme
│   │   ├── skel/
│   │   │   └── .config/
│   │   │       ├── matugen/          # per-user matugen config seed
│   │   │       ├── niri/             # per-user niri config seed
│   │   │       └── noctalia/         # Noctalia settings seed
│   │   ├── xdg/
│   │   │   ├── matugen/              # system-default matugen config
│   │   │   └── niri/config.kdl       # system-default niri config
│   │   └── yum.repos.d/
│   │       └── terra.repo            # Terra repository (noctalia-shell, noctalia-qs, ghostty)
│   └── usr/share/
│       ├── wayland-sessions/
│       │   └── niri.desktop          # session entry for SDDM
│       └── wallpapers/sideral/
│           └── README.md             # placeholder; add default.jpg here
└── rpm/
    └── sideral-niri-defaults.spec    # RPM spec — owns all src/ paths above
```

**Quickshell QML** (Noctalia's bar, launcher, lock, notifications, wallpaper) ships from Terra's `noctalia-shell` RPM to `/etc/xdg/quickshell/noctalia-shell/`. That directory is RPM-owned by `noctalia-shell`, not by `sideral-niri-defaults`.

## Overriding defaults with chezmoi

Sideral ships defaults at two layers:

| Layer | Path | Purpose |
|---|---|---|
| System default | `/etc/xdg/niri/config.kdl` | niri reads this when no user config exists |
| Per-user seed | `/etc/skel/.config/niri/config.kdl` | copied to `~/.config/niri/` on user creation |

To override per-user, add a chezmoi template:
```
~/.local/share/chezmoi/dot_config/niri/config.kdl.tmpl
```
or a plain file `dot_config/niri/config.kdl`. `chezmoi apply` writes to `~/.config/niri/config.kdl`; niri prefers `~/.config/` over `/etc/xdg/` so the user copy takes precedence.

Same pattern for matugen templates (`~/.config/matugen/templates/ghostty`, `~/.config/matugen/templates/helix.toml`) and the Noctalia seed (`~/.config/noctalia/settings.json`).

## NVIDIA known issues + workarounds (niri-26.04 + proprietary driver, F43)

The `sideral-nvidia` variant ships niri from day one with the full bluefin/bazzite-grade NVIDIA hardening layer (`os/build/nvidia/`). The configuration applied by `apply.sh` covers: kargs, modprobe NVreg options, VRAM-leak app profile, Wayland env vars, and the `debug { disable-cursor-plane }` niri drop-in. **Desktop-class workflows (terminal, browser, VS Code, Noctalia rendering, video playback) are expected to work**. The issues below are edge-case or hardware-specific.

### Cursor stuttering / VRR + NVIDIA

**Symptom**: Mouse cursor renders at the monitor's base refresh rate even when VRR is active (appears to stutter against smooth window animations).  
**Root cause**: niri-wm/niri#3095 — niri's smithay backend schedules cursor plane updates on a different timeline from the main DRM commit when VRR is active on NVIDIA 590+.  
**Workaround**: `debug { disable-cursor-plane }` is shipped as `/etc/xdg/niri/config.d/sideral-nvidia.kdl` on the nvidia variant. This forces the cursor to be composited into the frame (slight overhead, eliminates the stutter). No user action required — it's on by default.

### Suspend/resume VRAM corruption

**Symptom**: Compositor surfaces (bar, windows) appear garbled or black after waking from suspend.  
**Root cause**: NVIDIA driver default doesn't persist VRAM across suspend without `NVreg_PreserveVideoMemoryAllocations=1`.  
**Workaround**: Set in `/usr/lib/modprobe.d/sideral-nvidia.conf` (applied by `nvidia/apply.sh`). Verify: `cat /proc/driver/nvidia/params | grep PreserveVideoMemoryAllocations` should show `1` after boot.

### Hardware decode (VAAPI / NVDEC)

**Symptom**: Video playback in Zen Browser / Firefox has high CPU usage; GPU decode is not used.  
**Root cause**: `LIBVA_DRIVER_NAME` and `NVD_BACKEND` need to be set for the NVIDIA VAAPI backend.  
**Workaround**: Set in `/usr/lib/environment.d/90-sideral-niri-nvidia.conf` (`LIBVA_DRIVER_NAME=nvidia`, `NVD_BACKEND=direct`). Verify: `vainfo` should report the nvidia driver and list NVDEC-supported codecs.  
`MOZ_DISABLE_RDD_SANDBOX=1` (also in that file) lets the RDD subprocess reach the NVDEC ioctl; required for browser decode.

### Gaming / VR / DRM-lease workflows

niri's smithay backend doesn't implement DRM leases (required by SteamVR, some game engines). If you need GNOME+Mutter parity for gaming or VR, use `rpm-ostree rollback` to return to the previous deployment (the last GNOME-era sideral build), or fork the repo at the pre-niri SHA.

### NVK (open Vulkan driver) opt-in

The nvidia variant uses the proprietary NVIDIA Vulkan driver. NVK (Mesa open Vulkan) is in F43 but NOT active by default on sideral-nvidia — the proprietary driver takes precedence. To test NVK without rebasing:
```bash
__GLX_VENDOR_LIBRARY_NAME=mesa niri  # or any per-app launch wrapper
```
This is unsupported; NVK on F43 is mature for many workloads but unverified against sideral's full stack. File upstream issues at mesa/mesa.
