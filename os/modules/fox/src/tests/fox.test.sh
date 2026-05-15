#!/usr/bin/env bash
# fox.test.sh — integration tests for /usr/bin/fox (exec-just passthrough).
# Uses a fake-just stub on PATH.
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

run() {
    "$FOX" "$@" 2>&1
}

echo "── fox.test.sh ──"

# FOX-02: no-arg passes -f <justfile> to just with no extra args.
actual=$(run | grep '^FAKEJUST:' | tr '\n' ' ')
assert_contains "noarg_justfile" "FAKEJUST:$SILVERFOX_JUSTFILE" "$actual"

# FOX-02: --help passes through to just unchanged.
actual=$(run --help | grep '^FAKEJUST:' | tr '\n' ' ')
assert_contains "help_passthrough" "FAKEJUST:--help" "$actual"

# fox motd-toggle → just motd-toggle.
actual=$(run motd-toggle | grep '^FAKEJUST:' | tail -n2 | tr '\n' ' ')
assert_contains "motd-toggle_pass" "FAKEJUST:motd-toggle" "$actual"

# fox firmware-upgrade → just firmware-upgrade.
actual=$(run firmware-upgrade | grep '^FAKEJUST:' | tail -n2 | tr '\n' ' ')
assert_contains "firmware-upgrade_pass" "FAKEJUST:firmware-upgrade" "$actual"

# fox clean → just clean.
actual=$(run clean | grep '^FAKEJUST:' | tail -n2 | tr '\n' ' ')
assert_contains "clean_pass" "FAKEJUST:clean" "$actual"
actual=$(run clean -bm | grep '^FAKEJUST:' | tail -n2 | tr '\n' ' ')
assert_contains "clean_flag" "FAKEJUST:-bm" "$actual"

# FOX-04 / FOX-05: unknown verb passes through unchanged.
actual=$(run xyzzy | grep '^FAKEJUST:' | tail -n1)
assert_eq "passthrough_verb" "FAKEJUST:xyzzy" "$actual"

# fox os-upgrade with flags passes flags through.
actual=$(run os-upgrade --allow-downgrade | grep '^FAKEJUST:' | tail -n2 | tr '\n' ' ')
assert_contains "upgrade_pass" "FAKEJUST:os-upgrade" "$actual"
assert_contains "upgrade_flag" "FAKEJUST:--allow-downgrade" "$actual"

# fox os-status --json passes --json through.
actual=$(run os-status --json | grep '^FAKEJUST:' | tail -n2 | tr '\n' ' ')
assert_contains "status_json" "FAKEJUST:--json" "$actual"

# fox sync passes through as a single arg.
actual=$(run sync | grep '^FAKEJUST:' | tail -n2 | tr '\n' ' ')
assert_contains "sync_pass" "FAKEJUST:sync" "$actual"

# Multiple args all pass through (e.g. home-diff extra-flag).
actual=$(run home-diff --verbose | grep '^FAKEJUST:' | tail -n2 | tr '\n' ' ')
assert_contains "multi_arg_verb" "FAKEJUST:home-diff" "$actual"
assert_contains "multi_arg_flag" "FAKEJUST:--verbose" "$actual"

# FOX-04: just's exit code propagates.
mk_fake_just "$BINDIR" 7
set +e
"$FOX" xyzzy >/dev/null 2>&1
rc=$?
set -e
assert_exit "exit_propagation" "7" "$rc"

summary
