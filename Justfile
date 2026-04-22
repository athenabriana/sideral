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

# Push repo's home/ → live $HOME (overwrites tracked files, leaves untracked alone)
apply-home:
    rsync -a --info=NAME home/ $HOME/

# Pull live tracked dotfiles back into the repo (so git sees your edits)
capture-home:
    rsync -a --info=NAME --delete $HOME/.config/mise/ home/.config/mise/
    rsync -a --info=NAME $HOME/.bashrc home/.bashrc

# Show diff: repo vs live $HOME
diff-home:
    -diff -ruN $HOME/.config home/.config 2>&1 | head -200

# Rollback to the previous deployment
rollback:
    sudo rpm-ostree rollback
    @echo "Now run: systemctl reboot"
