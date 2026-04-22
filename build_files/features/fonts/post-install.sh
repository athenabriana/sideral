#!/usr/bin/env bash
# Fetch Adobe's Source Sans / Source Serif (latest releases) from GitHub
# and install system-wide. The Fedora RPMs ship older Pro (v3) variants.

set -euo pipefail

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

install_adobe_font() {
    local repo="$1" name="$2"
    local dest="/usr/share/fonts/$name"
    local tmp="/tmp/$name"

    log "[$name] Fetching latest release URL from $repo"
    local url
    url=$(curl -sL "https://api.github.com/repos/$repo/releases/latest" \
          | grep -oP '"browser_download_url": "\K[^"]+_Desktop\.zip')
    [ -n "$url" ] || { echo "Could not resolve $name release URL"; return 1; }
    echo "  $url"

    mkdir -p "$tmp" "$dest"
    curl -sL -o "$tmp/font.zip" "$url"
    unzip -q -o "$tmp/font.zip" -d "$tmp"

    find "$tmp" -name "*.otf" -exec cp {} "$dest/" \;
    chmod 644 "$dest"/*.otf
    rm -rf "$tmp"

    log "[$name] installed ($(ls "$dest" | wc -l) OTFs)"
}

install_adobe_font adobe-fonts/source-serif SourceSerif4
install_adobe_font adobe-fonts/source-sans  SourceSans3

log "Refreshing font cache"
fc-cache -f /usr/share/fonts
