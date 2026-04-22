#!/usr/bin/env bash
# Toggle Hyprland animations on/off. Useful on low battery or slow hardware.
# Prints JSON for Waybar consumption when called with --status.

set -euo pipefail

state=$(hyprctl getoption animations:enabled -j | jq -r '.int')

case "${1:-toggle}" in
    toggle)
        if [ "$state" = "1" ]; then
            hyprctl keyword animations:enabled false >/dev/null
            notify-send -a "Hyprland" -i preferences-desktop-screensaver "Animations disabled"
        else
            hyprctl keyword animations:enabled true  >/dev/null
            notify-send -a "Hyprland" -i preferences-desktop-screensaver "Animations enabled"
        fi
        ;;
    status)
        if [ "$state" = "1" ]; then
            printf '{"text":"","tooltip":"Animations on (click: disable)","class":"on","alt":"on"}\n'
        else
            printf '{"text":"","tooltip":"Animations off (click: enable)","class":"off","alt":"off"}\n'
        fi
        ;;
    *) echo "Usage: $0 [toggle|status]"; exit 2 ;;
esac
