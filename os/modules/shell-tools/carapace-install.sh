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
base="https://github.com/carapace-sh/carapace-bin/releases/latest/download"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

curl -fsSL -o "$tmp/carapace-bin_linux_amd64.tar.gz" "$base/carapace-bin_linux_amd64.tar.gz"
curl -fsSL -o "$tmp/carapace_checksums.txt"          "$base/carapace_checksums.txt"
# Extract the sha256 line for the tarball we downloaded; cd so sha256sum
# finds the file by name (same as starship pattern).
grep "carapace-bin_linux_amd64.tar.gz" "$tmp/carapace_checksums.txt" > "$tmp/SHA256SUMS"
( cd "$tmp" && sha256sum -c SHA256SUMS )
tar -xzf "$tmp/carapace-bin_linux_amd64.tar.gz" -C /usr/bin carapace
chown root:root /usr/bin/carapace
chmod 755 /usr/bin/carapace
