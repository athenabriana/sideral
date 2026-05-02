#!/usr/bin/env bash
# Apply NVIDIA-variant tweaks if we're building on top of silverblue-
# nvidia:43. Runs inside the orchestrator's per-module loop; both base
# and nvidia builds invoke it, but only the nvidia build does anything
# (variant detection by `rpm -q kmod-nvidia`).
#
# Why these are needed:
#   • silverblue-nvidia:43 ships kmod-nvidia, modprobe.d/nvidia.conf,
#     and dracut force_drivers — but NOT a kargs.d file. The four
#     kargs are required for proper Wayland on NVIDIA (most critically
#     nvidia-drm.modeset=1).
#   • Stock GNOME on F43 does NOT enable kms-modifiers by default for
#     nvidia-drm. Without it, Wayland uses legacy mode-setting and
#     produces tearing / partial frames.
# Bluefin handles both in its own 03-install-kernel-akmods.sh +
# 05-override-install.sh; sideral derives from silverblue-nvidia and
# has to add them back here.

set -euo pipefail

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

if ! rpm -q kmod-nvidia >/dev/null 2>&1; then
    log "[nvidia] base variant detected — skipping"
    exit 0
fi

mod_dir="$(dirname "$0")"

log "[nvidia] writing kargs.d/00-nvidia.toml"
install -Dm644 "$mod_dir/kargs.d/00-nvidia.toml" /usr/lib/bootc/kargs.d/00-nvidia.toml

log "[nvidia] writing dconf override 50-sideral-nvidia (mutter kms-modifiers)"
install -Dm644 "$mod_dir/dconf/50-sideral-nvidia" /etc/dconf/db/local.d/50-sideral-nvidia
