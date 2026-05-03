#!/usr/bin/env bash
# Bake the latest upstream carapace binary into /usr/bin.
#
# carapace-bin is not in Fedora main and we don't want a COPR in the
# build chain. /releases/latest/download is GitHub's redirect to the
# most recent stable release — each image rebuild picks up the newest
# version automatically. We verify against the upstream-published
# sha256 from the same release (defends against CDN/in-flight
# corruption; trusts the carapace project's release pipeline for
# authenticity).

set -euo pipefail

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

log "Installing latest carapace binary from upstream releases"

# carapace-bin switched to versioned filenames (e.g. carapace-bin_1.6.5_linux_amd64.tar.gz).
# Resolve the latest tag, strip the leading 'v', then build asset names.
TAG=$(curl -fsSL https://api.github.com/repos/carapace-sh/carapace-bin/releases/latest \
    | grep '"tag_name"' | cut -d'"' -f4)
VERSION="${TAG#v}"

base="https://github.com/carapace-sh/carapace-bin/releases/download/${TAG}"
tarball="carapace-bin_${VERSION}_linux_amd64.tar.gz"
checksums="carapace-bin_${VERSION}_checksums.txt"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

curl -fsSL -o "$tmp/$tarball"    "$base/$tarball"
curl -fsSL -o "$tmp/$checksums"  "$base/$checksums"
grep "$tarball" "$tmp/$checksums" > "$tmp/SHA256SUMS"
( cd "$tmp" && sha256sum -c SHA256SUMS )
tar -xzf "$tmp/$tarball" -C /usr/bin carapace
chown root:root /usr/bin/carapace
chmod 755 /usr/bin/carapace
