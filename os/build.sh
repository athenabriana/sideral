#!/usr/bin/env bash
# build.sh — orchestrates per-feature RPM installs inside the Containerfile.
#
# Each feature lives in features/<name>/ with:
#   packages.txt       — one RPM per line (optional; # comments allowed)
#   post-install.sh    — optional script, run after packages install
#
# Repo strategy:
#   • Four "persistent" repos are registered here AND shipped under
#     /etc/yum.repos.d/ (via sideral-base) so `rpm-ostree upgrade` can pull
#     new releases between image rebuilds:
#       - docker-ce-stable       (docker-ce + containerd.io)
#       - mise.jdx.dev/rpm       (mise)
#       - packages.microsoft.com (code / VS Code)
#       - copr atim/starship     (starship; not in Fedora main)
#   • The shipped /etc/yum.repos.d/ copies aren't yet on disk during this
#     RUN step (sideral-base is built later inline), so we register each
#     repo from upstream URL here and rely on the shipped copy taking over
#     post-install.

set -euo pipefail

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

FEATURES_DIR="/ctx/features"
FEATURES=(cli gnome container fonts gnome-extensions)

# ── Register persistent repos for build-time install ────────────────────
log "Registering docker-ce-stable repo"
dnf5 -y config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo

log "Registering mise repo"
dnf5 -y config-manager addrepo --from-repofile=https://mise.jdx.dev/rpm/mise.repo

log "Registering Microsoft VS Code repo"
dnf5 -y config-manager addrepo --from-repofile=https://packages.microsoft.com/yumrepos/vscode/config.repo

log "Registering atim/starship COPR (starship not in Fedora main)"
dnf5 -y config-manager addrepo --from-repofile=https://copr.fedorainfracloud.org/coprs/atim/starship/repo/fedora-43/atim-starship-fedora-43.repo

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

# ── mise + code from non-Fedora persistent repos ────────────────────────
# Listed separately because they don't live in any features/*/packages.txt
# (those are reserved for Fedora-main packages that share the standard install
# path). Together with the cli feature's 13 RPMs, this satisfies all 15
# Requires: of sideral-cli-tools when its inline-built RPM lands later.
log "Installing mise + code from persistent repos"
dnf5 install -y --setopt=install_weak_deps=False mise code

# /etc/os-release is now owned by sideral-base (sideral-rpms feature).
# Lives at packages/sideral-base/src/etc/os-release; the Containerfile's
# inline rpmbuild step builds the RPM after this script runs and installs
# it via `rpm -Uvh --replacefiles` to claim file ownership from
# fedora-release-common.

# ── Cleanup ─────────────────────────────────────────────────────────────
log "Cleaning dnf caches"
dnf5 clean all
rm -rf /var/cache/dnf/* /var/cache/libdnf5/* /var/lib/dnf/*

log "Done."
