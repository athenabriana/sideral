#!/usr/bin/env bash
set -eoux pipefail

IMAGE_REF="ghcr.io/athenabriana/silverfox"
IMAGE_TAG="latest"

useradd -m -G wheel liveuser
passwd -d liveuser

mkdir -p /etc/gdm
cat > /etc/gdm/custom.conf <<'GDM'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=liveuser
WaylandEnable=true
GDM

for unit in \
    rpm-ostreed-automatic.timer \
    rpm-ostree-countme.service \
    bootloader-update.service \
    flatpak-preinstall.service \
    silverfox-flatpak-install.service \
    fwupd-refresh.timer \
    ; do
    systemctl disable "$unit" 2>/dev/null || true
done

dnf install -y \
    libblockdev-btrfs \
    libblockdev-lvm \
    libblockdev-dm \
    anaconda-live \
    pciutils

mkdir -p /etc/anaconda/profile.d
tee /etc/anaconda/profile.d/silverfox.conf <<'EOF'
[Profile]
profile_id = silverfox

[Profile Detection]
os_id = silverfox

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

tee -a /usr/share/anaconda/interactive-defaults.ks <<EOF
%pre --erroronfail --interpreter=/bin/bash
URL="${IMAGE_REF}:${IMAGE_TAG}"
if lspci 2>/dev/null | grep -qiE 'vga.*nvidia|3d.*nvidia|display.*nvidia'; then
    URL="${IMAGE_REF}-nvidia:${IMAGE_TAG}"
fi
echo "ostreecontainer --url=\$URL --transport=registry --no-signature-verification" > /tmp/silverfox-image.ks
%end
%include /tmp/silverfox-image.ks
EOF
