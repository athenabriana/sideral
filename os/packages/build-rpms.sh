#!/usr/bin/env bash
# build-rpms.sh — build every sideral-* binary RPM inline.
#
# Reads packages/<pkg>/<pkg>.spec for each subdir, tarballs packages/<pkg>/src/
# as Source0, runs `rpmbuild -bb` with version + git-sha stamped via macros,
# emits the resulting .rpm files under <topdir>/RPMS/noarch/.
#
# Usage:    packages/build-rpms.sh <packages-dir> <output-topdir> [version]
#
# Default version: $_SIDERAL_VERSION env, else "0.0.0.dev".
#                  CI sets _SIDERAL_VERSION="$(date -u +%Y%m%d).${GITHUB_RUN_NUMBER}".
#
# Output:   <output-topdir>/RPMS/noarch/sideral-*.rpm

set -euo pipefail

PKG_ROOT="${1:?usage: build-rpms.sh <packages-dir> <output-topdir> [version]}"
TOPDIR="${2:?usage: build-rpms.sh <packages-dir> <output-topdir> [version]}"
VERSION="${3:-${_SIDERAL_VERSION:-0.0.0.dev}}"

[ -d "$PKG_ROOT" ] || { echo "packages dir not found: $PKG_ROOT" >&2; exit 1; }

mkdir -p "$TOPDIR"/{SOURCES,SPECS,BUILD,BUILDROOT,RPMS}

for pkgdir in "$PKG_ROOT"/*/; do
    pkg="$(basename "$pkgdir")"
    spec="$pkgdir/$pkg.spec"
    src="$pkgdir/src"

    [ -f "$spec" ] || { echo "skip $pkg: no spec" >&2; continue; }

    if [ -d "$src" ]; then
        # Tarball src/ as <pkg>-<version>/<absolute-path-tree> for %setup -q.
        stage="$TOPDIR/_stage/$pkg-$VERSION"
        mkdir -p "$stage"
        cp -a "$src/." "$stage/"
        ( cd "$TOPDIR/_stage" && tar czf "$TOPDIR/SOURCES/$pkg-$VERSION.tar.gz" "$pkg-$VERSION" )
        rm -rf "$stage"
    fi

    cp "$spec" "$TOPDIR/SPECS/"

    rpmbuild -bb \
        --define "_topdir $TOPDIR" \
        --define "_sideral_version $VERSION" \
        --define "dist .fc43" \
        "$TOPDIR/SPECS/$pkg.spec" >&2
done

rm -rf "$TOPDIR/_stage"

# Sanity: every package should have produced exactly one .rpm.
expected="$(find "$PKG_ROOT" -mindepth 1 -maxdepth 1 -type d | wc -l)"
produced="$(find "$TOPDIR/RPMS" -name 'sideral-*.rpm' | wc -l)"
if [ "$expected" != "$produced" ]; then
    echo "rpmbuild produced $produced RPMs, expected $expected" >&2
    exit 1
fi

echo "built $produced RPMs under $TOPDIR/RPMS/" >&2
find "$TOPDIR/RPMS" -name 'sideral-*.rpm' -print
