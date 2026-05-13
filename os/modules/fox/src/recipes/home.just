# home.just — `fox home <verb>` module. Loaded as `mod home` from
# sideral.justfile.

# Hard-reset sideral-managed paths in $HOME from /etc/skel
factory-reset *args:
    /usr/libexec/sideral/home-factory-reset.sh {{args}}

# First-time nix setup: stow flake + install nh + apply
home-init:
    #!/usr/bin/bash
    if ! command -v nix >/dev/null 2>&1; then
      echo "nix not ready. Wait for first-boot bootstrap or reboot, then retry."
      echo "  systemctl status sideral-nix-bootstrap"
      exit 1
    fi
    stow -R -d "$HOME/.config/sideral/stow" -t "$HOME" nix 2>/dev/null || true
    if ! command -v nh >/dev/null 2>&1; then
      echo "Installing nh..."
      nix profile install nixpkgs#nh
    fi
    echo "Applying home config..."
    nh home switch -c "$(whoami)"

# Re-apply the nix flake (stow then nh)
home-sync:
    #!/usr/bin/bash
    stow -R -d "$HOME/.config/sideral/stow" -t "$HOME" nix 2>/dev/null || true
    nh home switch -c "$(whoami)"

# Show pending changes without activating
home-diff:
    #!/usr/bin/bash
    nh home switch -c "$(whoami)" -- --dry-run 2>/dev/null \
      || nh home switch -c "$(whoami)" --dry 2>/dev/null \
      || echo "Dry-run not available with this nh version. Run 'fox home sync' to apply."

# Open the flake.nix in $EDITOR
home-edit:
    exec $EDITOR ~/.config/nix/flake.nix
