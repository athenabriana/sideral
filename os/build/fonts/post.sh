#!/usr/bin/env bash
# Fetch Adobe's Source Sans / Source Serif (latest releases) from GitHub
# and install system-wide. The Fedora RPMs ship older Pro (v3) variants.
#
# Self-contained: installs unzip at the top and removes it at the end,
# so this module doesn't have to ride on whatever ordering the
# orchestrator picks for desktop/extensions.sh (which used to be the
# happenstance source of unzip pre-refactor).

set -euo pipefail

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

# silverblue-main:43 ships curl but NOT unzip. Install temporarily.
log "Installing build-time deps (unzip)"
dnf5 install -y --setopt=install_weak_deps=False unzip
trap 'dnf5 remove -y unzip || true' EXIT

install_adobe_font() {
    local repo="$1" name="$2"
    local dest="/usr/share/fonts/$name"
    local tmp="/tmp/$name"

    log "[$name] Fetching latest release URL from $repo"
    local response url
    # GH API auth via $GITHUB_TOKEN if present (raises rate limit from 60/h to 5000/h);
    # falls back to unauthenticated.
    local auth=()
    [ -n "${GITHUB_TOKEN:-}" ] && auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
    response=$(curl -sL "${auth[@]}" "https://api.github.com/repos/$repo/releases/latest" || true)
    # `|| true` survives empty grep; pipefail would otherwise abort the script
    # before we can print a useful error or fall back.
    url=$(printf '%s' "$response" \
          | grep -oP '"browser_download_url": "\K[^"]+_Desktop\.zip' \
          | head -1 \
          || true)
    if [ -z "$url" ]; then
        echo "WARN: Could not resolve $name release URL (rate limit or asset rename?)."
        echo "      First 400 chars of API response:"
        printf '%s\n' "$response" | head -c 400
        echo
        echo "      Skipping $name; Fedora-shipped Source v3 variants remain available."
        return 0
    fi
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
