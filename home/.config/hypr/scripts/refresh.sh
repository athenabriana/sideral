#!/usr/bin/env bash
# Reload Hyprland + restart the AGS bar. Logs AGS output to ~/.local/state/ags.log
# so we can inspect errors after the fact.

LOG="${XDG_STATE_HOME:-$HOME/.local/state}/ags.log"
mkdir -p "$(dirname "$LOG")"

hyprctl reload >/dev/null 2>&1

# Nuke any stale AGS instances (named + anonymous)
ags quit -i bar          >/dev/null 2>&1
pkill -f 'gjs.*ags'      >/dev/null 2>&1

sleep 0.4

# Fresh log on every refresh, keep the previous run as .log.old
[ -f "$LOG" ] && mv "$LOG" "${LOG}.old"
{
    echo "=== AGS start $(date -Iseconds) ==="
} > "$LOG"

setsid ags run ~/.config/ags >> "$LOG" 2>&1 < /dev/null &

notify-send -a "Hyprland" -i view-refresh "Desktop refreshed" "Log: $LOG"
