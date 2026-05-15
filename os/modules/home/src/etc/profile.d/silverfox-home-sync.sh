# silverfox-home-sync.sh — bootstrap do home do usuário em todo login.
#
# Roda uma vez por sessão:
#   fox dotfiles-sync — copia skel + substitui __USER__ + stow (idempotente)
#
# O resto (nix pkgs, temas) fica sob demanda via `fox sync` e `fox theme-sync`.

if [ -z "${BASH_VERSION-}" ] && [ -z "${ZSH_VERSION-}" ]; then
    return
fi

[ -n "${SILVERFOX_HOME_SYNC_RAN:-}" ] && return
SILVERFOX_HOME_SYNC_RAN=1

: "${HOME:?HOME must be set}"

if command -v fox >/dev/null 2>&1; then
    fox dotfiles-sync >/dev/null 2>&1 || true
fi
