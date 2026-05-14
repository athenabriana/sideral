# silverfox-nix-init.sh — nix auto-stow + first-login init.
#
# 1. Stow nix flake symlink em todo login.
# 2. Auto-personaliza placeholder __USER__ no flake.
# 3. No primeiro login: nh home switch --impure.

if [ -z "${BASH_VERSION-}" ] && [ -z "${ZSH_VERSION-}" ]; then
    return
fi

[ -n "${SILVERFOX_NIX_INIT_RAN:-}" ] && return
SILVERFOX_NIX_INIT_RAN=1

# Auto-personaliza: troca placeholder __USER__ pelo username real
# Só roda se achar __USER__ (starter flake, não modificado)
flake_file="$HOME/.config/nix/flake.nix"
if [ -f "$flake_file" ] && grep -q '__USER__' "$flake_file" 2>/dev/null; then
    sed -i "s/__USER__/$USER/g" "$flake_file" 2>/dev/null || true
fi

# First-login: apply nix config
if command -v nh >/dev/null 2>&1 \
  && command -v nix >/dev/null 2>&1 \
  && [ -f "$flake_file" ] \
  && [ ! -f "$HOME/.config/silverfox/.nix-first-init-done" ]; then
    nh home switch --impure 2>/dev/null || true
    mkdir -p "$HOME/.config/silverfox"
    touch "$HOME/.config/silverfox/.nix-first-init-done"
fi
