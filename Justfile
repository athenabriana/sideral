# sideral OS — local build + rebase recipes (NixOS flavor).
#   list:        `just`
#   build:       `just build`
#   build-iso:   `just build-iso`
#   rebase:      `just rebase`
#   rollback:    `just rollback`

default:
    @just --list --unsorted

# `nix flake check` evaluates the flake (fast eval-only validation) +
# alejandra format check. Use this before pushing to catch silly typos.
lint:
    nix flake check
    nix fmt -- --check

# Format every .nix file in the tree (alejandra).
fmt:
    nix fmt

# Build the open-source closure (sideral host).
build:
    nix build .#nixosConfigurations.sideral.config.system.build.toplevel

# Build the NVIDIA closure.
build-nvidia:
    nix build .#nixosConfigurations.sideral-nvidia.config.system.build.toplevel

# Build the installer-only ISO. Output lands in result/iso/sideral_x86_64.iso.
build-iso:
    nix build .#sideral-iso

# Switch the running system to the local flake (open-source variant).
rebase:
    sudo nixos-rebuild switch --flake .#sideral
    @echo "Switched. Reboot only if kernel/initrd changed (\`systemctl reboot\` if so)."

# Switch to the NVIDIA variant.
rebase-nvidia:
    sudo nixos-rebuild switch --flake .#sideral-nvidia
    @echo "Switched. Reboot only if kernel/initrd changed."

# Roll back to the previous generation.
rollback:
    sudo nixos-rebuild switch --rollback
    @echo "Rolled back to previous generation."

# Show derivation diff vs the running system (useful before `just rebase`).
diff:
    nix store diff-closures \
        /run/current-system \
        $(nix path-info .#nixosConfigurations.sideral.config.system.build.toplevel)

# Update flake inputs (nixpkgs / home-manager / nix-flatpak) to latest.
update:
    nix flake update

# Garbage-collect the nix store — keep the last 14 days of generations.
clean:
    sudo nix-collect-garbage --delete-older-than 14d

# Pull the CI-built nixosConfiguration from GitHub and switch to it
# (mirrors `njust update` from inside the running system).
rebase-latest:
    sudo nixos-rebuild switch --upgrade --flake github:athenabriana/sideral#sideral
