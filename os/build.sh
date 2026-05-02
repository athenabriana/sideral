#!/usr/bin/env bash
# build.sh — orchestrates per-feature RPM installs inside the Containerfile.
#
# Each feature lives in features/<name>/ with:
#   packages.txt       — one RPM per line (optional; # comments allowed)
#   post-install.sh    — optional script, run after packages install
#
# Repo strategy:
#   • Three "persistent" repos are registered here AND shipped under
#     /etc/yum.repos.d/ (via sideral-base) so `rpm-ostree upgrade` can pull
#     new releases between image rebuilds:
#       - docker-ce-stable       (docker-ce + containerd.io)
#       - mise.jdx.dev/rpm       (mise)
#       - packages.microsoft.com (code / VS Code)
#   • The shipped /etc/yum.repos.d/ copies aren't yet on disk during this
#     RUN step (sideral-base is built later inline), so we register each
#     repo from upstream URL here and rely on the shipped copy taking over
#     post-install.
#   • starship is NOT in Fedora main and we're not shipping a third-party
#     COPR for it. Instead, the always-latest upstream binary is fetched
#     from /releases/latest/download (GitHub redirect to most recent
#     release) + verified against the upstream-published sha256 below,
#     and baked into /usr/bin. Each image rebuild pulls the newest
#     release; no version pinning to maintain.
#
# Flatpak strategy:
#   • Two curated remotes are registered system-wide and persist into the
#     image via /var/lib/flatpak/repo/config (ostree factory-seeds /var
#     on first boot):
#       - flathub                 (https://dl.flathub.org/repo/)
#       - fedora                  (oci+https://registry.fedoraproject.org)
#   • The full curated set (Zen Browser + 7 GNOME quality-of-life apps,
#     all from flathub) is installed at image build into /var/lib/flatpak.
#     ISO ships with everything present — no first-boot download wait,
#     works offline. Updates flow via inherited ublue-os-update-services
#     nightly `flatpak update`.
#   • sideral-flatpak-install.service still ships as an idempotent every-
#     boot self-heal: when a future image rebase adds new manifest
#     entries, deployed systems whose /var/lib/flatpak was seeded at an
#     older image pick up the additions on next boot.

set -euo pipefail

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

FEATURES_DIR="/ctx/features"
FEATURES=(cli gnome container fonts gnome-extensions)

# ── Remove inherited base packages we don't ship ────────────────────────
# silverblue-main:43 ships firefox + htop + dconf-editor as part of the
# default ublue-main set. sideral's curated stack replaces these:
#   • firefox  → Zen Browser (Flathub, app.zen_browser.zen)
#   • htop     → Resources (Flathub, net.nokyan.Resources)
#   • dconf-editor → gnome-tweaks for the rare adjustment users actually need
# Remove them here so they don't sit unused on every deployed system.
# Tolerant of upstream renames/drops: only remove what's actually present.
log "Removing inherited base packages we don't ship"
to_remove=()
for pkg in firefox firefox-langpacks htop dconf-editor; do
    rpm -q "$pkg" >/dev/null 2>&1 && to_remove+=("$pkg")
