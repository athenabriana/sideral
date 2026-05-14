# silverfox-skel-merge.sh — copia Dotfiles do skel e aplica symlinks via stow.
#
# Em todo login:
#   1. Copia arquivos novos de /etc/skel/Dotfiles para $HOME/Dotfiles (ignora existentes)
#   2. Roda stow em cada pacote de $HOME/Dotfiles

if [ -z "${BASH_VERSION-}" ] && [ -z "${ZSH_VERSION-}" ]; then
    return
fi

[ -n "${SILVERFOX_SKEL_MERGE_RAN:-}" ] && return
SILVERFOX_SKEL_MERGE_RAN=1

SKEL_DOTFILES="${SKEL_DIR:-/etc/skel}/Dotfiles"
HOME_DOTFILES="$HOME/Dotfiles"
: "${HOME:?HOME must be set}"

[ -d "$SKEL_DOTFILES" ] || return

# Copia arquivos/symlinks novos
while IFS= read -r -d '' src; do
    rel="${src#"$SKEL_DOTFILES"/}"
    dst="$HOME_DOTFILES/$rel"
    { [ -e "$dst" ] || [ -L "$dst" ]; } && continue
    mkdir -p "$(dirname "$dst")"
    cp -a "$src" "$dst"
done < <(find "$SKEL_DOTFILES" -mindepth 1 -not -type d -print0 2>/dev/null)

# Aplica symlinks via stow para cada pacote
command -v stow >/dev/null 2>&1 || return
[ -d "$HOME_DOTFILES" ] || return

while IFS= read -r -d '' pkg; do
    stow -d "$HOME_DOTFILES" -t "$HOME" --no-folding "${pkg##*/}" 2>/dev/null || true
done < <(find "$HOME_DOTFILES" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
