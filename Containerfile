# Athena OS — custom Bluefin-DX derivative with Hyprland + astal-gtk4 + curated CLIs.
#
# Local build:    just build
# Local rebase:   just rebase
# CI build:       push to main → GH Actions → ghcr.io/<user>/athena-os:latest
# Remote rebase:  rpm-ostree rebase ostree-unverified-registry:ghcr.io/<user>/athena-os:latest

ARG BASE_IMAGE="ghcr.io/ublue-os/bluefin-dx:stable"

# Stage 1: scratch carrier for build scripts — bind-mounted, never in final image.
FROM scratch AS ctx
COPY build_files /

# Stage 2: the real image. One RUN does the heavy lifting in a single layer.
FROM ${BASE_IMAGE}

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh && \
    ostree container commit

# System-wide config snippets (mise activation, default toolchain, etc.)
COPY system_files/etc /etc
RUN ostree container commit

# Final bootc sanity check — catches image structure bugs early.
RUN bootc container lint
