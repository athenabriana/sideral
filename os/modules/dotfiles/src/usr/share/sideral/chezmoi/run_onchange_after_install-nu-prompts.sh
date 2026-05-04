#!/usr/bin/env bash
# Generate per-tool nushell init files into ~/.local/share/nushell/
# vendor/autoload/. Run by chezmoi on first apply and whenever the
# content of THIS script changes (the `run_onchange_` prefix hashes the
# script body, not the generated output — bump the version comment below
# to force a regen, e.g. when bumping the atuin sed pattern).
#
# Why pre-generate: nushell's `source` is a parse-time keyword, so the
# `cmd init nu | save tmp; source tmp` pattern (used in bash/zsh)
# can't work in nushell — it fails on every cold shell because the
# tmp file doesn't exist at parse time. Files in $nu.vendor-autoload-
# dirs are auto-sourced by nu on startup with no `source` keyword
# needed, so pre-generated init files Just Work.
#
# script-version: 1   (bump to force regen)

set -euo pipefail

log()  { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m⚠\033[0m  %s\n' "$*" >&2; }

AUTOLOAD_DIR="${HOME}/.local/share/nushell/vendor/autoload"
mkdir -p "$AUTOLOAD_DIR"

_emit() {
    local tool="$1" outfile="$2"
    shift 2
    if ! command -v "$tool" >/dev/null 2>&1; then
        warn "$tool not on PATH — skipping $outfile"
        rm -f "$AUTOLOAD_DIR/$outfile"   # clean up stale file from prior version
        return
    fi
    log "  $outfile  ←  $tool $*"
    "$tool" "$@" > "$AUTOLOAD_DIR/$outfile"
}

_emit starship sideral-starship.nu init nu
_emit atuin    sideral-atuin.nu    init nu --disable-up-arrow
_emit zoxide   sideral-zoxide.nu   init nushell
_emit mise     sideral-mise.nu     activate nu

# atuin 18.12 emits `job spawn -t atuin {...}`, assuming nushell's
# `--tag` flag added in 0.105. Nushell renamed it to `--description`
# (`-d`) before 0.112, so the generated file fails to parse on shipped
# nu. Sed-swap is idempotent — once atuin's upstream catches up, the
# pattern won't match and this is a no-op.
if [ -f "$AUTOLOAD_DIR/sideral-atuin.nu" ]; then
    sed -i 's/job spawn -t atuin/job spawn -d atuin/g' "$AUTOLOAD_DIR/sideral-atuin.nu"
fi

log "Done. Autoloads in $AUTOLOAD_DIR:"
ls -1 "$AUTOLOAD_DIR" 2>/dev/null | sed 's/^/    /'
