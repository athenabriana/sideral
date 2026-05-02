#!/usr/bin/env bash
# Install GNOME Shell extensions from extensions.gnome.org at image-build time.
# Queries the e.g.o API for the latest compatible .shell-extension.zip for the
# running GNOME Shell version (picked up from the base image), unpacks into
# /usr/share/gnome-shell/extensions/<uuid>/, compiles schemas, and cleans up.
#
# Runs as part of the Containerfile build; the downloaded zips are not kept.

set -euo pipefail

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

EXTENSIONS=(
    "tilingshell@ferrarodomenico.com"
    "rounded-window-corners@fxgn"
)

log "Installing build-time deps (glib2-devel for schema compilation)"
dnf5 install -y --setopt=install_weak_deps=False glib2-devel unzip jq curl

# ── Resolve shell version (e.g. "47") from the base image ──
shell_version="$(gnome-shell --version | awk '{print $3}' | cut -d. -f1)"
log "Target GNOME Shell version: $shell_version"

EXT_ROOT="/usr/share/gnome-shell/extensions"
mkdir -p "$EXT_ROOT"

for uuid in "${EXTENSIONS[@]}"; do
    log "[$uuid] resolving latest for shell $shell_version"
    info_url="https://extensions.gnome.org/extension-info/?uuid=${uuid}&shell_version=${shell_version}"
    info_json="$(curl -sSfL "$info_url")"
    version_tag="$(echo "$info_json" | jq -r '.version_tag // empty')"
    [ -n "$version_tag" ] || { echo "could not resolve version for $uuid at shell $shell_version"; exit 1; }

    download_url="https://extensions.gnome.org/download-extension/${uuid}.shell-extension.zip?version_tag=${version_tag}"
    tmpzip="$(mktemp --suffix=.zip)"
    curl -sSfL -o "$tmpzip" "$download_url"

    dest="$EXT_ROOT/$uuid"
    rm -rf "$dest"
    mkdir -p "$dest"
    unzip -q -o "$tmpzip" -d "$dest"
    rm -f "$tmpzip"

    if [ -d "$dest/schemas" ]; then
        glib-compile-schemas --strict "$dest/schemas"
    fi
    log "[$uuid] installed (tag $version_tag)"
done

# ── Merge schemas into system schema cache so `gsettings` sees them ──
log "Recompiling system schema cache"
glib-compile-schemas --strict /usr/share/glib-2.0/schemas/ || true

log "Removing build-time deps"
dnf5 remove -y glib2-devel unzip jq

log "Done."
