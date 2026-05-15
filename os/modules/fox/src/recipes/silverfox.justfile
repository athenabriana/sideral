default:
    @just -f {{ justfile() }} --list

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

clean *args:
    #!/usr/bin/bash
    if [ $# -eq 0 ]; then
      gum confirm "Clean podman images, rpm-ostree cache, and nix store?" || exit 0
      podman image prune -af
      rpm-ostree cleanup -prm
      command -v nh >/dev/null 2>&1 && nh clean || echo "nh not installed, skipping nix cleanup"
    else
      rpm-ostree cleanup "$@"
    fi

dotfiles-sync:
    #!/usr/bin/bash
    set -euo pipefail
    SKEL="/etc/skel/Dotfiles"
    HOME_DOTFILES="$HOME/Dotfiles"
    [ -d "$SKEL" ] || { echo "/etc/skel/Dotfiles not found" >&2; exit 1; }
    if [ ! -d "$HOME_DOTFILES" ]; then
        echo "~/Dotfiles missing — restoring from $SKEL…"
        cp -a "$SKEL" "$HOME_DOTFILES"
    fi
    while IFS= read -r -d '' f; do
        if grep -q '__USER__' "$f" 2>/dev/null; then
            echo "Replacing __USER__ → $USER in ${f#"$HOME_DOTFILES/home-manager/"}"
            sed -i "s/__USER__/$USER/g" "$f"
        fi
    done < <(find "$HOME_DOTFILES/home-manager" -type f -print0 2>/dev/null || true)
    if command -v stow >/dev/null 2>&1 && [ -d "$HOME_DOTFILES/stow" ]; then
        find "$HOME_DOTFILES/stow" -mindepth 1 -maxdepth 1 -type d -print0 \
          | while IFS= read -r -d '' pkg; do
              stow -R -d "$HOME_DOTFILES/stow" -t "$HOME" "${pkg##*/}" || true
            done
    fi
    echo "dotfiles: synced."

edit:
    #!/usr/bin/bash
    [ -d "$HOME/Dotfiles" ] || { echo "~/Dotfiles does not exist — run 'fox dotfiles-sync'" >&2; exit 1; }
    if command -v zed >/dev/null 2>&1; then
        exec zed "$HOME/Dotfiles"
    elif command -v xdg-open >/dev/null 2>&1; then
        exec xdg-open "$HOME/Dotfiles"
    else
        echo "Neither zed nor xdg-open found" >&2
        exit 1
    fi

firmware-upgrade:
    fwupdmgr refresh --force
    fwupdmgr get-updates
    fwupdmgr update

diff:
    #!/usr/bin/bash
    nh home switch --impure --dry 2>/dev/null \
      || echo "Dry-run not available. Run 'fox sync' to apply."

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
    echo "=== NH_HOME_FLAKE ==="
    echo "${NH_HOME_FLAKE:-<unset>}"
    echo "=== flake ==="
    _flake_dir="${NH_HOME_FLAKE:-$HOME/Dotfiles/home-manager}"
    if [ -e "$_flake_dir/flake.nix" ]; then
      echo "found: $_flake_dir/flake.nix"
      [ -f "$_flake_dir/flake.lock" ] && echo "lock: ok" || echo "lock: ausente (run 'nix flake update' para gerar)"
    else
      echo "flake not found at $_flake_dir"
      echo "Run 'fox sync' to bootstrap from skel."
    fi

sync *args:
    #!/usr/bin/bash
    just -f {{ justfile() }} dotfiles-sync
    if command -v nh >/dev/null 2>&1; then
        echo "nix/home-manager: applying configuration…"
        _flake="${NH_HOME_FLAKE:-$HOME/Dotfiles/home-manager}"
        if [ -f "$_flake/flake.lock" ]; then
            (cd "$_flake" && nix flake update silverfox 2>/dev/null) || true
        fi
        nh home switch --impure "$_flake"
    else
        echo "nh not found — skipping nix sync."
    fi

theme-sync:
    #!/usr/bin/bash
    set -euo pipefail
    if command -v flavours >/dev/null 2>&1; then
        _data="${XDG_DATA_HOME:-$HOME/.local/share}/flavours"
        if [ ! -d "$_data/base16/schemes" ]; then
            echo "flavours: baixando temas…"
            flavours update all 2>&1 || echo "flavours: warning — some themes could not be downloaded."
        fi
        _current=$(flavours current 2>/dev/null || true)
        if [ -z "$_current" ]; then
            echo "flavours: no active theme (use 'fox theme-pick')."
            exit 0
        fi
        echo "flavours: reapplying $_current…"
        flavours apply "$_current"
        _cosmic_theme="$HOME/.cache/silverfox/cosmic-theme.ron"
        if command -v cosmic-settings >/dev/null 2>&1 && [ -f "$_cosmic_theme" ]; then
            cosmic-settings appearance import "$_cosmic_theme" >/dev/null 2>&1 \
                && echo "cosmic: theme imported." \
                || echo "cosmic: warning — import failed."
        fi
        if pgrep -x ghostty >/dev/null 2>&1; then
            gdbus call --session --dest com.mitchellh.ghostty \
                --object-path /com/mitchellh/ghostty \
                --method org.gtk.Actions.Activate reload-config '[]' '{}' >/dev/null 2>&1 \
                || pkill -USR2 ghostty 2>/dev/null \
                || true
        fi
    fi

theme-pick:
    #!/usr/bin/bash
    set -euo pipefail
    _default_dark="onedark"
    _default_light="one-light"
    _actual_current=$(flavours current 2>/dev/null || true)
    echo "distro default : $_default_dark / $_default_light"
    echo "current theme  : ${_actual_current:-(none)}"
    echo ""
    _data="${XDG_DATA_HOME:-$HOME/.local/share}/flavours"
    if [ ! -d "$_data/base16/schemes" ]; then
        gum confirm "Themes not downloaded. Download now?" || exit 0
        flavours update all 2>&1 || echo "warning: some themes could not be downloaded."
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
        } | gum filter --placeholder "search theme…"
    ) || exit 0
    if [ -z "$_chosen" ]; then exit 0; fi
    gum spin --spinner dot --title "Applying $_chosen…" -- flavours apply "$_chosen"
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
    echo "theme applied: $_chosen"

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

os-changelog *args:
    rpm-ostree db diff {{args}}

os-rollback *args:
    #!/usr/bin/bash
    gum confirm "Rollback to the previous deployment?" || exit 0
    rpm-ostree rollback {{args}}
    echo "Reboot to apply."

os-status *args:
    rpm-ostree status {{args}}

os-upgrade *args:
    rpm-ostree upgrade
    @echo "Reboot to apply the staged deployment."

