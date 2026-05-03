#!/usr/bin/env bash
# Bake the latest upstream nushell binary into /usr/bin.
#
# nushell is not in Fedora main repos. We download the upstream release
# tarball, verify sha256, install nu to /usr/bin/nu (symlinked as nushell),
# and place the bundled nu_plugin_* binaries in /usr/bin so that
# nushell-plugins-install.sh can find them via `command -v` without a
# second tarball fetch.

set -euo pipefail

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

log "Installing latest nushell binary from upstream releases"

VERSION=$(curl -fsSL https://api.github.com/repos/nushell/nushell/releases/latest \
    | grep '"tag_name"' | cut -d'"' -f4)

base="https://github.com/nushell/nushell/releases/download/${VERSION}"
tarball="nu-${VERSION}-x86_64-unknown-linux-gnu.tar.gz"
inner="nu-${VERSION}-x86_64-unknown-linux-gnu"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

curl -fsSL -o "$tmp/$tarball"   "$base/$tarball"
curl -fsSL -o "$tmp/SHA256SUMS" "$base/SHA256SUMS"
grep "$tarball" "$tmp/SHA256SUMS" > "$tmp/CHECKSUMS"
( cd "$tmp" && sha256sum -c CHECKSUMS )

tar -xzf "$tmp/$tarball" -C "$tmp"

install -m 755 "$tmp/$inner/nu" /usr/bin/nu
ln -sf nu /usr/bin/nushell

for plugin in "$tmp/$inner"/nu_plugin_*; do
    [ -f "$plugin" ] || continue
    install -m 755 "$plugin" "/usr/bin/$(basename "$plugin")"
done

log "Installed nushell $(nu --version)"
