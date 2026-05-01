# Sideral OS — local build + rebase recipes.
#   list:    `just`
#   build:   `just build`
#   rebase:  `just rebase`

image_name := "sideral"
image_tag  := "dev"
registry   := env_var_or_default("REGISTRY", "localhost")

default:
    @just --list --unsorted

# Build image locally with podman
build:
    podman build \
        --tag {{registry}}/{{image_name}}:{{image_tag}} \
        --file os/Containerfile \
        os

# Shellcheck every build script
lint:
    shellcheck os/*.sh os/features/*/post-install.sh

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

# Rollback to the previous deployment
rollback:
    sudo rpm-ostree rollback
    @echo "Now run: systemctl reboot"
