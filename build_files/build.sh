#!/usr/bin/env bash
# build.sh — runs inside the Containerfile to do everything in one layer.
#   1. Enable COPR repos we need for Hyprland ecosystem
#   2. rpm-ostree install all packages from packages.txt
#   3. Build astal-gtk4 from source and install into /usr/
#   4. Clean up build deps + repo metadata

set -euo pipefail

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

# ── COPR repos (hyprblue pattern: array + non-fatal fallbacks) ──────────
COPR_REPOS=(
    solopasha/hyprland
    erikreider/SwayNotificationCenter
    che/nerd-fonts
)

log "Enabling COPR repos"
for repo in "${COPR_REPOS[@]}"; do
    if ! dnf5 -y copr enable "$repo" 2>&1; then
        echo "  ⚠ Failed to enable $repo — continuing"
    fi
done

# ── Install all packages in one transaction (single layer) ──────────────
log "Installing packages from packages.txt"
PACKAGES=$(grep -vE '^\s*(#|$)' /ctx/packages.txt | tr '\n' ' ')
dnf5 install -y --setopt=install_weak_deps=False $PACKAGES

# ── Build astal-gtk4 from source ────────────────────────────────────────
log "Building astal-gtk4"
BUILD_DEPS=(meson ninja-build vala gobject-introspection-devel
            gtk4-devel gtk4-layer-shell-devel wayland-protocols-devel
            json-glib-devel git)
dnf5 install -y --setopt=install_weak_deps=False "${BUILD_DEPS[@]}"

git clone --depth 1 https://github.com/Aylur/astal /tmp/astal

for sub in lib/astal/io lib/astal/gtk4; do
    pushd "/tmp/astal/$sub" >/dev/null
    meson setup build --prefix=/usr
    meson compile -C build
    meson install -C build
    popd >/dev/null
done

rm -rf /tmp/astal
dnf5 remove -y "${BUILD_DEPS[@]}"

# ── Disable COPR repos (keep final image metadata clean) ────────────────
log "Disabling COPR repos"
for repo in "${COPR_REPOS[@]}"; do
    dnf5 -y copr disable "$repo" 2>/dev/null || true
done

# ── Final cleanup ───────────────────────────────────────────────────────
log "Cleaning dnf cache"
dnf5 clean all
rm -rf /var/cache/dnf/* /var/cache/libdnf5/* /var/lib/dnf/*

log "Sanity check"
ls -la /usr/lib64/girepository-1.0/Astal-4.0.typelib
ls -la /usr/lib64/libastal-gtk4*.so*

log "Done."
