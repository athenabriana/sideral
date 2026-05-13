# sideral.justfile — operator-CLI recipe surface, dispatched by /usr/bin/fox.
# Verbs: chsh, cheatsheet, update, upgrade, rollback, status, cleanup,
# changelog, toggle-banner, upgrade-firmware, diff, edit, doctor
# (top-level) + home::factory-reset (module).

default:
    @just -f {{ justfile() }} --list

# Switch login shell (no arg = interactive picker; allowlist: bash, zsh)
chsh shell="":
    /usr/libexec/sideral/chsh.sh {{shell}}

# Open the sideral cheatsheet manpage (man 7 sideral)
cheatsheet:
    exec man 7 sideral

# Update installed flatpaks and sync nix config
update *args:
    #!/usr/bin/bash
    flatpak update {{args}}
    if command -v nh >/dev/null 2>&1; then
      echo "--- nix home switch ---"
      stow -R -d "$HOME/.config/sideral/stow" -t "$HOME" nix 2>/dev/null || true
      nh home switch --impure -c "$(whoami)"
    fi

# Stage rpm-ostree upgrade, flatpak update, and distrobox upgrade all at once
upgrade *args:
    #!/usr/bin/bash
    rpm-ostree upgrade "$@"
    echo "--- flatpak update ---"
    flatpak update -y
    if command -v distrobox >/dev/null 2>&1; then
      echo "--- distrobox upgrade ---"
      distrobox upgrade -a
    fi
    echo "Reboot to apply the staged deployment."

# Roll back to the previous rpm-ostree deployment
rollback *args:
    rpm-ostree rollback {{args}}
    @echo "Reboot to apply."

# Show rpm-ostree deployment status
status *args:
    rpm-ostree status {{args}}

# Clean podman images, unused flatpaks, rpm-ostree metadata, and nix store (default);
# with explicit args, passes through to rpm-ostree cleanup
cleanup *args:
    #!/usr/bin/bash
    if [ $# -eq 0 ]; then
      podman image prune -af
      flatpak uninstall --unused
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
    nh home switch --impure -c "$(whoami)" -- --dry-run 2>/dev/null \
      || nh home switch --impure -c "$(whoami)" --dry 2>/dev/null \
      || echo "Dry-run not available. Run 'fox sync' to apply."

# Open the nix flake in $EDITOR
edit:
    exec $EDITOR ~/.config/nix/flake.nix

mod home
