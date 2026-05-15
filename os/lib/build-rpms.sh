#!/usr/bin/env bash
set -euo pipefail

MOD_ROOT="${1:?usage: build-rpms.sh <modules-dir> <output-topdir> [version]}"
TOPDIR="${2:?usage: build-rpms.sh <modules-dir> <output-topdir> [version]}"
VERSION="${3:-${_SILVERFOX_VERSION:-0.0.0.dev}}"

[ -d "$MOD_ROOT" ] || { echo "modules dir not found: $MOD_ROOT" >&2; exit 1; }

mkdir -p "$TOPDIR"/{SOURCES,SPECS,BUILD,BUILDROOT,RPMS}

expected_count=0

for moddir in "$MOD_ROOT"/*/; do
    module="$(basename "$moddir")"
    rpmdir="$moddir/rpm"
    src="$moddir/src"

    [ -d "$rpmdir" ] || continue

    shopt -s nullglob
    specs=("$rpmdir"/*.spec)
    shopt -u nullglob

    [ ${#specs[@]} -gt 0 ] || { echo "skip $module: rpm/ has no .spec files" >&2; continue; }

    for spec in "${specs[@]}"; do
        spec_name="$(basename "$spec" .spec)"
        expected_count=$((expected_count + 1))

        if [ -d "$src" ]; then
            stage="$TOPDIR/_stage/$spec_name-$VERSION"
            mkdir -p "$stage"
            cp -a "$src/." "$stage/"
            ( cd "$TOPDIR/_stage" && tar czf "$TOPDIR/SOURCES/$spec_name-$VERSION.tar.gz" "$spec_name-$VERSION" )
            rm -rf "$stage"
        else
            stage="$TOPDIR/_stage/$spec_name-$VERSION"
            mkdir -p "$stage"
            ( cd "$TOPDIR/_stage" && tar czf "$TOPDIR/SOURCES/$spec_name-$VERSION.tar.gz" "$spec_name-$VERSION" )
            rm -rf "$stage"
        fi

        cp "$spec" "$TOPDIR/SPECS/"

        rpmbuild -bb \
            --define "_topdir $TOPDIR" \
            --define "_silverfox_version $VERSION" \
            --define "dist .fc44" \
            "$TOPDIR/SPECS/$spec_name.spec" >&2
    done
done

rm -rf "$TOPDIR/_stage"

produced="$(find "$TOPDIR/RPMS" -name 'silverfox-*.rpm' | wc -l)"
if [ "$expected_count" != "$produced" ]; then
    echo "rpmbuild produced $produced RPMs, expected $expected_count" >&2
    exit 1
fi

echo "built $produced RPMs under $TOPDIR/RPMS/" >&2
find "$TOPDIR/RPMS" -name 'silverfox-*.rpm' -print
