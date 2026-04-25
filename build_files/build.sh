#!/usr/bin/env bash
# build.sh — orchestrates per-feature RPM installs inside the Containerfile.
#
# Each feature lives in features/<name>/ with:
#   packages.txt       — one RPM per line (optional; # comments allowed)
#   post-install.sh    — optional script, run after packages install
#
# Repo strategy:
#   • The docker-ce-stable repo is registered here AND shipped as
#     /etc/yum.repos.d/docker-ce.repo so `rpm-ostree upgrade` can pull new
#     Docker releases between image rebuilds.
#   • ublue-os/packages COPR stays enabled in the shipped image to source
#     bazaar (GNOME app store) and any future ublue-shared RPMs.
#   • Any other build-time repos would be disabled before image commit.

set -euo pipefail

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

# ── Pinned nix-installer (upstream CppNix, ostree planner) ──────────────
# Staged at /usr/libexec/nix-installer; invoked by athens-nix-install.service
# on first boot. Upstream repo was renamed from experimental-nix-installer
# to nix-installer (same code, no longer "experimental"); both URLs work.
NIX_INSTALLER_VERSION="2.34.5"
NIX_INSTALLER_URL="https://github.com/NixOS/nix-installer/releases/download/${NIX_INSTALLER_VERSION}/nix-installer-x86_64-linux"

log "Staging nix-installer ${NIX_INSTALLER_VERSION} at /usr/libexec/nix-installer"
curl -sSfL "$NIX_INSTALLER_URL" -o /usr/libexec/nix-installer
chmod 0755 /usr/libexec/nix-installer

FEATURES_DIR="/ctx/features"
FEATURES=(gnome container fonts gnome-extensions)

# ── COPRs that stay enabled in the shipped image (for `rpm-ostree upgrade`) ──
# Universal Blue's curated packages repo — source of `bazaar` (GNOME app
# store) and other ublue-specific RPMs. Same COPR used by Bazzite/Aurora.
PERSISTENT_COPRS=(
    ublue-os/packages
)

# ── Enable persistent COPRs ─────────────────────────────────────────────
log "Enabling persistent COPRs"
for repo in "${PERSISTENT_COPRS[@]}"; do
    dnf5 -y copr enable "$repo"
done

# ── Register docker-ce-stable repo for build-time install ───────────────
# (The same repo file is also shipped under system_files/ for post-boot upgrades.)
log "Registering docker-ce-stable repo"
dnf5 -y config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo

# ── Per-feature install loop ────────────────────────────────────────────
for feature in "${FEATURES[@]}"; do
    feature_dir="$FEATURES_DIR/$feature"
    pkg_file="$feature_dir/packages.txt"

    if [ -f "$pkg_file" ]; then
        packages=$(grep -vE '^\s*(#|$)' "$pkg_file" | tr '\n' ' ')
        if [ -n "$packages" ]; then
            log "[$feature] Installing packages"
            echo "  $packages"
            # --allowerasing lets containerd.io replace Fedora's containerd.
            dnf5 install -y --allowerasing --setopt=install_weak_deps=False $packages
        fi
    fi

    if [ -x "$feature_dir/post-install.sh" ]; then
        log "[$feature] Running post-install"
        "$feature_dir/post-install.sh"
    fi
done

# /etc/os-release is now owned by athens-os-base (athens-copr feature).
# Lives at packages/athens-os-base/src/etc/os-release; the Containerfile's
# packages/*/src/ overlay step lays it down after this script runs.

# ── Cleanup ─────────────────────────────────────────────────────────────
log "Cleaning dnf caches"
dnf5 clean all
rm -rf /var/cache/dnf/* /var/cache/libdnf5/* /var/lib/dnf/*

log "Done."
