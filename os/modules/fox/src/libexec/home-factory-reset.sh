#!/usr/bin/env bash
# home-factory-reset.sh — hard wipe + reseed of sideral-managed paths
# under $HOME from /etc/skel. Scope: depth ≤ 2 under $SKEL_DIR.
# SKEL_DIR and HOME overridable via env for tests.
set -euo pipefail

SKEL_DIR="${SKEL_DIR:-/etc/skel}"
# Paths under $HOME to preserve (relative to the skel tree). The nix
# stow package contains the user's flake.nix — wiping it would discard
# the user's declarative config.
SKIP_PATTERNS=(
    ".config/sideral/stow/nix"
)

yes=0
for arg in "$@"; do
    case "$arg" in
        --yes|-y) yes=1 ;;
        *) printf 'error: unknown flag: %s\n' "$arg" >&2; exit 1 ;;
    esac
done

# Enumerate scope paths: top-level files/links + depth-2 children of
# top-level dirs. Stored as paths relative to $SKEL_DIR.
paths=()
while IFS= read -r -d '' top; do
    rel="${top#"$SKEL_DIR"/}"
    if [[ -d "$top" && ! -L "$top" ]]; then
        while IFS= read -r -d '' child; do
            paths+=("$rel/${child##*/}")
        done < <(find "$top" -mindepth 1 -maxdepth 1 -print0)
    else
        paths+=("$rel")
    fi
done < <(find "$SKEL_DIR" -mindepth 1 -maxdepth 1 -print0)

N=${#paths[@]}

if [[ "$yes" -eq 0 && ! -t 0 ]]; then
    echo 'error: no TTY available — use --yes for non-interactive' >&2
    exit 1
fi

if [[ "$yes" -eq 0 ]]; then
    read -r -p "Apply factory reset to $HOME from $SKEL_DIR ($N entries affected). [y/N] " ans
    case "$ans" in
        y|Y|yes|YES) ;;
        *) echo "Cancelled."; exit 0 ;;
    esac
fi

: "${HOME:?HOME must be set}"
reset_count=0
skip_count=0
for p in "${paths[@]}"; do
    skip=0
    for pattern in "${SKIP_PATTERNS[@]}"; do
        if [[ "$p" == "$pattern"* ]]; then
            skip=1
            break
        fi
    done
    if [[ "$skip" -eq 1 ]]; then
        ((skip_count++))
        continue
    fi
    rm -rf "${HOME:?}/$p"
    mkdir -p "$(dirname "$HOME/$p")"
    cp -a "$SKEL_DIR/$p" "$HOME/$p"
    ((reset_count++))
done

echo "Reset $reset_count entries from $SKEL_DIR ($skip_count skipped)."
