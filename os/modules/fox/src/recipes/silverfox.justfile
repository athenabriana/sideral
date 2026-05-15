# silverfox.justfile — operator-CLI recipe surface, dispatched by /usr/bin/fox.
# Verbs: chsh, clean, doctor, dotfiles-sync, edit,
# firmware-upgrade, diff, home-theme, motd-toggle, os-changelog,
# os-rollback, os-status, os-upgrade, sync (top-level).

default:
    @just -f {{ justfile() }} --list

# Switch login shell (no arg = gum choose; allowlist: bash, zsh)
chsh shell="":
    #!/usr/bin/bash
    set -euo pipefail
    target="{{shell}}"
    if [[ -z "$target" ]]; then
        target=$(gum choose bash zsh)
    fi
    case "$target" in
        bash|zsh) ;;
        *) echo "Unknown shell: $target (try: bash, zsh)" >&2; exit 1 ;;
    esac
    current=$(getent passwd "$USER" | cut -d: -f7)
    if [[ "$current" == "/usr/bin/$target" ]]; then
        echo "Already on $target."
        exit 0
    fi
    sudo usermod -s "/usr/bin/$target" "$USER"
    echo "Done. Log out and back in, or 'exec $target -l' to swap now."

# Clean podman images, rpm-ostree metadata, and nix store;
# with explicit args, passes through to rpm-ostree cleanup
clean *args:
    #!/usr/bin/bash
    if [ $# -eq 0 ]; then
      gum confirm "Limpar imagens podman, cache rpm-ostree e nix store?" || exit 0
      podman image prune -af
      rpm-ostree cleanup -prm
      command -v nh >/dev/null 2>&1 && nh clean || echo "nh not installed, skipping nix cleanup"
    else
      rpm-ostree cleanup "$@"
    fi

# Inicializa ~/Dotfiles do skel (se ausente) + substitui __USER__ + stow
dotfiles-sync:
    #!/usr/bin/bash
    set -euo pipefail
    SKEL="/etc/skel/Dotfiles"
    HOME_DOTFILES="$HOME/Dotfiles"
    [ -d "$SKEL" ] || { echo "/etc/skel/Dotfiles não encontrado" >&2; exit 1; }
    if [ ! -d "$HOME_DOTFILES" ]; then
        echo "Copiando $SKEL → $HOME_DOTFILES…"
        cp -a "$SKEL" "$HOME_DOTFILES"
    fi
    for f in "$HOME_DOTFILES/nix/flake.nix" "$HOME_DOTFILES/nix/modules/home.nix"; do
        if [ -f "$f" ] && grep -q '__USER__' "$f" 2>/dev/null; then
            echo "Substituindo __USER__ → $USER em $(basename "$f")…"
            sed -i "s/__USER__/$USER/g" "$f"
        fi
    done
    if command -v stow >/dev/null 2>&1; then
        find "$HOME_DOTFILES" -mindepth 1 -maxdepth 1 -type d -print0 \
          | while IFS= read -r -d '' pkg; do
              case "${pkg##*/}" in
                nix) continue ;;
              esac
              stow -R -d "$HOME_DOTFILES" -t "$HOME" --no-folding "${pkg##*/}" 2>/dev/null || true
            done
    fi
    echo "dotfiles: sincronizado."

# Abre ~/Dotfiles no zed (se disponível) ou no file manager (xdg-open)
edit:
    #!/usr/bin/bash
    [ -d "$HOME/Dotfiles" ] || { echo "~/Dotfiles não existe — rode 'fox dotfiles-sync'" >&2; exit 1; }
    if command -v zed >/dev/null 2>&1; then
        exec zed "$HOME/Dotfiles"
    elif command -v xdg-open >/dev/null 2>&1; then
        exec xdg-open "$HOME/Dotfiles"
    else
        echo "Nem zed nem xdg-open encontrados" >&2
        exit 1
    fi

# Atualiza firmware do dispositivo (fwupdmgr)
firmware-upgrade:
    fwupdmgr refresh --force
    fwupdmgr get-updates
    fwupdmgr update

# Mostra pending nix config changes (dry-run)
diff:
    #!/usr/bin/bash
    nh home switch --impure --dry 2>/dev/null \
      || echo "Dry-run not available. Run 'fox sync' to apply."

# Diagnose nix + nh health — version, daemon, mount, SELinux, flake
doctor:
    #!/usr/bin/bash
    echo "=== nix version ==="
    nix --version 2>&1 || echo "NOT FOUND"
    echo "=== nix-daemon ==="
    if systemctl is-active nix-daemon >/dev/null 2>&1; then
      echo "active"
    else
      echo "NOT ACTIVE (try: sudo systemctl start nix-daemon)"
    fi
    echo "=== /nix mount ==="
    if findmnt /nix >/dev/null 2>&1; then
      echo "$(findmnt -n -o SOURCE /nix) → /nix"
    else
      echo "NOT MOUNTED (nix bootstrap may not have run yet)"
    fi
    echo "=== SELinux /nix/store ==="
    if [ -d /nix/store ]; then
      ls -Z /nix/store 2>&1 | head -1
    else
      echo "NOT ACCESSIBLE — /nix/store does not exist"
    fi
    echo "=== nh version ==="
    nh --version 2>&1 || echo "NOT INSTALLED (run 'fox sync')"
    echo "=== NH_FLAKE ==="
    echo "${NH_FLAKE:-<unset>}"
    echo "=== flake ==="
    _flake_dir="${NH_FLAKE:-$HOME/Dotfiles/nix}"
    if [ -e "$_flake_dir/flake.nix" ]; then
      echo "found: $_flake_dir/flake.nix"
      [ -f "$_flake_dir/flake.lock" ] && echo "lock: ok" || echo "lock: ausente (run 'nix flake update' para gerar)"
    else
      echo "flake não encontrado em $_flake_dir"
      echo "Run 'fox sync' to bootstrap from skel."
    fi

