#!/usr/bin/env bash
# Apply NVIDIA-variant tweaks if we're building on top of silverblue-
# nvidia:43. Runs inside the orchestrator's per-module loop; both base
# and nvidia builds invoke it, but only the nvidia build does anything
# (variant detection by `rpm -q kmod-nvidia`).
#
# What this installs (kargs + five niri-era additions):
#   • kargs.d/00-nvidia.toml — bootc early-boot kargs (modeset, fbdev,
#     blacklists). Applied to the bootloader entry on rpm-ostree upgrade.
#   • modprobe.d/sideral-nvidia.conf → /usr/lib/modprobe.d/ — NVreg
#     options (VRAM persistence, temp path, GSP firmware, power mgmt).
#   • nvidia-app-profiles/50-niri.json → NVIDIA app-profiles RC dir —
#     GLVidHeapReuseRatio=0 for niri to cap VRAM leak.
#   • environment.d/90-sideral-niri-nvidia.conf → /usr/lib/environment.d/
#     — Wayland env vars (GSYNC, VRR, LIBVA, NVD_BACKEND, MOZ sandbox).
#   • niri.config.d/sideral-nvidia.kdl → /etc/xdg/niri/config.d/ —
#     `debug { disable-cursor-plane }` for VRR cursor-stutter fix.
#
# The mutter dconf override (50-sideral-nvidia) was removed 2026-05-02:
# niri's smithay backend handles KMS modifiers natively; the gsetting
# was Mutter-only and has no niri equivalent (NIR-33a).

set -euo pipefail

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

if ! rpm -q kmod-nvidia >/dev/null 2>&1; then
    log "[nvidia] base variant detected — skipping"
    exit 0
fi

mod_dir="$(dirname "$0")"

log "[nvidia] writing kargs.d/00-nvidia.toml"
install -Dm644 "$mod_dir/kargs.d/00-nvidia.toml" /usr/lib/bootc/kargs.d/00-nvidia.toml

log "[nvidia] writing modprobe.d/sideral-nvidia.conf"
install -Dm644 "$mod_dir/modprobe.d/sideral-nvidia.conf" /usr/lib/modprobe.d/sideral-nvidia.conf

log "[nvidia] writing nvidia-app-profiles/50-niri.json"
install -Dm644 "$mod_dir/nvidia-app-profiles/50-niri.json" \
    /usr/share/nvidia/nvidia-application-profiles-rc.d/50-niri.json

log "[nvidia] writing environment.d/90-sideral-niri-nvidia.conf"
install -Dm644 "$mod_dir/environment.d/90-sideral-niri-nvidia.conf" \
    /usr/lib/environment.d/90-sideral-niri-nvidia.conf

log "[nvidia] writing niri.config.d/sideral-nvidia.kdl"
install -Dm644 "$mod_dir/niri.config.d/sideral-nvidia.kdl" \
    /etc/xdg/niri/config.d/sideral-nvidia.kdl
