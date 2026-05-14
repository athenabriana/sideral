#!/usr/bin/env bash
# fox.test.sh — integration tests for /usr/bin/fox (the bash dispatcher).
# Uses a fake-just stub on PATH + a fixture /etc/os-release.
set -euo pipefail

export SUITE=fox
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib.sh disable=SC1091
source "$HERE/lib.sh"

FOX="$HERE/../bin/fox"
[[ -x "$FOX" ]] || chmod +x "$FOX"  # in case checkout dropped the mode

TMP=$(mktmpdir)
trap 'rm -rf "$TMP"' EXIT

BINDIR="$TMP/bin"
mk_fake_just "$BINDIR"
export PATH="$BINDIR:$PATH"
export SILVERFOX_JUSTFILE="$TMP/fixture.justfile"
echo "# fixture" >"$SILVERFOX_JUSTFILE"
export SILVERFOX_OS_RELEASE="$TMP/os-release"
cat >"$SILVERFOX_OS_RELEASE" <<'EOF'
NAME="silverfox"
VERSION_ID="20260511.42"
ID=fedora
EOF

run() {
    "$FOX" "$@" 2>&1
}

echo "── fox.test.sh ──"

# FOX-03: --version prints VERSION_ID from $SILVERFOX_OS_RELEASE.
actual=$(run --version | grep -v '^FAKEJUST:' || true)
assert_eq "version_id" "20260511.42" "$actual"

# FOX-02: no-arg invokes fake-just with --list.
actual=$(run | grep '^FAKEJUST:' | tail -n2 | tr '\n' ' ')
assert_contains "noarg_list" "FAKEJUST:--list" "$actual"
assert_contains "noarg_justfile" "FAKEJUST:$SILVERFOX_JUSTFILE" "$actual"

# FOX-02: --help also lists.
actual=$(run --help | grep '^FAKEJUST:' | tr '\n' ' ')
assert_contains "help_list" "FAKEJUST:--list" "$actual"

# FOXEN-01: fox toggle-banner → just toggle-banner.
actual=$(run toggle-banner | grep '^FAKEJUST:' | tail -n2 | tr '\n' ' ')
assert_contains "toggle-banner_pass" "FAKEJUST:toggle-banner" "$actual"

# FOXEN-03: fox upgrade-firmware → just upgrade-firmware.
actual=$(run upgrade-firmware | grep '^FAKEJUST:' | tail -n2 | tr '\n' ' ')
assert_contains "upgrade-firmware_pass" "FAKEJUST:upgrade-firmware" "$actual"

# FOXEN-02: fox cleanup → just cleanup.
actual=$(run cleanup | grep '^FAKEJUST:' | tail -n2 | tr '\n' ' ')
assert_contains "cleanup_pass" "FAKEJUST:cleanup" "$actual"
actual=$(run cleanup -bm | grep '^FAKEJUST:' | tail -n2 | tr '\n' ' ')
assert_contains "cleanup_flag" "FAKEJUST:-bm" "$actual"

# FOX-04 / FOX-05: unknown verb passes through.
actual=$(run xyzzy | grep '^FAKEJUST:' | tail -n1)
assert_eq "passthrough_verb" "FAKEJUST:xyzzy" "$actual"

# FOXEN-04 / FOX-05: fox upgrade with flags → just upgrade with flags.
actual=$(run upgrade --allow-downgrade | grep '^FAKEJUST:' | tail -n2 | tr '\n' ' ')
assert_contains "upgrade_pass" "FAKEJUST:upgrade" "$actual"
assert_contains "upgrade_flag" "FAKEJUST:--allow-downgrade" "$actual"

# FOX-12: fox status --json passes --json.
actual=$(run status --json | grep '^FAKEJUST:' | tail -n2 | tr '\n' ' ')
assert_contains "status_json" "FAKEJUST:--json" "$actual"

# FOX-05: fox home factory-reset --yes → just home::factory-reset --yes.
actual=$(run home factory-reset --yes | grep '^FAKEJUST:' | tail -n2 | tr '\n' ' ')
assert_contains "home_sub_xform" "FAKEJUST:home::factory-reset" "$actual"
assert_contains "home_sub_yes" "FAKEJUST:--yes" "$actual"

# FOX-05: fox home (no sub) → just --list home.
actual=$(run home | grep '^FAKEJUST:' | tr '\n' ' ')
assert_contains "home_nosub_list" "FAKEJUST:--list" "$actual"
assert_contains "home_nosub_arg"  "FAKEJUST:home" "$actual"

# FOX-04: just's exit code propagates.
mk_fake_just "$BINDIR" 7
set +e
"$FOX" xyzzy >/dev/null 2>&1
rc=$?
set -e
assert_exit "exit_propagation" "7" "$rc"

summary
