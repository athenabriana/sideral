#!/usr/bin/env bash
# build.sh — orchestrates per-feature install scripts inside the Containerfile.
# Each feature lives in features/<name>/ with:
#   packages.txt       — one RPM per line (required)
#   post-install.sh    — optional script run after packages install

set -euo pipefail

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

FEATURES_DIR="/ctx/features"
FEATURES=(hyprland desktop devtools fonts)

# ── COPR repos (enabled for build, disabled afterward) ─────────────────
# Note: bluefin-dx already ships ublue-os/{packages,staging} + che/nerd-fonts enabled.
COPR_REPOS=(
    sdegler/hyprland                     # hyprland 0.54+ + all hypr* + astal-gtk4 as RPM
    erikreider/SwayNotificationCenter    # swaync (upstream-maintained)
)

log "Enabling COPR repos"
for repo in "${COPR_REPOS[@]}"; do
    if ! dnf5 -y copr enable "$repo" 2>&1; then
        echo "  ⚠ Failed to enable $repo — continuing"
    fi
done

# ── Per-feature install loop ───────────────────────────────────────────
for feature in "${FEATURES[@]}"; do
    feature_dir="$FEATURES_DIR/$feature"
    pkg_file="$feature_dir/packages.txt"

    if [ -f "$pkg_file" ]; then
        packages=$(grep -vE '^\s*(#|$)' "$pkg_file" | tr '\n' ' ')
        if [ -n "$packages" ]; then
            log "[$feature] Installing packages"
            echo "  $packages"
            dnf5 install -y --setopt=install_weak_deps=False $packages
        fi
    fi

    if [ -x "$feature_dir/post-install.sh" ]; then
        log "[$feature] Running post-install"
        "$feature_dir/post-install.sh"
    fi
done

# ── Cleanup ────────────────────────────────────────────────────────────
log "Disabling COPR repos"
for repo in "${COPR_REPOS[@]}"; do
    dnf5 -y copr disable "$repo" 2>/dev/null || true
done

log "Cleaning dnf caches"
dnf5 clean all
rm -rf /var/cache/dnf/* /var/cache/libdnf5/* /var/lib/dnf/*

log "Done."
