#!/usr/bin/env bash
# Clipboard history picker (cliphist + rofi).
#   no args  → pick → copy
#   delete   → pick → delete entry
#   wipe     → clear all history

set -euo pipefail

case "${1:-pick}" in
    delete)
        sel=$(cliphist list | rofi -dmenu -i -p "Delete clip" \
              -theme-str 'window { width: 640px; } listview { lines: 10; }') || exit 0
        [ -n "$sel" ] && printf '%s\n' "$sel" | cliphist delete
        ;;
    wipe)
        cliphist wipe && notify-send -a "Clipboard" "History cleared"
        ;;
    pick|*)
        sel=$(cliphist list | rofi -dmenu -i -p "Clipboard" \
              -theme-str 'window { width: 640px; } listview { lines: 10; }') || exit 0
        [ -n "$sel" ] && printf '%s\n' "$sel" | cliphist decode | wl-copy
        ;;
esac
