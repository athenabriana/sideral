# Athena OS — personal Bluefin-DX derivative
#
# Build locally:      podman build -t athena-os .
# Push to ghcr.io:    podman push ghcr.io/<USER>/athena-os:latest
# Rebase host:        rpm-ostree rebase ostree-unverified-registry:ghcr.io/<USER>/athena-os:latest

ARG BASE_IMAGE="ghcr.io/ublue-os/bluefin-dx:stable"
FROM ${BASE_IMAGE}

# ── Layer 1: system packages ────────────────────────────────────────────
COPY build_files/install-packages.sh /tmp/install-packages.sh
COPY packages.txt /tmp/packages.txt
RUN chmod +x /tmp/install-packages.sh && /tmp/install-packages.sh && \
    rm /tmp/install-packages.sh /tmp/packages.txt && \
    ostree container commit

# ── Layer 2: build astal-gtk4 from source ───────────────────────────────
COPY build_files/build-astal-gtk4.sh /tmp/build-astal-gtk4.sh
RUN chmod +x /tmp/build-astal-gtk4.sh && /tmp/build-astal-gtk4.sh && \
    rm /tmp/build-astal-gtk4.sh && \
    ostree container commit

# ── Layer 3: flatpak installation manifest (applied on first boot) ──────
COPY files/etc/flatpak-manifest /etc/flatpak-manifest
COPY build_files/flatpak-install.service /etc/systemd/system/flatpak-install.service
RUN systemctl enable flatpak-install.service && \
    ostree container commit

# ── Final housekeeping ──────────────────────────────────────────────────
RUN ostree container commit
