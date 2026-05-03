#!/usr/bin/env bash
# build.sh — Layer 2: run per-module *.sh scripts then regenerate initramfs.
# Package installation is handled by install-packages.sh (Layer 1).
#
# Module ORDER: cli-tools first (nushell-plugins-install.sh needs the `nu`
# binary that Layer 1 installed). flatpaks last so all sideral RPMs are
# present before the curated Flatpak set is preinstalled. nvidia last in
# BUILD so it's a no-op on the base variant without affecting other steps.

set -euo pipefail

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

MODULES_DIR="/ctx/modules"
BUILD_DIR="/ctx/build"

MODULES=(cli-tools niri-defaults services kubernetes flatpaks)
BUILD=(fonts nvidia)

# ── 1. Run per-module *.sh scripts ────────────────────────────────────
_run_scripts() {
    local label="$1" module_dir="$2"
    [ -d "$module_dir" ] || { log "[$label] no dir at $module_dir, skipping"; return; }
    shopt -s nullglob
    for script in "$module_dir"/*.sh; do
        log "[$label] running $(basename "$script")"
        "$script"
    done
    shopt -u nullglob
}

for module in "${MODULES[@]}"; do
    _run_scripts "$module" "$MODULES_DIR/$module"
done
for module in "${BUILD[@]}"; do
    _run_scripts "$module" "$BUILD_DIR/$module"
done

# ── 2. Regenerate initramfs ────────────────────────────────────────────
# Defensive end-of-build regen, matching bluefin's pattern. silverblue-
# {main,nvidia}:44 each generate an initramfs at upstream build time and
# nothing in the steps above should invalidate it (we install only
# userspace packages and don't touch kernel modules), but if a future
# package install triggers a kernel post-script that strips nvidia/zfs/
# whatever from the initramfs without rebuilding, this catches it.
# --reproducible + DRACUT_NO_XATTR=1 keep the output deterministic so
# rebuilds with no upstream change produce byte-identical images.
log "Regenerating initramfs"
KERNEL_VERSION="$(rpm -q --queryformat='%{evr}.%{arch}' kernel-core)"
export DRACUT_NO_XATTR=1
/usr/bin/dracut --no-hostonly --kver "$KERNEL_VERSION" --reproducible --add ostree -f "/lib/modules/${KERNEL_VERSION}/initramfs.img"
chmod 0600 "/lib/modules/${KERNEL_VERSION}/initramfs.img"
unset DRACUT_NO_XATTR

log "Done."
