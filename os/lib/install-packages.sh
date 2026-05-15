#!/usr/bin/env bash
set -euo pipefail

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

MODULES_DIR="/ctx/modules"
BUILD_DIR="/ctx/build"

MODULES=(cli-tools services kubernetes nix)
BUILD=(fonts nvidia cosmic)

log "Removing inherited base packages"
to_remove=()
for pkg in firefox firefox-langpacks dconf-editor \
           gnome-software gnome-software-rpm-ostree \
           gnome-terminal gnome-terminal-nautilus ptyxis \
           ublue-os-just toolbox distrobox; do
    rpm -q "$pkg" >/dev/null 2>&1 && to_remove+=("$pkg")
done
[ ${#to_remove[@]} -gt 0 ] && dnf5 remove -y "${to_remove[@]}"

log "Staging persistent yum repos"
shopt -s nullglob
for repo_src in "$MODULES_DIR"/*/src/etc/yum.repos.d/*.repo; do
    log "  $(basename "$repo_src")"
    cp "$repo_src" /etc/yum.repos.d/
done
shopt -u nullglob

_install_pkg_file() {
    local label="$1" pkg_file="$2"
    [ -f "$pkg_file" ] || return 0
    local packages
    packages=$(grep -vE '^\s*(#|$)' "$pkg_file" | tr '\n' ' ')
    [ -n "$packages" ] || return 0
    log "[$label] installing"
    echo "  $packages"
    dnf5 install -y --setopt=install_weak_deps=False $packages
}

for module in "${MODULES[@]}"; do
    _install_pkg_file "$module" "$MODULES_DIR/$module/packages.txt"
done
for module in "${BUILD[@]}"; do
    _install_pkg_file "$module" "$BUILD_DIR/$module/packages.txt"
done

log "Cleaning dnf caches"
dnf5 clean all
rm -rf /var/cache/dnf/* /var/cache/libdnf5/* /var/lib/dnf/*
rm -f /var/log/dnf5.log /var/log/dnf5.librepo.log /var/log/dnf5.rpm.log

log "Packages installed."
