#!/usr/bin/env bash
# titanoboa hook-post-rootfs: install Anaconda into the installer rootfs.
set -eoux pipefail

IMAGE_REF="ghcr.io/athenabriana/sideral"
IMAGE_TAG="latest"

# ── Disable services that don't apply in the installer env ──────────
for unit in \
    rpm-ostreed-automatic.timer \
    rpm-ostree-countme.service \
    bootloader-update.service \
    flatpak-preinstall.service \
    sideral-flatpak-install.service \
    fwupd-refresh.timer \
    ; do
    systemctl disable "$unit" 2>/dev/null || true
done

# ── Anaconda install ─────────────────────────────────────────────────
dnf install -y \
    libblockdev-btrfs \
    libblockdev-lvm \
    libblockdev-dm \
    anaconda-live \
    pciutils

# ── Anaconda profile ─────────────────────────────────────────────────
# All classic spokes stay visible — Network is required because the
# kickstart pulls the container image from ghcr.io at install time.
mkdir -p /etc/anaconda/profile.d
tee /etc/anaconda/profile.d/sideral.conf <<'EOF'
[Profile]
profile_id = sideral

[Profile Detection]
os_id = sideral

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

[Password Policies]
root = quality 1, length 1, allow-empty False
user = quality 1, length 1, allow-empty False
luks = quality 1, length 1, allow-empty False

[Localization]
use_geolocation = False
EOF

# ── Kickstart: GPU detection → pull matching image variant ───────────
# The ISO carries no image bytes. The %pre script detects NVIDIA at
# install time and selects sideral-nvidia; everything else gets sideral.
# --no-signature-verification: tracked in image-ops feature; drop once
# sigstore policy is wired up.
tee -a /usr/share/anaconda/interactive-defaults.ks <<EOF
%pre --erroronfail --interpreter=/bin/bash
URL="${IMAGE_REF}:${IMAGE_TAG}"
if lspci 2>/dev/null | grep -qiE 'vga.*nvidia|3d.*nvidia|display.*nvidia'; then
    URL="${IMAGE_REF}-nvidia:${IMAGE_TAG}"
fi
echo "ostreecontainer --url=\$URL --transport=registry --no-signature-verification" > /tmp/sideral-image.ks
%end
%include /tmp/sideral-image.ks
EOF
