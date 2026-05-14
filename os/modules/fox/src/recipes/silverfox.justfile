# silverfox.justfile — operator-CLI recipe surface, dispatched by /usr/bin/fox.
# Verbs: chsh, sync, upgrade, rollback, status, clean, changelog,
# toggle-banner, upgrade-firmware, diff, doctor, config (top-level).

default:
    @just -f {{ justfile() }} --list

# Switch login shell (no arg = interactive picker; allowlist: bash, zsh)
chsh shell="":
    /usr/libexec/silverfox/chsh.sh {{shell}}

# Aplica symlinks de ~/Dotfiles em $HOME
"dotfiles link":
    #!/usr/bin/bash
    set -euo pipefail
    command -v stow >/dev/null 2>&1 || { echo "stow não encontrado" >&2; exit 1; }
    [ -d "$HOME/Dotfiles" ] || { echo "~/Dotfiles não existe" >&2; exit 1; }
    find "$HOME/Dotfiles" -mindepth 1 -maxdepth 1 -type d -print0 \
      | while IFS= read -r -d '' pkg; do
          stow -R -d "$HOME/Dotfiles" -t "$HOME" --no-folding "${pkg##*/}"
        done
    echo "dotfiles: symlinks aplicados."

# Destroi ~/Dotfiles/ e recopia do /etc/skel/Dotfiles, depois reaplica stow
"dotfiles reset":
    #!/usr/bin/bash
    set -euo pipefail
    SKEL_DOTFILES="/etc/skel/Dotfiles"
    HOME_DOTFILES="$HOME/Dotfiles"
    [ -d "$SKEL_DOTFILES" ] || { echo "/etc/skel/Dotfiles não encontrado" >&2; exit 1; }
    echo "Removendo $HOME_DOTFILES..."
    rm -rf "$HOME_DOTFILES"
    echo "Copiando de $SKEL_DOTFILES..."
    cp -a "$SKEL_DOTFILES" "$HOME_DOTFILES"
    echo "Aplicando symlinks via stow..."
    command -v stow >/dev/null 2>&1 || { echo "stow não encontrado" >&2; exit 1; }
    find "$HOME_DOTFILES" -mindepth 1 -maxdepth 1 -type d -print0 \
      | while IFS= read -r -d '' pkg; do
          stow -R -d "$HOME_DOTFILES" -t "$HOME" --no-folding "${pkg##*/}"
        done
    echo "dotfiles reset: concluído."

# Sync nix config (packages + flatpaks declarativos)
sync *args:
    #!/usr/bin/bash
    just -f {{ justfile() }} "dotfiles link"
    command -v nh >/dev/null 2>&1 && nh home switch --impure

# Stage rpm-ostree upgrade.
upgrade *args:
    rpm-ostree upgrade
    @echo "Reboot to apply the staged deployment."

# Roll back to the previous rpm-ostree deployment
rollback *args:
    rpm-ostree rollback {{args}}
    @echo "Reboot to apply."

# Show rpm-ostree deployment status
status *args:
    rpm-ostree status {{args}}

# Clean podman images, rpm-ostree metadata, and nix store (default);
# with explicit args, passes through to rpm-ostree cleanup
clean *args:
    #!/usr/bin/bash
    if [ $# -eq 0 ]; then
      podman image prune -af
      rpm-ostree cleanup -prm
      command -v nh >/dev/null 2>&1 && nh clean || echo "nh not installed, skipping nix cleanup"
    else
      rpm-ostree cleanup "$@"
    fi

# Show RPM diff vs the pending or previous deployment
changelog *args:
    rpm-ostree db diff {{args}}

# Toggle display of the login banner
toggle-banner:
    #!/usr/bin/bash
    if test -e "${HOME}/.config/no-show-user-motd"; then
      rm -f "${HOME}/.config/no-show-user-motd"
      echo "Banner enabled on next login."
    else
      mkdir -p "${HOME}/.config"
      touch "${HOME}/.config/no-show-user-motd"
      echo "Banner disabled."
    fi

# Update device firmware (fwupdmgr)
upgrade-firmware:
    fwupdmgr refresh --force
    fwupdmgr get-updates
    fwupdmgr update

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
    echo "=== flake symlink ==="
    if [ -L "$HOME/.config/nix/flake.nix" ]; then
      echo "symlink: $(readlink -f "$HOME/.config/nix/flake.nix")"
      nix flake check "$HOME/.config/nix" 2>&1 || echo "flake check FAILED — run 'fox sync' to update"
    else
      echo "~/.config/nix/flake.nix not found or not a symlink"
      echo "Run 'fox sync' to set up the starter flake."
    fi

# Show pending nix config changes (dry-run)
diff:
    #!/usr/bin/bash
    nh home switch --impure --dry 2>/dev/null \
      || echo "Dry-run not available. Run 'fox sync' to apply."

# Open the Dotfiles stow tree in $EDITOR
config:
    exec $EDITOR ~/Dotfiles

