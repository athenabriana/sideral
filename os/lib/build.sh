#!/usr/bin/env bash
set -euo pipefail

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

MODULES_DIR="/ctx/modules"
BUILD_DIR="/ctx/build"

MODULES=(cli-tools services kubernetes nix)
BUILD=(fonts nvidia)

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

log "Regenerating initramfs"
KERNEL_VERSION="$(rpm -q --queryformat='%{evr}.%{arch}' kernel-core)"
export DRACUT_NO_XATTR=1
/usr/bin/dracut --no-hostonly --kver "$KERNEL_VERSION" --reproducible --add ostree -f "/lib/modules/${KERNEL_VERSION}/initramfs.img"
chmod 0600 "/lib/modules/${KERNEL_VERSION}/initramfs.img"
unset DRACUT_NO_XATTR

log "Done."
