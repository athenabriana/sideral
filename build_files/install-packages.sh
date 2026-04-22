#!/usr/bin/env bash
# Install RPMs listed in packages.txt via rpm-ostree.
# Runs inside the Containerfile during image build.

set -euo pipefail

PACKAGES=$(grep -vE '^\s*(#|$)' /tmp/packages.txt | tr '\n' ' ')

if [ -z "$PACKAGES" ]; then
    echo "No packages to install — skipping."
    exit 0
fi

echo "Installing: $PACKAGES"
rpm-ostree install --idempotent --allow-inactive $PACKAGES
