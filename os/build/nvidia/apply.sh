#!/usr/bin/env bash
# Apply NVIDIA-variant tweaks if we're building on top of silverblue-
# nvidia:44. Runs inside the orchestrator's per-module loop; both base
# and nvidia builds invoke it, but only the nvidia build does anything
# (variant detection by `rpm -q kmod-nvidia`).
#
# What this installs:
#   • kargs.d/00-nvidia.toml — bootc early-boot kargs (modeset, fbdev,
#     blacklists). Applied to the bootloader entry on rpm-ostree upgrade.
#   • modprobe.d/silverfox-nvidia.conf → /usr/lib/modprobe.d/ — NVreg
#     options (VRAM persistence, temp path, GSP firmware, power mgmt).

set -euo pipefail

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

if ! rpm -q kmod-nvidia >/dev/null 2>&1; then
    log "[nvidia] base variant detected — skipping"
    exit 0
fi

mod_dir="$(dirname "$0")"

log "[nvidia] writing kargs.d/00-nvidia.toml"
install -Dm644 "$mod_dir/kargs.d/00-nvidia.toml" /usr/lib/bootc/kargs.d/00-nvidia.toml

log "[nvidia] writing modprobe.d/silverfox-nvidia.conf"
install -Dm644 "$mod_dir/modprobe.d/silverfox-nvidia.conf" /usr/lib/modprobe.d/silverfox-nvidia.conf
