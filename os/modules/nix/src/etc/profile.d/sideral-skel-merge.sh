# sideral-skel-merge.sh — auto-merge novos defaults do /etc/skel.
#
# Em todo login:
#   1. Copia arquivos NOVOS do skel (que não existem em $HOME)
#   2. Se um arquivo do skel mudou vs $HOME: marca como pendente
#   3. Exibe aviso se houver pendências
#
# Para aplicar pendências: fox update-system --merge

if [ -z "${BASH_VERSION-}" ] && [ -z "${ZSH_VERSION-}" ]; then
    return
fi

[ -n "${SIDERAL_SKEL_MERGE_RAN:-}" ] && return
SIDERAL_SKEL_MERGE_RAN=1

SKEL_DIR="${SKEL_DIR:-/etc/skel}"
PENDING_FILE="$HOME/.config/sideral/.skel-pending"
: "${HOME:?HOME must be set}"

[ -d "$SKEL_DIR" ] || return

pending=()

# Walk top-level entries in skel (files, symlinks, dirs)
while IFS= read -r -d '' top; do
    rel="${top#"$SKEL_DIR"/}"

    # Skip sideral stow directory — managed by stow, not by skel merge
    [[ "$rel" == .config/sideral* ]] && continue

    if [[ -d "$top" && ! -L "$top" ]]; then
        # Directory: walk depth-1 children
        while IFS= read -r -d '' child; do
            crel="$rel/${child##*/}"
            src="$SKEL_DIR/$crel"
            dst="$HOME/$crel"
            if [ ! -e "$dst" ]; then
                # New file: copy silently
                mkdir -p "$(dirname "$dst")"
                cp -a "$src" "$dst"
            elif [ -f "$src" ] && [ -f "$dst" ]; then
                # Same type: compare content
                if ! diff -q "$src" "$dst" >/dev/null 2>&1; then
                    pending+=("$crel")
                fi
            elif [ -L "$src" ] && [ -L "$dst" ]; then
                # Symlinks: compare targets
                src_target=$(readlink "$src")
                dst_target=$(readlink "$dst")
                if [ "$src_target" != "$dst_target" ]; then
                    pending+=("$crel (symlink)")
                fi
            fi
        done < <(find "$top" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)
    elif [ -f "$top" ] || [ -L "$top" ]; then
        # Top-level file or symlink
        dst="$HOME/$rel"
        if [ ! -e "$dst" ]; then
            mkdir -p "$(dirname "$dst")"
            cp -a "$top" "$dst"
        elif [ -f "$top" ] && [ -f "$dst" ]; then
            if ! diff -q "$top" "$dst" >/dev/null 2>&1; then
                pending+=("$rel")
            fi
        elif [ -L "$top" ] && [ -L "$dst" ]; then
            src_target=$(readlink "$top")
            dst_target=$(readlink "$dst")
            if [ "$src_target" != "$dst_target" ]; then
                pending+=("$rel (symlink)")
            fi
        fi
    fi
done < <(find "$SKEL_DIR" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)

if [ ${#pending[@]} -gt 0 ]; then
    mkdir -p "$HOME/.config/sideral"
    printf '%s\n' "${pending[@]}" > "$PENDING_FILE"
    echo
    echo "⚡ sideral: novos defaults do sistema disponíveis"
    echo "   Revise os arquivos conflitantes e resolva manualmente:"
    for p in "${pending[@]}"; do
        echo "     • $p"
    done
    echo
else
    rm -f "$PENDING_FILE"
fi
