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

# ── Anaconda install ─────────────────────────────────────────────────
# anaconda-live needs fedora-logos but it conflicts with the
# generic-logos that silverblue ships. Swap in rpmdb only — the actual
# files don't matter for the live env. (rhbz#2433186)
rpm --erase --nodeps --justdb generic-logos || true
dnf download fedora-logos
rpm -i --justdb fedora-logos*.rpm
rm -f fedora-logos*.rpm

dnf install -y \
    libblockdev-btrfs \
    libblockdev-lvm \
    libblockdev-dm \
    anaconda-live \
    firefox

rpm --erase --nodeps --justdb fedora-logos || true

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
