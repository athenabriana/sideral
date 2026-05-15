# silverfox-home-sync.sh — user home bootstrap on every login.
# Runs once per session via fox dotfiles-sync.

if [ -z "${BASH_VERSION-}" ] && [ -z "${ZSH_VERSION-}" ]; then
    return
fi

[ -n "${SILVERFOX_HOME_SYNC_RAN:-}" ] && return
SILVERFOX_HOME_SYNC_RAN=1

: "${HOME:?HOME must be set}"

if command -v fox >/dev/null 2>&1; then
    fox dotfiles-sync >/dev/null 2>&1 || true
fi
