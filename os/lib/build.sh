#!/usr/bin/env bash
# build.sh — image-build orchestrator. Iterates os/modules/<name>/ and
# applies each module's build-time concerns:
#
#   1. Inherited-base prune (firefox/htop/dconf-editor)
#   2. Stage every module's persistent /etc/yum.repos.d/*.repo so
#      build-time package installs can resolve from those repos. The
#      same files ship via the sideral-* RPMs in the inline-RPM step
#      later, so the staged copies become the permanent ones.
#   3. Per-module loop:
#        - dnf5 install <module>/packages.txt (Fedora-main + persistent repos)
#        - run any *.sh scripts in <module>/ in lexical order
#   4. Defensive end-of-build initramfs regen (matches bluefin pattern;
#      catches kernel post-script invalidation of the inherited
#      initramfs even though sideral installs only userspace packages).
#   5. Cleanup.
#
# Module ORDER list lives at the top of this file. Order matters — see
# the comment next to MODULES for what depends on what.
#
# Modules without packages.txt or *.sh are silently skipped here (they
# only contribute via the inline RPM build later — e.g. signing,
# shell-init, meta).

set -euo pipefail

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

MODULES_DIR="/ctx/modules"

# Order: shell-tools first because sideral-cli-tools (built later in
# the inline RPM step) Requires: every binary installed by shell-tools'
# packages.txt. desktop and containers can come in any order. fonts
# late so the font cache rebuild post-script picks up everything that
# was installed earlier. flatpaks near the end so all sideral RPM
# requirements are present by the time we install the curated set.
# nvidia last so the variant tweaks land on the final tree.
MODULES=(shell-tools desktop containers kubernetes fonts flatpaks nvidia)

# ── 1. Remove inherited base packages we don't ship ─────────────────────
# silverblue-{main,nvidia}:43 ship firefox + htop + dconf-editor as part
# of the default ublue-main set. sideral's curated stack replaces these:
#   • firefox  → Zen Browser (Flathub)
#   • htop     → Resources (Flathub)
#   • dconf-editor → gnome-tweaks for the rare adjustment users actually need
# Tolerant of upstream renames: only remove what's actually present.
log "Removing inherited base packages we don't ship"
to_remove=()
for pkg in firefox firefox-langpacks htop dconf-editor; do
    rpm -q "$pkg" >/dev/null 2>&1 && to_remove+=("$pkg")
done
if [ ${#to_remove[@]} -gt 0 ]; then
    dnf5 remove -y "${to_remove[@]}"
fi

# ── 2. Stage persistent yum repos from every module ─────────────────────
# Each module that ships a /etc/yum.repos.d/X.repo file (in its src/
# tree, destined for the sideral-* RPM that owns it) puts a copy into
# the live /etc/yum.repos.d/ before we run dnf5 install. After the
# inline RPM step lands later, the same files become RPM-owned.
log "Staging persistent yum repos from modules"
shopt -s nullglob
for repo_src in "$MODULES_DIR"/*/src/etc/yum.repos.d/*.repo; do
    log "  $(basename "$repo_src")"
    cp "$repo_src" /etc/yum.repos.d/
done
shopt -u nullglob

# ── 3. Per-module loop ──────────────────────────────────────────────────
for module in "${MODULES[@]}"; do
    module_dir="$MODULES_DIR/$module"
    [ -d "$module_dir" ] || { log "[$module] no module dir at $module_dir, skipping"; continue; }

    pkg_file="$module_dir/packages.txt"
    if [ -f "$pkg_file" ]; then
        packages=$(grep -vE '^\s*(#|$)' "$pkg_file" | tr '\n' ' ')
        if [ -n "$packages" ]; then
            log "[$module] installing"
            echo "  $packages"
            dnf5 install -y --setopt=install_weak_deps=False $packages
        fi
    fi

    # Run any *.sh scripts in lexical order. install.sh / *-install.sh /
    # apply.sh / post.sh / extensions.sh — the convention is one script
    # per concern within a module, named for what it does. Scripts must
    # be committed with the executable bit set (git update-index
    # --chmod=+x); /ctx is bind-mounted read-only here so we can't
    # chmod at runtime.
    shopt -s nullglob
    for script in "$module_dir"/*.sh; do
        log "[$module] running $(basename "$script")"
        "$script"
    done
    shopt -u nullglob
done

# ── 4. Regenerate initramfs ────────────────────────────────────────────
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

# ── 5. Cleanup ─────────────────────────────────────────────────────────
log "Cleaning dnf caches and logs"
dnf5 clean all
rm -rf /var/cache/dnf/* /var/cache/libdnf5/* /var/lib/dnf/*
rm -f /var/log/dnf5.log /var/log/dnf5.librepo.log /var/log/dnf5.rpm.log

log "Done."
