#!/usr/bin/env bash
# Screenshot menu — rofi-driven.
#   no args  → show menu
#   region   → select area → clipboard
#   region-edit → select area → swappy editor
#   region-save → select area → ~/Pictures/Screenshots/
#   window   → pick window → clipboard
#   full     → whole screen → clipboard
#   full-save → whole screen → file
#   delay    → 5s countdown → full → file

set -euo pipefail

SAVE_DIR="${HOME}/Pictures/Screenshots"
mkdir -p "$SAVE_DIR"
stamp() { date +'%Y-%m-%d_%H%M%S'; }
notify() { notify-send -a "Screenshot" -i camera-photo "$@"; }

save_path() { printf '%s/screenshot_%s.png' "$SAVE_DIR" "$(stamp)"; }

to_clipboard() { wl-copy --type image/png; }

do_region()      { grim -g "$(slurp -d)" - | to_clipboard && notify "Region copied"; }
do_region_save() { f=$(save_path); grim -g "$(slurp -d)" "$f" && notify "Saved" "$f" && xdg-open "$(dirname "$f")" >/dev/null 2>&1 || true; }
do_region_edit() { grim -g "$(slurp -d)" - | swappy -f - ; }
do_window()      { hyprshot -m window -z -o "$SAVE_DIR" --clipboard-only && notify "Window copied"; }
do_full()        { grim - | to_clipboard && notify "Full screen copied"; }
do_full_save()   { f=$(save_path); grim "$f" && notify "Saved" "$f"; }
do_delay()       { for i in 5 4 3 2 1; do notify -t 900 "Screenshot in ${i}s"; sleep 1; done; do_full_save; }

case "${1:-menu}" in
    region)      do_region ;;
    region-save) do_region_save ;;
    region-edit) do_region_edit ;;
    window)      do_window ;;
    full)        do_full ;;
    full-save)   do_full_save ;;
    delay)       do_delay ;;
    menu)
        choice=$(printf '%s\n' \
            "  Region  →  clipboard" \
            "  Region  →  save" \
            "  Region  →  edit" \
            "  Window  →  clipboard" \
            "  Full    →  clipboard" \
            "  Full    →  save" \
            "  Full    →  5s delay" \
            | rofi -dmenu -i -p "Screenshot" -theme-str 'window { width: 420px; }')
        case "$choice" in
            *Region*clipboard) do_region ;;
            *Region*save)      do_region_save ;;
            *Region*edit)      do_region_edit ;;
            *Window*)          do_window ;;
            *Full*clipboard)   do_full ;;
            *Full*save)        do_full_save ;;
            *delay*)           do_delay ;;
        esac
        ;;
    *) echo "Usage: $0 [region|region-save|region-edit|window|full|full-save|delay|menu]"; exit 2 ;;
esac