done
if [ ${#to_remove[@]} -gt 0 ]; then
    dnf5 remove -y "${to_remove[@]}"
fi

# ── Register persistent repos for build-time install ────────────────────
log "Registering docker-ce-stable repo"
dnf5 -y config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo

log "Registering mise repo"
dnf5 -y config-manager addrepo --from-repofile=https://mise.jdx.dev/rpm/mise.repo

log "Registering Microsoft VS Code repo"
dnf5 -y config-manager addrepo --from-repofile=https://packages.microsoft.com/yumrepos/vscode/config.repo

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
# path). Together with the cli feature's 12 RPMs, this satisfies all 14
# Requires: of sideral-cli-tools when its inline-built RPM lands later.
log "Installing mise + code from persistent repos"
dnf5 install -y --setopt=install_weak_deps=False mise code

# ── starship binary (not in Fedora main, no COPR) ───────────────────────
# Always-latest: GitHub's /releases/latest/download/<file> redirect resolves
# to the most recent stable release every build. Each image rebuild picks
# up new starship versions automatically — no version pinning to maintain.
# We still verify the tarball against the upstream-published sha256 file
# from the same release (defends against CDN/in-flight corruption; trusts
# the starship project's release pipeline for authenticity).
log "Installing latest starship binary from upstream releases"
starship_base="https://github.com/starship/starship/releases/latest/download"
starship_tmp=$(mktemp -d)
trap 'rm -rf "$starship_tmp"' EXIT
curl -fsSL -o "$starship_tmp/starship.tar.gz"        "$starship_base/starship-x86_64-unknown-linux-musl.tar.gz"
curl -fsSL -o "$starship_tmp/starship.tar.gz.sha256" "$starship_base/starship-x86_64-unknown-linux-musl.tar.gz.sha256"
# Upstream sha256 file is bare hash (no filename), so format it for `sha256sum -c`.
printf '%s  starship.tar.gz\n' "$(awk '{print $1}' "$starship_tmp/starship.tar.gz.sha256")" > "$starship_tmp/SHA256SUMS"
( cd "$starship_tmp" && sha256sum -c SHA256SUMS )
tar -xzf "$starship_tmp/starship.tar.gz" -C /usr/bin starship
chown root:root /usr/bin/starship
chmod 755 /usr/bin/starship
rm -rf "$starship_tmp"
trap - EXIT

# ── Flatpak remotes + curated flatpak set (preinstalled at image build) ─
# Remotes are read from /ctx/packages/sideral-flatpaks/src/etc/sideral-
# flatpak-remotes (single source of truth; same file ships in the RPM
# and is consumed by sideral-flatpak-install.service for forward-compat).
# Manifest is read from the sideral-flatpaks src tree directly — no need
# to wait for the inline-RPM step (which runs in a later RUN layer).
log "Registering flatpak remotes"
remotes_file="/ctx/packages/sideral-flatpaks/src/etc/sideral-flatpak-remotes"
[ -r "$remotes_file" ] || { echo "remotes file not found at $remotes_file"; exit 1; }
while read -r remote_name remote_url; do
    case "$remote_name" in ""|\#*) continue;; esac
    log "  $remote_name -> $remote_url"
    flatpak remote-add --system --if-not-exists "$remote_name" "$remote_url"
done < "$remotes_file"

log "Installing curated flatpaks at image build"
manifest_file="/ctx/packages/sideral-flatpaks/src/etc/flatpak-manifest"
[ -r "$manifest_file" ] || { echo "manifest not found at $manifest_file"; exit 1; }
while read -r remote ref; do
    case "$remote" in ""|\#*) continue;; esac
    log "  $remote $ref"
    flatpak install --system -y --noninteractive "$remote" "$ref"
done < "$manifest_file"

# /etc/os-release is now owned by sideral-base (sideral-rpms feature).
# Lives at packages/sideral-base/src/etc/os-release; the Containerfile's
# inline rpmbuild step builds the RPM after this script runs and installs
# it via `rpm -Uvh --replacefiles` to claim file ownership from
# fedora-release-common.

# ── NVIDIA-variant tweaks ───────────────────────────────────────────────
# silverblue-nvidia:43 already supplies the full nvidia stack inherited
# down to sideral-nvidia: signed kmod-nvidia matched to a versionlocked
# kernel, kargs (rd.driver.blacklist=nouveau, modprobe.blacklist=nouveau,
# nvidia-drm.modeset=1, initcall_blacklist=simpledrm_platform_driver_init)
# at /usr/lib/bootc/kargs.d/00-nvidia.toml, and a dracut force_drivers
# config that bakes nvidia into the initramfs.
#
# What's missing on top — and what bluefin-nvidia adds — is mutter's
# `kms-modifiers` experimental feature. Without it, GNOME on Wayland
# falls back to non-atomic mode-setting on NVIDIA and you get tearing /
# partial-frame glitches even though the driver is loaded correctly.
# Stock GNOME on F43 does NOT enable kms-modifiers by default for
# nvidia-drm. (Also enable scale-monitor-framebuffer for fractional
# scaling — same default-off, same one-line cost to flip on.)
#
# Detect the variant by checking for kmod-nvidia in rpmdb so the same
# build.sh works for both base and nvidia. The dconf snippet is picked
# up by the Containerfile's `dconf update` after the inline RPM step
# installs sideral-dconf's user profile.
if rpm -q kmod-nvidia >/dev/null 2>&1; then
    log "NVIDIA variant detected — enabling mutter kms-modifiers"
    mkdir -p /etc/dconf/db/local.d
    cat > /etc/dconf/db/local.d/50-sideral-nvidia <<'EOF'
# Auto-applied at image build for the sideral-nvidia variant. Without
# kms-modifiers, GNOME's Wayland compositor uses legacy mode-setting on
# NVIDIA and produces visible tearing / partial frames.
[org/gnome/mutter]
experimental-features=['scale-monitor-framebuffer', 'kms-modifiers']
EOF
fi

# ── Regenerate initramfs ────────────────────────────────────────────────
# Defensive end-of-build regen, matching bluefin's pattern. silverblue-
# {main,nvidia}:43 each generate an initramfs at upstream build time and
# nothing in the steps above should invalidate it (we install only
# userspace packages and don't touch kernel modules), but if a future
# package install triggers a kernel post-script that strips nvidia/zfs/
# whatever from the initramfs without rebuilding, this catches it.
# --reproducible + DRACUT_NO_XATTR=1 keep the output deterministic so
# rebuilds with no upstream change produce byte-identical images.
log "Regenerating initramfs"
KERNEL_VERSION="$(rpm -q --queryformat='%{evr}.%{arch}' kernel-core)"
export DRACUT_NO_XATTR=1
/usr/bin/dracut --no-hostonly --kver "$KERNEL_VERSION" --reproducible --add ostree -f "/lib/modules/${KERNEL_VERSION}/initramfs.img"
chmod 0600 "/lib/modules/${KERNEL_VERSION}/initramfs.img"
unset DRACUT_NO_XATTR

# ── Cleanup ─────────────────────────────────────────────────────────────
log "Cleaning dnf caches and logs"
dnf5 clean all
rm -rf /var/cache/dnf/* /var/cache/libdnf5/* /var/lib/dnf/*
rm -f /var/log/dnf5.log /var/log/dnf5.librepo.log /var/log/dnf5.rpm.log

log "Done."
