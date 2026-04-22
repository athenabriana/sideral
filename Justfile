# Athena OS — local build recipes.
#   list:    `just`
#   build:   `just build`
#   rebase:  `just rebase`

image_name := "athena-os"
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

# Shellcheck all build scripts
lint:
    shellcheck build_files/*.sh

# Rebase host to locally-built image (needs reboot after)
rebase:
    sudo rpm-ostree rebase \
        ostree-unverified-image:containers-storage:{{registry}}/{{image_name}}:{{image_tag}}
    @echo "Now run: systemctl reboot"

# Pull the CI-built image and rebase to it
rebase-latest gh_user:
    sudo rpm-ostree rebase \
        ostree-unverified-registry:ghcr.io/{{gh_user}}/{{image_name}}:latest
    @echo "Now run: systemctl reboot"

# Remove the local image
clean:
    -podman rmi {{registry}}/{{image_name}}:{{image_tag}}

# Show what would change vs. current deployment
diff:
    sudo rpm-ostree db diff

# Rollback to previous deployment
rollback:
    sudo rpm-ostree rollback
    @echo "Now run: systemctl reboot"
