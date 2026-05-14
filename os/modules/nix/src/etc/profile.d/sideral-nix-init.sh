# sideral-nix-init.sh — nix auto-stow + first-login init.
#
# 1. Stow nix flake symlink em todo login.
# 2. Auto-personaliza placeholder __USER__ no flake.
# 3. No primeiro login: nh home switch --impure.

if [ -z "${BASH_VERSION-}" ] && [ -z "${ZSH_VERSION-}" ]; then
    return
fi

[ -n "${SIDERAL_NIX_INIT_RAN:-}" ] && return
SIDERAL_NIX_INIT_RAN=1

# Stow nix flake (every login, idempotent)
if command -v stow >/dev/null 2>&1 && [ -d "$HOME/Dotfiles/nix" ]; then
    stow -R -d "$HOME/Dotfiles" -t "$HOME" nix 2>/dev/null || true
fi

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
  && [ ! -f "$HOME/.config/sideral/.nix-first-init-done" ]; then
    nh home switch --impure 2>/dev/null || true
    mkdir -p "$HOME/.config/sideral"
    touch "$HOME/.config/sideral/.nix-first-init-done"
fi
