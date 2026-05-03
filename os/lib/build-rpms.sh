#!/usr/bin/env bash
# build-rpms.sh — build every sideral-* binary RPM inline from os/modules/.
#
# Walks <modules-dir>/<module>/rpm/*.spec. Each spec has a sibling
# <modules-dir>/<module>/src/ tree that becomes Source0 (tarballed as
# <spec-basename>-<version>/<path-tree> for `%setup -q`). Modules with
# multiple specs share the same src/ — each spec's %files filters down
# to what it actually owns.
#
# Modules without an rpm/ subdir are skipped here; they only contribute
# build-time concerns (packages.txt, *.sh) handled by the orchestrator.
#
# Usage:    os/lib/build-rpms.sh <modules-dir> <output-topdir> [version]
#
# Default version: $_SIDERAL_VERSION env, else "0.0.0.dev". CI sets
# _SIDERAL_VERSION="$(date -u +%Y%m%d).${GITHUB_RUN_NUMBER}".
#
# Output:   <output-topdir>/RPMS/noarch/sideral-*.rpm

set -euo pipefail

MOD_ROOT="${1:?usage: build-rpms.sh <modules-dir> <output-topdir> [version]}"
TOPDIR="${2:?usage: build-rpms.sh <modules-dir> <output-topdir> [version]}"
VERSION="${3:-${_SIDERAL_VERSION:-0.0.0.dev}}"

[ -d "$MOD_ROOT" ] || { echo "modules dir not found: $MOD_ROOT" >&2; exit 1; }

mkdir -p "$TOPDIR"/{SOURCES,SPECS,BUILD,BUILDROOT,RPMS}

built_count=0
expected_count=0

for moddir in "$MOD_ROOT"/*/; do
    module="$(basename "$moddir")"
    rpmdir="$moddir/rpm"
    src="$moddir/src"

    [ -d "$rpmdir" ] || continue   # build-time-only modules live under os/build/, not here

    shopt -s nullglob
    specs=("$rpmdir"/*.spec)
    shopt -u nullglob

    [ ${#specs[@]} -gt 0 ] || { echo "skip $module: rpm/ has no .spec files" >&2; continue; }

    for spec in "${specs[@]}"; do
        spec_name="$(basename "$spec" .spec)"
        expected_count=$((expected_count + 1))

        if [ -d "$src" ]; then
            # Tarball src/ as <spec_name>-<version>/<path-tree> for %setup -q.
            stage="$TOPDIR/_stage/$spec_name-$VERSION"
            mkdir -p "$stage"
            cp -a "$src/." "$stage/"
            ( cd "$TOPDIR/_stage" && tar czf "$TOPDIR/SOURCES/$spec_name-$VERSION.tar.gz" "$spec_name-$VERSION" )
            rm -rf "$stage"
        else
            # No src/ — synthesize an empty tarball so %setup -q has something
            # to extract. Specs with no %files (pure Requires meta-RPMs)
            # don't need anything in the source tree.
            stage="$TOPDIR/_stage/$spec_name-$VERSION"
            mkdir -p "$stage"
            ( cd "$TOPDIR/_stage" && tar czf "$TOPDIR/SOURCES/$spec_name-$VERSION.tar.gz" "$spec_name-$VERSION" )
            rm -rf "$stage"
        fi

        cp "$spec" "$TOPDIR/SPECS/"

        rpmbuild -bb \
            --define "_topdir $TOPDIR" \
            --define "_sideral_version $VERSION" \
            --define "dist .fc44" \
            "$TOPDIR/SPECS/$spec_name.spec" >&2
    done
done

rm -rf "$TOPDIR/_stage"

# Sanity: spec count matches built RPM count.
produced="$(find "$TOPDIR/RPMS" -name 'sideral-*.rpm' | wc -l)"
if [ "$expected_count" != "$produced" ]; then
    echo "rpmbuild produced $produced RPMs, expected $expected_count" >&2
    exit 1
fi

echo "built $produced RPMs under $TOPDIR/RPMS/" >&2
find "$TOPDIR/RPMS" -name 'sideral-*.rpm' -print
