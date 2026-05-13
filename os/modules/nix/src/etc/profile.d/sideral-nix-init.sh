# sideral-nix-init.sh — nix auto-init + auto-stow for every login.
#
# 1. Runs `stow -R nix` every login (fast, ~100ms) to re-assert the
#    flake.nix symlink in case the stow tree got out of sync.
# 2. On the very first login per user: installs `nh` via nix profile
#    and runs `nh home switch` to apply the starter flake.
#
# Guarded by:
#   - `command -v nix` — nix must be ready (bootstrap service ran)
#   - `command -v stow` — stow must be installed
#   - `~/.config/sideral/.nix-first-init-done` — first-login sentinel

if [ -z "${BASH_VERSION-}" ] && [ -z "${ZSH_VERSION-}" ]; then
    return  # only bash and zsh
fi

# Only run once per shell session
[ -n "${SIDERAL_NIX_INIT_RAN:-}" ] && return
SIDERAL_NIX_INIT_RAN=1

# ── 1. Stow nix flake (every login, idempotent) ─────────────────────────
if command -v stow >/dev/null 2>&1 && [ -d "$HOME/.config/sideral/stow/nix" ]; then
    stow -R -d "$HOME/.config/sideral/stow" -t "$HOME" nix 2>/dev/null || true
fi

# ── 2. First-login init: install nh + apply flake ───────────────────────
if command -v nix >/dev/null 2>&1 && [ ! -f "$HOME/.config/sideral/.nix-first-init-done" ]; then
    # Install nh if not present
    if ! command -v nh >/dev/null 2>&1; then
        nix profile install nixpkgs#nh 2>/dev/null || true
    fi

    # Run nh home switch if nh is now available
    if command -v nh >/dev/null 2>&1 && [ -f "$HOME/.config/nix/flake.nix" ]; then
        nh home switch --impure -c "$(whoami)" 2>/dev/null || true
    fi

    # Mark done (even if it failed — retry on next login is fine)
    mkdir -p "$HOME/.config/sideral"
    touch "$HOME/.config/sideral/.nix-first-init-done"
fi
