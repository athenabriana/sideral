#!/usr/bin/env bash
# Hide chromium from the GNOME app grid by patching `NoDisplay=true`
# into its .desktop file. Bluefin uses the same approach to hide
# gnome-system-monitor, etc. — sed-add-key after `[Desktop Entry]`.
#
# Why hide rather than just install: chromium is here for non-GUI use
# (headless automation via puppeteer/playwright, web-app debugging,
# fallback rendering when Zen Browser hits a compatibility issue).
# Surfacing it in the app grid alongside Zen creates "which browser
# do I open?" friction with no upside — the CLI invocation
# (`chromium-browser <url>`) is what we actually want.
#
# Idempotent: if NoDisplay= is already set, leave it; if not, insert.

set -euo pipefail

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

shopt -s nullglob
hidden_count=0
for f in /usr/share/applications/chromium*.desktop; do
    if grep -q '^NoDisplay=true' "$f"; then
        log "[chromium] $(basename "$f") already hidden"
    else
        sed -i '/^\[Desktop Entry\]$/a NoDisplay=true' "$f"
        log "[chromium] hid $(basename "$f")"
        hidden_count=$((hidden_count + 1))
    fi
done
shopt -u nullglob

if [ $hidden_count -eq 0 ]; then
    log "[chromium] no .desktop files needed patching"
fi
