#!/usr/bin/env bash
# Build astal-gtk4 from source during image build and install into /usr/.
# This fills the gap left by Fedora's astal RPM, which ships only Astal-3.0.typelib.

set -euo pipefail

BUILD_DEPS="meson ninja-build vala gobject-introspection-devel \
            gtk4-devel gtk4-layer-shell-devel wayland-protocols-devel \
            json-glib-devel git"

echo "▶ Installing build deps"
dnf install -y --setopt=install_weak_deps=False $BUILD_DEPS

echo "▶ Cloning Aylur/astal"
git clone --depth 1 https://github.com/Aylur/astal /tmp/astal

echo "▶ Building astal-io (gtk-agnostic core)"
cd /tmp/astal/lib/astal/io
meson setup build --prefix=/usr
meson compile -C build
meson install -C build

echo "▶ Building astal-gtk4 shim"
cd /tmp/astal/lib/astal/gtk4
meson setup build --prefix=/usr
meson compile -C build
meson install -C build

echo "▶ Cleaning up"
rm -rf /tmp/astal
dnf remove -y $BUILD_DEPS
dnf clean all
rm -rf /var/cache/dnf/*

echo "✔ astal-gtk4 installed:"
ls /usr/lib64/girepository-1.0/Astal-4.0.typelib
ls /usr/lib64/libastal-gtk4*.so*
