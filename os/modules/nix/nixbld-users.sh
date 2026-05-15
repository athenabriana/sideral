#!/usr/bin/env bash
set -euo pipefail

NIXBLD_GID="${NIXBLD_GID:-30000}"
NIXBLD_UID_START="${NIXBLD_UID_START:-30001}"
NIXBLD_COUNT="${NIXBLD_COUNT:-32}"

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

log "Creating nixbld group (GID $NIXBLD_GID)..."
if ! getent group nixbld >/dev/null 2>&1; then
    groupadd --system --gid "$NIXBLD_GID" nixbld
fi

log "Creating $NIXBLD_COUNT nixbld users (UIDs $NIXBLD_UID_START–$((NIXBLD_UID_START + NIXBLD_COUNT - 1)))..."
for i in $(seq 1 "$NIXBLD_COUNT"); do
    uid=$((NIXBLD_UID_START + i - 1))
    username="nixbld$i"
    if ! getent passwd "$username" >/dev/null 2>&1; then
        useradd \
            --system \
            --no-create-home \
            --shell /sbin/nologin \
            --uid "$uid" \
            --gid "$NIXBLD_GID" \
            "$username"
    fi
done

log "nixbld users created:"
getent passwd | grep -c '^nixbld'
