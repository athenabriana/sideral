# athens-os — a personal Fedora atomic desktop derived directly from
# ublue-os/silverblue-main. Ships GNOME + tiling-shell, a curated flatpak set
# (browser + GUI apps), home-manager-driven user layer (mise, vscode, CLI QoL),
# and a surgical RPM layer (docker-ce + compose, gnome extensions + bazaar, dev
# + kernel-debug stack, fonts).
#
# Local build:    just build
# Local rebase:   just rebase
# CI build:       push to main → GH Actions → ghcr.io/<user>/athens-os:latest
# Remote rebase:  rpm-ostree rebase ostree-unverified-registry:ghcr.io/<user>/athens-os:latest

ARG BASE_IMAGE="ghcr.io/ublue-os/silverblue-main:43"

# Stage 1: scratch carrier for build scripts — bind-mounted, never in final image.
FROM scratch AS ctx
COPY build_files /

# Stage 2: the real image.
FROM ${BASE_IMAGE}

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh && \
    ostree container commit

# System-wide config overlay: dconf profile + local.d snippets, yum repo files
# (vscode, docker-ce), systemd units (flatpak-install, mise, vscode), flatpak manifest.
COPY system_files/etc /etc
COPY system_files/usr /usr

# User defaults — /etc/skel is copied into new users' home on account creation.
# `just apply-home` updates an existing user's live ~/.config from the repo.
COPY home /etc/skel

# Compile dconf local DB from /etc/dconf/db/local.d snippets so GNOME reads them.
RUN dconf update && \
    ostree container commit

# Final bootc sanity check.
RUN bootc container lint