# Sync nix config (dotfiles + pacotes + flatpaks declarativos)
sync *args:
    #!/usr/bin/bash
    just -f {{ justfile() }} dotfiles-sync
    if command -v nh >/dev/null 2>&1; then
        echo "nix/home-manager: aplicando configuração…"
        _flake="${NH_FLAKE:-$HOME/Dotfiles/nix}"
        if [ -f "$_flake/flake.lock" ]; then
            nix flake update silverfox --flake "$_flake" 2>/dev/null || true
        fi
        nh home switch --impure
    else
        echo "nh não encontrado — pulando sincronização nix."
    fi

# Aplica tema padrão (flavours + cosmic + ghostty reload)
theme-sync:
    #!/usr/bin/bash
    set -euo pipefail
    if command -v flavours >/dev/null 2>&1; then
        _data="${XDG_DATA_HOME:-$HOME/.local/share}/flavours"
        if [ ! -d "$_data/base16/schemes" ]; then
            echo "flavours: baixando temas…"
            flavours update all 2>&1 || echo "flavours: aviso — alguns temas não puderam ser baixados."
        fi
        _current=$(flavours current 2>/dev/null || true)
        if [ -z "$_current" ]; then
            echo "flavours: nenhum tema ativo (use 'fox theme-pick')."
            exit 0
        fi
        echo "flavours: reaplicando $_current…"
        flavours apply "$_current"
        _cosmic_theme="$HOME/.cache/silverfox/cosmic-theme.ron"
        if command -v cosmic-settings >/dev/null 2>&1 && [ -f "$_cosmic_theme" ]; then
            cosmic-settings appearance import "$_cosmic_theme" >/dev/null 2>&1 \
                && echo "cosmic: tema importado." \
                || echo "cosmic: aviso — import falhou."
        fi
        if pgrep -x ghostty >/dev/null 2>&1; then
            gdbus call --session --dest com.mitchellh.ghostty \
                --object-path /com/mitchellh/ghostty \
                --method org.gtk.Actions.Activate reload-config '[]' '{}' >/dev/null 2>&1 \
                || pkill -USR2 ghostty 2>/dev/null \
                || true
        fi
    fi

# Mostra padrão da distro e tema atual; oferece lista para escolher e aplicar
theme-pick:
    #!/usr/bin/bash
    set -euo pipefail
    _default_dark="onedark"
    _default_light="one-light"
    _actual_current=$(flavours current 2>/dev/null || true)
    echo "padrão da distro : $_default_dark / $_default_light"
    echo "tema atual       : ${_actual_current:-(nenhum)}"
    echo ""
    _data="${XDG_DATA_HOME:-$HOME/.local/share}/flavours"
    if [ ! -d "$_data/base16/schemes" ]; then
        gum confirm "Temas não baixados. Baixar agora?" || exit 0
        flavours update all 2>&1 || echo "aviso: alguns temas não puderam ser baixados."
    fi
    _chosen=$(
        {
            if [ -n "$_actual_current" ] \
                && [ "$_actual_current" != "$_default_dark" ] \
                && [ "$_actual_current" != "$_default_light" ]; then
                echo "$_actual_current"
            fi
            echo "$_default_dark"
            echo "$_default_light"
            flavours list | tr ' ' '\n' \
                | grep -vxF "$_default_dark" \
                | grep -vxF "$_default_light" \
                | grep -vxF "${_actual_current:-__none__}"
        } | gum filter --placeholder "buscar tema…"
    ) || exit 0
    if [ -z "$_chosen" ]; then exit 0; fi
    gum spin --spinner dot --title "Aplicando $_chosen…" -- flavours apply "$_chosen"
    _cosmic_theme="$HOME/.cache/silverfox/cosmic-theme.ron"
    if command -v cosmic-settings >/dev/null 2>&1 && [ -f "$_cosmic_theme" ]; then
        cosmic-settings appearance import "$_cosmic_theme" >/dev/null 2>&1 || true
    fi
    if pgrep -x ghostty >/dev/null 2>&1; then
        gdbus call --session --dest com.mitchellh.ghostty \
            --object-path /com/mitchellh/ghostty \
            --method org.gtk.Actions.Activate reload-config '[]' '{}' >/dev/null 2>&1 \
            || pkill -USR2 ghostty 2>/dev/null \
            || true
    fi
    echo "tema aplicado: $_chosen"

# Toggle display of the login banner
motd-toggle:
    #!/usr/bin/bash
    if test -e "${HOME}/.config/no-show-user-motd"; then
      rm -f "${HOME}/.config/no-show-user-motd"
      echo "Banner enabled on next login."
    else
      mkdir -p "${HOME}/.config"
      touch "${HOME}/.config/no-show-user-motd"
      echo "Banner disabled."
    fi

# Show RPM diff vs the pending or previous deployment
os-changelog *args:
    rpm-ostree db diff {{args}}

# Roll back to the previous rpm-ostree deployment
os-rollback *args:
    #!/usr/bin/bash
    gum confirm "Fazer rollback para o deployment anterior?" || exit 0
    rpm-ostree rollback {{args}}
    echo "Reboot to apply."

# Show rpm-ostree deployment status
os-status *args:
    rpm-ostree status {{args}}

# Stage rpm-ostree upgrade
os-upgrade *args:
    rpm-ostree upgrade
    @echo "Reboot to apply the staged deployment."

