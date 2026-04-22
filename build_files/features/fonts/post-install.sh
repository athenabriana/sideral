#!/usr/bin/env bash
# Download Source Serif 4 (latest release) from Adobe's GitHub and install
# system-wide into /usr/share/fonts/SourceSerif4/. Fedora's RPM ships v3.

set -euo pipefail

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

TMP=/tmp/ss4
DEST=/usr/share/fonts/SourceSerif4

log "Fetching latest Source Serif 4 release URL"
URL=$(curl -sL https://api.github.com/repos/adobe-fonts/source-serif/releases/latest \
    | grep -oP '"browser_download_url": "\K[^"]+_Desktop\.zip')

[ -n "$URL" ] || { echo "Could not resolve Source Serif release URL"; exit 1; }
log "URL: $URL"

mkdir -p "$TMP" "$DEST"
curl -sL -o "$TMP/ss4.zip" "$URL"
unzip -q -o "$TMP/ss4.zip" -d "$TMP"

log "Installing OTFs"
find "$TMP" -name "*.otf" -exec cp {} "$DEST/" \;
chmod 644 "$DEST"/*.otf
rm -rf "$TMP"

log "Refreshing font cache"
fc-cache -f "$DEST"

log "Source Serif 4 installed:"
ls "$DEST" | head -5
echo "  … ($(ls "$DEST" | wc -l) files total)"
