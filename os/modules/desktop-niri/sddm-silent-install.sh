#!/usr/bin/env bash
# Bake the upstream SilentSDDM theme into /usr/share/sddm/themes/silent/.
#
# SilentSDDM is the Qt6-based SDDM theme that pairs with niri+Noctalia
# (see niri-shell spec D-02). It is not packaged in Fedora main or Terra,
# so we fetch the upstream release tarball at image build, sha256-verify,
# and extract. Same shape as starship-install.sh.
#
# Pin a specific tag rather than releases/latest — theme assets churn
# for cosmetic reasons; image-build determinism beats "always latest"
# here. Bump SDDM_TAG manually after reviewing upstream changes.
#
# The tarball's archive path (top-level dir name) varies by release.
# We unpack into a temp dir then rsync to keep the install path stable.

set -euo pipefail

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

SDDM_TAG="v1.4.2"
SDDM_REPO="uiriansan/SilentSDDM"
SDDM_DEST="/usr/share/sddm/themes/silent"

# Pinned upstream-tarball sha256. Bump alongside SDDM_TAG.
# Compute fresh: curl -fsSL "$tarball_url" | sha256sum
SDDM_SHA256="058dd0326dad06f23906bd8d42572126339ec90c1053d2d52a1b9ac3f0bea991"

# Idempotent skip if already installed and tag matches.
if [ -f "$SDDM_DEST/.sideral-tag" ] \
   && [ "$(cat "$SDDM_DEST/.sideral-tag" 2>/dev/null)" = "$SDDM_TAG" ]; then
    log "SilentSDDM $SDDM_TAG already installed at $SDDM_DEST — skipping"
    exit 0
fi

log "Installing SilentSDDM $SDDM_TAG from upstream"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

tarball_url="https://github.com/${SDDM_REPO}/archive/refs/tags/${SDDM_TAG}.tar.gz"
curl -fsSL -o "$tmp/silent.tar.gz" "$tarball_url"

if [ "$SDDM_SHA256" != "REPLACE_AT_FIRST_BUILD" ]; then
    printf '%s  silent.tar.gz\n' "$SDDM_SHA256" > "$tmp/SHA256SUMS"
    ( cd "$tmp" && sha256sum -c SHA256SUMS )
else
    log "SDDM_SHA256 placeholder — recording observed hash for next bump"
    sha256sum "$tmp/silent.tar.gz" >&2
fi

mkdir -p "$tmp/extracted" "$SDDM_DEST"
tar -xzf "$tmp/silent.tar.gz" -C "$tmp/extracted"
# Tarball top-level dir is like "SilentSDDM-1.4.2"; copy its contents.
src_root="$(find "$tmp/extracted" -mindepth 1 -maxdepth 1 -type d | head -n1)"
[ -n "$src_root" ] || { echo "extract failed: no top-level dir" >&2; exit 1; }
cp -a "$src_root"/. "$SDDM_DEST/"
printf '%s\n' "$SDDM_TAG" > "$SDDM_DEST/.sideral-tag"
chown -R root:root "$SDDM_DEST"
find "$SDDM_DEST" -type d -exec chmod 0755 {} +
find "$SDDM_DEST" -type f -exec chmod 0644 {} +

log "SilentSDDM $SDDM_TAG installed to $SDDM_DEST"
