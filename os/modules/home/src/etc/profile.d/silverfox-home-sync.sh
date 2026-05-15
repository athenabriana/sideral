# silverfox-home-sync.sh — bootstrap e sync do home do usuário em todo login.
#
# Roda uma vez por sessão:
#   1. fox dotfiles-init  — copia skel + substitui __USER__ (idempotente)
#   2. fox dotfiles-link  — aplica stow em cada pacote (pula nix/)
#   3. nh home switch     — sync home-manager em background
#   4. flavours / cosmic / ghostty — aplica tema default se necessário

if [ -z "${BASH_VERSION-}" ] && [ -z "${ZSH_VERSION-}" ]; then
    return
fi

[ -n "${SILVERFOX_HOME_SYNC_RAN:-}" ] && return
SILVERFOX_HOME_SYNC_RAN=1

: "${HOME:?HOME must be set}"

# Delega bootstrap (skel-copy + __USER__ substitution) e stow ao fox.
# fox dotfiles-init é idempotente; dotfiles-link refaz symlinks no-op.
if command -v fox >/dev/null 2>&1; then
    fox dotfiles-init >/dev/null 2>&1 || true
    fox dotfiles-link >/dev/null 2>&1 || true
fi

# Sincroniza home-manager nix em background para não travar o login
if command -v nh >/dev/null 2>&1; then
    nh home switch --impure >"$HOME/.cache/silverfox-home-sync.log" 2>&1 & disown
fi

# Garante tema base16 padrão se nenhum foi aplicado ainda
if command -v flavours >/dev/null 2>&1; then
    if ! flavours current >/dev/null 2>&1; then
        flavours apply onedark >/dev/null 2>&1 || true
    fi
    # Sempre importa o tema atual no COSMIC (single source of truth)
    _cosmic_theme="$HOME/.cache/silverfox/cosmic-theme.ron"
    if command -v cosmic-settings >/dev/null 2>&1 && [ -f "$_cosmic_theme" ]; then
        cosmic-settings appearance import "$_cosmic_theme" >/dev/null 2>&1 || true
    fi
    # Reload ghostty config (no-op se não tiver janela aberta)
    if pgrep -x ghostty >/dev/null 2>&1; then
        gdbus call --session --dest com.mitchellh.ghostty \
            --object-path /com/mitchellh/ghostty \
            --method org.gtk.Actions.Activate reload-config '[]' '{}' >/dev/null 2>&1 \
            || pkill -USR2 ghostty 2>/dev/null \
            || true
    fi
fi
