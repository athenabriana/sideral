#!/usr/bin/env bash
# Build astal-gtk4 from source — not packaged in any Fedora repo.
# Produces:
#   /usr/lib64/libastal-gtk4*.so*
#   /usr/lib64/girepository-1.0/Astal-4.0.typelib

set -euo pipefail

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

BUILD_DEPS=(meson ninja-build vala gobject-introspection-devel
            gtk4-devel gtk4-layer-shell-devel wayland-protocols-devel
            json-glib-devel git)

log "Installing astal-gtk4 build deps"
dnf5 install -y --setopt=install_weak_deps=False "${BUILD_DEPS[@]}"

log "Cloning Aylur/astal"
git clone --depth 1 https://github.com/Aylur/astal /tmp/astal

for sub in lib/astal/io lib/astal/gtk4; do
    log "Building $sub"
    pushd "/tmp/astal/$sub" >/dev/null
    meson setup build --prefix=/usr
    meson compile -C build
    meson install -C build
    popd >/dev/null
done

log "Cleaning astal-gtk4 build deps"
rm -rf /tmp/astal
dnf5 remove -y "${BUILD_DEPS[@]}"

log "astal-gtk4 installed:"
ls /usr/lib64/girepository-1.0/Astal-4.0.typelib
ls /usr/lib64/libastal-gtk4*.so*
