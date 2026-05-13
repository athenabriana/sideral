# sideral-nix-init.sh — nix auto-stow + first-login init.
#
# 1. Stow nix flake symlink em todo login (rápido, ~100ms).
# 2. No primeiro login por usuário: `nh home switch --impure` pra
#    aplicar a starter flake.
#
# nh já vem instalado no perfil system-wide pelo bootstrap service,
# então não precisa instalar manualmente.
#
# Guarded by:
#   - `command -v nix` — nix deve estar pronto
#   - `command -v stow` — stow deve estar instalado
#   - `~/.config/sideral/.nix-first-init-done` — sentinela

if [ -z "${BASH_VERSION-}" ] && [ -z "${ZSH_VERSION-}" ]; then
    return
fi

[ -n "${SIDERAL_NIX_INIT_RAN:-}" ] && return
SIDERAL_NIX_INIT_RAN=1

# Stow nix flake (every login, idempotent)
if command -v stow >/dev/null 2>&1 && [ -d "$HOME/Dotfiles/nix" ]; then
    stow -R -d "$HOME/Dotfiles" -t "$HOME" nix 2>/dev/null || true
fi

# First-login: apply nix config
if command -v nh >/dev/null 2>&1 \
  && command -v nix >/dev/null 2>&1 \
  && [ -f "$HOME/.config/nix/flake.nix" ] \
  && [ ! -f "$HOME/.config/sideral/.nix-first-init-done" ]; then
    nh home switch --impure -c "$(whoami)" 2>/dev/null || true
    mkdir -p "$HOME/.config/sideral"
    touch "$HOME/.config/sideral/.nix-first-init-done"
fi
