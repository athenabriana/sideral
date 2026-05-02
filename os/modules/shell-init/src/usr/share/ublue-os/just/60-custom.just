# sideral-specific ujust recipes.
#
# Loaded automatically by /usr/share/ublue-os/justfile via its
# `import? "/usr/share/ublue-os/just/60-custom.just"` line — the `?`
# makes the import optional; this file fills the slot.
#
# Run any recipe with `ujust <name>` (e.g. `ujust chsh fish`).
# Run `ujust` (no args) to list all recipes.

# Switch login shell. Defaults to zsh (sideral's recommended interactive
# shell — fish-parity for highlighting + autosuggestions via the two
# zsh-users plugins, plus bash-compatible syntax so your scripts and
# one-liners work unchanged). Pass `bash` or `fish` for those instead.
# Uses `sudo usermod -s` because ublue-os/main removes setuid `chsh`
# as part of its hardening pass — `usermod` is the equivalent root-
# only path.
#
# Examples:
#   ujust chsh           # → /usr/bin/zsh (default)
#   ujust chsh zsh       # → /usr/bin/zsh
#   ujust chsh fish      # → /usr/bin/fish
#   ujust chsh bash      # → /bin/bash
[group('System')]
chsh shell="zsh":
    #!/usr/bin/bash
    set -euo pipefail
    case "{{shell}}" in
        bash) target=/bin/bash ;;
        fish) target=/usr/bin/fish ;;
        zsh)  target=/usr/bin/zsh ;;
        *)
            echo "Unknown shell: {{shell}} (try: bash, fish, zsh)" >&2
            exit 1
            ;;
    esac
    if [ ! -x "$target" ]; then
        echo "$target not found — is it installed?" >&2
        exit 1
    fi
    current="$(getent passwd "$USER" | cut -d: -f7)"
    if [ "$current" = "$target" ]; then
        echo "Login shell is already $target — nothing to do."
        exit 0
    fi
    echo "Switching login shell: $current -> $target (for $USER)"
    sudo usermod -s "$target" "$USER"
    echo
    echo "Done. Log out and back in for the change to take effect,"
    echo "or run \`exec $target -l\` to swap your current session now."

# Initialize dotfiles from a chezmoi git repo. Wraps `chezmoi init
# --apply <url>`. On first run chezmoi clones the repo to
# ~/.local/share/chezmoi/ and applies its templates to $HOME.
# Subsequent updates: `chezmoi update`.
#
# Replaces the per-shell onboarding hint that used to print on first
# login — that hint became noise once the recipe existed (and was bash-
# only; this works for any login shell).
#
# Examples:
#   ujust chezmoi-init https://github.com/yourname/dotfiles
#   ujust chezmoi-init git@github.com:yourname/dotfiles.git
[group('Setup')]
chezmoi-init repo="":
    #!/usr/bin/bash
    set -euo pipefail
    if [ -z "{{repo}}" ]; then
        echo "Usage: ujust chezmoi-init <git-repo-url>" >&2
        echo "Example: ujust chezmoi-init https://github.com/yourname/dotfiles" >&2
        exit 1
    fi
    if [ ! -x /usr/bin/chezmoi ]; then
        echo "chezmoi not found — should ship via sideral-cli-tools" >&2
        exit 1
    fi
    chezmoi init --apply "{{repo}}"
