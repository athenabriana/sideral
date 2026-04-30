#!/usr/bin/env bash
# titanoboa hook-post-rootfs: install Anaconda into the live rootfs so the
# ISO ships with a working "Install to disk" flow. Without this the ISO
# boots fine as a live env but has no installer.
#
# Adapted from projectbluefin/iso/iso_files/configure_iso_anaconda.sh
# (the canonical Bluefin pattern). Trimmed of ublue-specific service
# disables, secureboot key enrollment, and branding clones we don't have.
set -eoux pipefail

IMAGE_REF="ghcr.io/athenabriana/athens-os"
IMAGE_TAG="latest"

# ── Live env: anaconda first in dock, suspend off ────────────────────
mkdir -p /usr/share/glib-2.0/schemas
tee /usr/share/glib-2.0/schemas/zz2-athens-os-installer.gschema.override <<'EOF'
[org.gnome.shell]
welcome-dialog-last-shown-version='4294967295'
favorite-apps=['anaconda.desktop', 'org.gnome.Nautilus.desktop', 'org.mozilla.firefox.desktop']

[org.gnome.settings-daemon.plugins.power]
sleep-inactive-ac-type='nothing'
sleep-inactive-battery-type='nothing'
sleep-inactive-ac-timeout=0
sleep-inactive-battery-timeout=0

[org.gnome.desktop.session]
idle-delay=uint32 0
EOF
glib-compile-schemas /usr/share/glib-2.0/schemas

# ── Disable services that misbehave in the live env ─────────────────
# These all assume rpm-ostree state, network metadata services, or
# first-boot user setup — none of which apply to a squashfs-backed
# liveuser session. `|| true` because not every service exists in
# every athens-os build (e.g. flatpak-preinstall.service is from
# athens-os-flatpaks but may be renamed in future).
for unit in \
    rpm-ostreed-automatic.timer \
    rpm-ostree-countme.service \
    bootloader-update.service \
    flatpak-preinstall.service \
    athens-flatpak-install.service \
    fwupd-refresh.timer \
    ; do
    systemctl disable "$unit" 2>/dev/null || true
done

# Don't autostart gnome-software in the live env — anaconda is the
# only software op that matters here
rm -f /etc/xdg/autostart/org.gnome.Software.desktop
tee /usr/share/gnome-shell/search-providers/org.gnome.Software-search-provider.ini <<'EOF'
DefaultDisabled=true
EOF

# ── Anaconda install ─────────────────────────────────────────────────
# silverblue-main:43 already ships fedora-logos, so the Bluefin
# generic-logos→fedora-logos rpmdb swap (rhbz#2433186) doesn't apply here.
dnf install -y \
    libblockdev-btrfs \
    libblockdev-lvm \
    libblockdev-dm \
    anaconda-live \
    firefox

# ── Anaconda profile ─────────────────────────────────────────────────
mkdir -p /etc/anaconda/profile.d
tee /etc/anaconda/profile.d/athens-os.conf <<'EOF'
[Profile]
profile_id = athens-os

[Profile Detection]
os_id = athens-os

[Network]
default_on_boot = FIRST_WIRED_WITH_LINK

[Bootloader]
efi_dir = fedora
menu_auto_hide = True

[Storage]
default_scheme = BTRFS
btrfs_compression = zstd:1
default_partitioning =
    /     (min 1 GiB, max 70 GiB)
    /home (min 500 MiB, free 50 GiB)
    /var  (btrfs)

[User Interface]
hidden_spokes =
    NetworkSpoke
    PasswordSpoke
    UserSpoke
hidden_webui_pages =
    anaconda-screen-accounts

[Localization]
use_geolocation = False
EOF

# Interactive kickstart: pull our published bootc image and install it.
# --no-signature-verification because we don't ship a policy.json yet —
# tracked under the image-ops feature; once that lands, drop this flag
# and add a `bootc switch --enforce-container-sigpolicy` post-script.
tee -a /usr/share/anaconda/interactive-defaults.ks <<EOF
ostreecontainer --url=${IMAGE_REF}:${IMAGE_TAG} --transport=registry --no-signature-verification
EOF
