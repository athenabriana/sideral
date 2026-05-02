#!/usr/bin/env bash
# Bake the latest upstream starship binary into /usr/bin.
#
# starship is not in Fedora main and we don't want a third-party COPR
# in the build chain. /releases/latest/download is GitHub's redirect
# to the most recent stable release — each image rebuild picks up the
# newest version automatically. We still verify the tarball against
# the upstream-published sha256 from the same release (defends against
# CDN/in-flight corruption; trusts the starship project's release
# pipeline for authenticity).

set -euo pipefail

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

log "Installing latest starship binary from upstream releases"
base="https://github.com/starship/starship/releases/latest/download"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

curl -fsSL -o "$tmp/starship.tar.gz"        "$base/starship-x86_64-unknown-linux-musl.tar.gz"
curl -fsSL -o "$tmp/starship.tar.gz.sha256" "$base/starship-x86_64-unknown-linux-musl.tar.gz.sha256"
# Upstream sha256 file is bare hash (no filename), reformat for `sha256sum -c`.
printf '%s  starship.tar.gz\n' "$(awk '{print $1}' "$tmp/starship.tar.gz.sha256")" > "$tmp/SHA256SUMS"
( cd "$tmp" && sha256sum -c SHA256SUMS )
tar -xzf "$tmp/starship.tar.gz" -C /usr/bin starship
chown root:root /usr/bin/starship
chmod 755 /usr/bin/starship
