#!/usr/bin/env bash
# build-srpm.sh — generate an SRPM for one athens-os-* sub-package.
#
# Reads packages/<pkg>/<pkg>.spec, optionally tarballs packages/<pkg>/src/
# if it exists, and runs `rpmbuild -bs` with the version + git-sha
# stamped in via macro defines.
#
# Usage:    scripts/build-srpm.sh <package-name> [version]
#
# Default version: $(date -u +%Y%m%d).${GITHUB_RUN_NUMBER:-0}
#                  e.g. 20260424.42 in CI, 20260424.0 locally.
#
# Output:   path to the produced .src.rpm, printed on stdout, AND copied
#           to <repo-root>/_build/ for the workflow to pick up.

set -euo pipefail

PKG="${1:?usage: build-srpm.sh <package-name> [version]}"
VERSION="${2:-$(date -u +%Y%m%d).${GITHUB_RUN_NUMBER:-0}}"

REPO="$(git rev-parse --show-toplevel)"
PKGDIR="${REPO}/packages/${PKG}"
SPEC="${PKGDIR}/${PKG}.spec"
SRCDIR="${PKGDIR}/src"

[ -f "$SPEC" ] || { echo "spec not found: $SPEC" >&2; exit 1; }

# Private rpmbuild tree under a tmpdir — keeps repo clean.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

TOPDIR="$TMP/rpmbuild"
mkdir -p "$TOPDIR"/{SOURCES,SPECS,BUILD,SRPMS}

# Stage tarball iff src/ exists. Meta-packages (no src/) skip Source0.
if [ -d "$SRCDIR" ]; then
    STAGE="$TMP/${PKG}-${VERSION}"
    mkdir -p "$STAGE"
    # -a preserves perms, symlinks, dotfiles. The "/." form copies
    # contents (not the dir itself) into STAGE.
    cp -a "$SRCDIR/." "$STAGE/"
    (cd "$TMP" && tar czf "${PKG}-${VERSION}.tar.gz" "${PKG}-${VERSION}")
    cp "$TMP/${PKG}-${VERSION}.tar.gz" "$TOPDIR/SOURCES/"
fi

cp "$SPEC" "$TOPDIR/SPECS/"

SHA="$(git -C "$REPO" rev-parse --short HEAD)"

rpmbuild -bs \
    --define "_topdir $TOPDIR" \
    --define "_athens_version ${VERSION}" \
    --define "_athens_sha ${SHA}" \
    --define "dist .fc43" \
    "$TOPDIR/SPECS/$(basename "$SPEC")" >&2

# Find and publish the produced SRPM.
SRPM="$(find "$TOPDIR/SRPMS" -name '*.src.rpm' -print -quit)"
[ -n "$SRPM" ] || { echo "rpmbuild produced no SRPM under $TOPDIR/SRPMS" >&2; exit 1; }

mkdir -p "$REPO/_build"
cp "$SRPM" "$REPO/_build/"

# stdout = path to the SRPM (for workflows / scripts that pipe).
echo "$REPO/_build/$(basename "$SRPM")"
