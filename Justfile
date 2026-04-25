# Athens OS — local build + dotfile recipes.
#   list:    `just`
#   build:   `just build`
#   rebase:  `just rebase`

image_name := "athens-os"
image_tag  := "dev"
registry   := env_var_or_default("REGISTRY", "localhost")

default:
    @just --list --unsorted

# Build image locally with podman
build:
    podman build \
        --tag {{registry}}/{{image_name}}:{{image_tag}} \
        --file Containerfile \
        .

# Shellcheck every build script
lint:
    shellcheck build_files/*.sh build_files/features/*/post-install.sh

# Rebase host to the locally-built image (requires reboot after)
rebase:
    sudo rpm-ostree rebase \
        ostree-unverified-image:containers-storage:{{registry}}/{{image_name}}:{{image_tag}}
    @echo "Now run: systemctl reboot"

# Pull the CI-built image and rebase to it
rebase-latest gh_user:
    sudo rpm-ostree rebase \
        ostree-unverified-registry:ghcr.io/{{gh_user}}/{{image_name}}:latest
    @echo "Now run: systemctl reboot"

# Remove the local dev image
clean:
    -podman rmi {{registry}}/{{image_name}}:{{image_tag}}

# Show RPM-level diff vs the current deployment
diff:
    sudo rpm-ostree db diff

# home.nix lives under athens-os-user's src tree (athens-copr feature).
home_nix := "packages/athens-os-user/src/etc/skel/.config/home-manager/home.nix"

# Edit the repo's home.nix in $EDITOR (falls back to vi)
home-edit:
    ${EDITOR:-vi} {{home_nix}}

# Apply the repo's home.nix to live $HOME via home-manager switch
home-apply:
    home-manager switch -f {{home_nix}}

# Preview what `home-apply` would change vs the currently-active generation
home-diff:
    home-manager build -f {{home_nix}}
    @echo "Built generation above; compare via: home-manager generations"

# Rollback to the previous deployment
rollback:
    sudo rpm-ostree rollback
    @echo "Now run: systemctl reboot"
