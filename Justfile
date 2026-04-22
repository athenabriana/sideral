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

# Install mise tools defined in /etc/mise/config.toml
mise-setup:
    @echo "Installing tools from /etc/mise/config.toml into your user mise dir..."
    mise install

# Push repo's home/ → live $HOME (overwrites tracked files, leaves untracked alone)
apply-home:
    rsync -a --info=NAME home/ $HOME/

# Pull live dotfiles back into repo's home/ (so git sees your edits)
capture-home:
    rsync -a --info=NAME --delete \
        --exclude 'wallpapers/' --exclude 'fonts/' \
        $HOME/.config/hypr/ home/.config/hypr/
    rsync -a --info=NAME --delete $HOME/.config/ags/   home/.config/ags/
    rsync -a --info=NAME --delete $HOME/.config/rofi/  home/.config/rofi/
    rsync -a --info=NAME --delete $HOME/.config/wlogout/ home/.config/wlogout/
    rsync -a --info=NAME --delete $HOME/.config/kitty/ home/.config/kitty/
    rsync -a --info=NAME --delete $HOME/.config/mise/  home/.config/mise/

# Show diff: repo vs live $HOME
diff-home:
    -diff -ruN $HOME/.config home/.config 2>&1 | head -200

# Rollback to previous deployment
rollback:
    sudo rpm-ostree rollback
    @echo "Now run: systemctl reboot"
