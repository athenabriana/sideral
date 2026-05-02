#!/usr/bin/env bash
# Register flatpak remotes and preinstall the curated set into
# /var/lib/flatpak at image build time. Manifest + remotes config
# live next to this script (single source of truth — same files
# ship inside the sideral-flatpaks RPM and are consumed by
# sideral-flatpak-install.service for forward-compat self-heal).
#
# ostree factory-seeds /var on first boot, so flatpaks land on the
# user system without a download wait.

set -euo pipefail

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

mod_dir="$(dirname "$0")"
remotes="$mod_dir/src/etc/sideral-flatpak-remotes"
manifest="$mod_dir/src/etc/flatpak-manifest"

[ -r "$remotes" ]  || { echo "remotes file not found at $remotes"; exit 1; }
[ -r "$manifest" ] || { echo "manifest not found at $manifest"; exit 1; }

log "Registering flatpak remotes"
while read -r name url; do
    case "$name" in ""|\#*) continue;; esac
    log "  $name -> $url"
    flatpak remote-add --system --if-not-exists "$name" "$url"
done < "$remotes"

log "Installing curated flatpaks at image build"
while read -r remote ref; do
    case "$remote" in ""|\#*) continue;; esac
    log "  $remote $ref"
    flatpak install --system -y --noninteractive "$remote" "$ref"
done < "$manifest"
