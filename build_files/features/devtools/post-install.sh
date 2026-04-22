#!/usr/bin/env bash
# Install mise system-wide into /usr/local/bin/ — it's not packaged as an RPM
# in Fedora or any COPR that bluefin-dx enables.

set -euo pipefail

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

log "Installing mise from the official binary release"
curl -sSfL https://mise.run | MISE_INSTALL_PATH=/usr/local/bin/mise sh

log "mise installed:"
/usr/local/bin/mise --version
