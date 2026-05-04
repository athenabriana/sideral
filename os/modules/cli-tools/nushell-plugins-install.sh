#!/usr/bin/env bash
# Build and install nushell plugins to /usr/lib/nushell/plugins/.
#
# Plugin set: query, formats, gstat (bundled in Fedora nushell package),
# file (pre-built binary), rpm / explore (cargo-built from crates.io).
# Cargo is installed, used, and removed in one pass so no Rust toolchain
# bloats the final image. All failures are non-fatal (warn + continue).

set -euo pipefail

log()  { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m⚠\033[0m  %s\n' "$*" >&2; }

PLUGIN_DIR=/usr/lib/nushell/plugins
mkdir -p "$PLUGIN_DIR"

NU_VER="$(nu --version)"
log "Installing nushell plugins for nu $NU_VER"

# ── 1. Bundled plugins ─────────────────────────────────────────────────
# Fedora's nushell package ships nu_plugin_{formats,gstat,query,...}
# alongside nu. Copy whichever are present; fall back to the matching
# upstream release tarball for any that are missing.
_need_bundled=()
for plugin in nu_plugin_query nu_plugin_formats nu_plugin_gstat; do
    src="$(command -v "$plugin" 2>/dev/null || true)"
    if [ -n "$src" ]; then
        log "Copying Fedora-bundled $plugin"
        cp "$src" "$PLUGIN_DIR/$plugin"
    else
        _need_bundled+=("$plugin")
    fi
done

if [ ${#_need_bundled[@]} -gt 0 ]; then
    log "Fetching missing bundled plugins from nushell $NU_VER release tarball"
    _tmp_dl=$(mktemp -d)
    trap 'rm -rf "$_tmp_dl"' EXIT
    _tarball="nu-${NU_VER}-x86_64-unknown-linux-gnu.tar.gz"
    if curl -fsSL --max-time 120 -o "$_tmp_dl/$_tarball" \
            "https://github.com/nushell/nushell/releases/download/${NU_VER}/${_tarball}"; then
        for plugin in "${_need_bundled[@]}"; do
            if tar -xzf "$_tmp_dl/$_tarball" -C "$PLUGIN_DIR" \
                    --strip-components=1 "*/$plugin" 2>/dev/null \
                    || tar -xzf "$_tmp_dl/$_tarball" -C "$PLUGIN_DIR" \
                    "$plugin" 2>/dev/null; then
                log "  extracted $plugin"
            else
                warn "  $plugin not in tarball, skipping"
            fi
        done
    else
        warn "Could not fetch nushell release tarball — bundled plugins may be missing"
    fi
fi

# ── 2. nu_plugin_file — pre-built binary from fdncred/nu_plugin_file ──
log "Fetching nu_plugin_file pre-built binary"
_file_base="https://github.com/fdncred/nu_plugin_file/releases/latest/download"
_file_tmp=$(mktemp -d)
if curl -fsSL --max-time 60 -o "$_file_tmp/nu_plugin_file" \
        "$_file_base/nu_plugin_file" 2>/dev/null; then
    install -m 755 "$_file_tmp/nu_plugin_file" "$PLUGIN_DIR/nu_plugin_file"
    log "  nu_plugin_file installed"
else
    warn "  nu_plugin_file download failed, skipping"
fi
rm -rf "$_file_tmp"

# ── 3. Source-built plugins (highlight, rpm, explore) ─────────────────
# Install Rust toolchain only if not already present; track whether we
# added it so teardown is symmetric.
_rust_added=0
if ! command -v cargo >/dev/null 2>&1; then
    log "Installing Rust toolchain for source-built plugins"
    dnf5 install -y rust cargo
    _rust_added=1
fi

CARGO_HOME="$(mktemp -d)"
export CARGO_HOME
export PATH="$CARGO_HOME/bin:$PATH"

_build_plugin() {
    local crate="$1"
    log "Building $crate"
    if cargo install "$crate" --root "$CARGO_HOME" 2>/dev/null; then
        if [ -f "$CARGO_HOME/bin/$crate" ]; then
            install -m 755 "$CARGO_HOME/bin/$crate" "$PLUGIN_DIR/$crate"
            log "  $crate installed"
        else
            warn "  $crate binary not found after install, skipping"
        fi
    else
        warn "  $crate build failed, skipping"
    fi
}

_build_plugin nu_plugin_rpm

# nu_plugin_explore: build then verify protocol compatibility with
# the installed nushell version before keeping (D-06).
log "Building nu_plugin_explore (with compatibility check)"
if cargo install nu_plugin_explore --root "$CARGO_HOME" 2>/dev/null \
        && [ -f "$CARGO_HOME/bin/nu_plugin_explore" ]; then
    tmp_plugin="$CARGO_HOME/bin/nu_plugin_explore"
    if nu --commands "plugin add $tmp_plugin" >/dev/null 2>&1; then
        install -m 755 "$tmp_plugin" "$PLUGIN_DIR/nu_plugin_explore"
        log "  nu_plugin_explore installed (compatible)"
    else
        warn "  nu_plugin_explore is incompatible with nu $NU_VER — dropping (D-06)"
    fi
else
    warn "  nu_plugin_explore build failed, skipping"
fi

# ── 4. Teardown ────────────────────────────────────────────────────────
rm -rf "$CARGO_HOME"
if [ "$_rust_added" -eq 1 ]; then
    log "Removing Rust toolchain"
    rpm -e --nodeps rust cargo 2>/dev/null || dnf5 remove -y rust cargo || true
fi

chown -R root:root "$PLUGIN_DIR"
log "Nushell plugins installed: $(ls "$PLUGIN_DIR" | tr '\n' ' ')"
