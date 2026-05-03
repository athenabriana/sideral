#!/usr/bin/env bash
# install-packages.sh — Layer 1: remove inherited packages, stage repos,
# install all module packages.txt. No scripts run here (see build.sh).
# Mounted from ctx-packages (stable content only) so spec/script changes
# do not invalidate this layer's BuildKit cache.
#
# Module ORDER mirrors build.sh. flatpaks has no packages.txt — no-op.

set -euo pipefail

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

MODULES_DIR="/ctx/modules"
BUILD_DIR="/ctx/build"

MODULES=(cli-tools niri-defaults services kubernetes flatpaks)
BUILD=(fonts nvidia)

# ── 1. Remove inherited base packages ──────────────────────────────────
log "Removing inherited base packages"
to_remove=()
for pkg in firefox firefox-langpacks dconf-editor \
           gnome-software gnome-software-rpm-ostree \
           gdm gnome-shell gnome-session mutter \
           gnome-control-center gnome-settings-daemon \
           gnome-shell-extension-appindicator \
           gnome-shell-extension-dash-to-panel; do
    rpm -q "$pkg" >/dev/null 2>&1 && to_remove+=("$pkg")
done
[ ${#to_remove[@]} -gt 0 ] && dnf5 remove -y "${to_remove[@]}"

# ── 2. Stage persistent yum repos ──────────────────────────────────────
log "Staging persistent yum repos"
shopt -s nullglob
for repo_src in "$MODULES_DIR"/*/src/etc/yum.repos.d/*.repo; do
    log "  $(basename "$repo_src")"
    cp "$repo_src" /etc/yum.repos.d/
done
shopt -u nullglob

# ── 3. Install packages from every module's packages.txt ───────────────
_install_pkg_file() {
    local label="$1" pkg_file="$2"
    [ -f "$pkg_file" ] || return 0
    local packages
    packages=$(grep -vE '^\s*(#|$)' "$pkg_file" | tr '\n' ' ')
    [ -n "$packages" ] || return 0
    log "[$label] installing"
    echo "  $packages"
    # shellcheck disable=SC2086
    dnf5 install -y --setopt=install_weak_deps=False $packages
}

for module in "${MODULES[@]}"; do
    _install_pkg_file "$module" "$MODULES_DIR/$module/packages.txt"
done
for module in "${BUILD[@]}"; do
    _install_pkg_file "$module" "$BUILD_DIR/$module/packages.txt"
done

# ── 4. Cleanup ──────────────────────────────────────────────────────────
log "Cleaning dnf caches"
dnf5 clean all
rm -rf /var/cache/dnf/* /var/cache/libdnf5/* /var/lib/dnf/*
rm -f /var/log/dnf5.log /var/log/dnf5.librepo.log /var/log/dnf5.rpm.log

log "Packages installed."
