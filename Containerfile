# athens-os — a personal Fedora atomic desktop derived directly from
# ublue-os/silverblue-main. Ships GNOME + tiling-shell, a curated flatpak set
# (Zen Browser + GUI apps), home-manager-driven user layer (mise, vscode, CLI QoL),
# and a narrow RPM layer (docker-ce + compose, gnome extensions + bazaar, fonts).
#
# Local build:    just build (alias for build-local)
# Local rebase:   just rebase
# CI build:       push to main → GH Actions → ghcr.io/<user>/athens-os:latest
# Remote rebase:  rpm-ostree rebase ostree-unverified-registry:ghcr.io/<user>/athens-os:latest
#
# Phase B+C-light layout (athens-copr feature, 2026-04-25): athens-os files
# live under packages/<owner-package>/src/<absolute-image-path>. The Containerfile
# overlays all packages/*/src/ trees instead of COPY system_files /etc. When the
# Copr setup is later activated, this changes to `dnf5 install athens-os-base`.

ARG BASE_IMAGE="ghcr.io/ublue-os/silverblue-main:43"

# Stage 1: scratch carrier for build scripts + package sources — bind-mounted,
# never embedded in final image.
FROM scratch AS ctx
COPY build_files /build_files
COPY packages /packages

# Stage 2: the real image.
FROM ${BASE_IMAGE}

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build_files/build.sh && \
    ostree container commit

# Overlay every athens-os-* sub-package's src/ tree into the image.
# Each packages/<name>/src/ mirrors absolute image paths; cp -a preserves
# permissions, symlinks, and dotfiles. This is the dev-mode equivalent of
# `dnf5 install athens-os-base` — same files land in the same places, just
# without RPM metadata. When Copr is activated this RUN block is replaced
# by a `dnf5 copr enable + install athens-os-base` pair.
RUN --mount=type=bind,from=ctx,source=/packages,target=/ctx-packages \
    for d in /ctx-packages/*/src; do \
        [ -d "$d" ] && cp -a "$d/." /; \
    done && \
    ostree container commit

# Compile dconf local DB from /etc/dconf/db/local.d snippets so GNOME reads them.
RUN dconf update && \
    ostree container commit

# Final bootc sanity check.
RUN bootc container lint
