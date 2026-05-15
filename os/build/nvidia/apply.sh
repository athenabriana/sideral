#!/usr/bin/env bash
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
