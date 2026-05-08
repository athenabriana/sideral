# sideral recipes — ported from the Fedora-flavor 60-custom.just for the
# NixOS branch. Loaded by the `njust` wrapper at /run/current-system/sw/bin/njust
# (a writeShellScriptBin that does `exec just --justfile /etc/sideral/sideral.just`).
#
# Run any recipe with `njust <name>` (e.g. `njust chsh nu`).
# Run `njust` (no args) to list all recipes.

# Switch login shell. With no argument, opens an interactive picker
# (gum/tv). Pass a shell name to skip the picker. Uses `sudo usermod
# -s` because setuid `chsh` is dropped by NixOS' default hardening —
# `usermod` is the equivalent root-only path.
#
# Examples:
#   njust chsh           # interactive picker
#   njust chsh zsh       # → /run/current-system/sw/bin/zsh  (default)
#   njust chsh bash      # → /run/current-system/sw/bin/bash
[group('System')]
chsh shell="":
    #!/usr/bin/env bash
    set -euo pipefail
    selected="{{shell}}"
    if [ -z "$selected" ]; then
        if command -v gum >/dev/null 2>&1; then
            selected="$(gum choose zsh bash)" || exit 0
        elif command -v tv >/dev/null 2>&1; then
            selected="$(printf 'zsh\nbash\n' | tv --preview-disabled --no-help)" || exit 0
        else
            echo "Pass a shell name explicitly: njust chsh [bash|zsh]" >&2
            exit 1
        fi
    fi
    case "$selected" in
        bash) target="$(command -v bash)" ;;
        zsh)  target="$(command -v zsh)" ;;
        *)
            echo "Unknown shell: $selected (try: bash, zsh)" >&2
            exit 1
            ;;
    esac
    if [ -z "$target" ] || [ ! -x "$target" ]; then
        echo "$selected not found on PATH — is it installed?" >&2
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

# Cheatsheet of behavior differences vs. a stock NixOS install — what
# you actually need to know after installing sideral. Skips drop-in
# replacements (eza, bat, rg, podman) past one summary line each since
# their interfaces match what they replace; spends space on the things
# that change muscle memory.
[group('Help')]
tools:
    #!/usr/bin/env bash
    _urllink() { printf '\e]8;;%s\e\\%s\e]8;;\e\\' "$1" "$2"; }
    B=$'\e[1m'; D=$'\e[2m'; R=$'\e[0m'
    cat <<EOF

    ${B}Editor split${R} — \$EDITOR=hx, \$VISUAL=code
      Tools that check \$VISUAL first (Ctrl+P below, some git frontends)
      land in VS Code. Everything else (git commit, sudoedit, mise edit,
      crontab -e, less's \`v\` key, ssh sessions) lands in Helix.
      ${D}hx is selection-first modal — try \`hx --tutor\` if new to it.${R}

    ${B}Navigation${R} — what changes from stock bash
      z <partial>     ${D}NEW.${R} zoxide jump by frecency. Replaces \`cd long/path\`
                      with \`z partial\`. \`z\` alone → highest-frecency match.
      cd "$(tv dirs)" ${D}NEW.${R} pick a directory via television, cd in.
      Ctrl+P          ${D}NEW.${R} tv-driven file picker → opens in \$VISUAL.
                      Like VS Code's Quick Open but shell-side.
      Ctrl+R          ${D}REPLACED.${R} atuin replaces bash's reverse-i-search.
                      Adds: fuzzy match, cwd/exit-code/duration metadata,
                      cross-shell history, optional sync.
      Ctrl+T          ${D}NEW.${R} tv files → paste path at cursor.
      Ctrl+S          ${D}NEW.${R} toggle \`sudo \` prefix on the current line.
      Ctrl+G          ${D}NEW.${R} tv-driven git branch picker → checkout.
      Ctrl+E          ${D}NEW.${R} launch yazi — cd to where you exit.
      Ctrl+/          ${D}NEW.${R} launch television channel picker.

    ${B}Containers${R} — there is no docker daemon
      \`docker ...\`    runs podman (via virtualisation.podman.dockerCompat).
                      No daemon to start, rootless by default.
      podman-compose  drop-in for \`docker compose up\`. ~95% spec parity.

    ${B}Runtime versions${R}
      mise            polyglot version manager (Node, Python, Go, Ruby,
                      Rust, etc.) driven by .mise.toml per project.
                      \`mise install\`, \`mise use python@3.13\`.

    ${B}Drop-in replacements${R} — same interface, just better
      ls / ll / la / lt / tree    → eza (icons, git status, grouping)
      cat <file>                  → bat (syntax color when output is TTY)
      grep -r                     → rg (respects .gitignore, faster)
      ${D}\\\\ls / \\\\cat skip the alias and hit GNU coreutils for scripts.${R}

    ${B}Shells${R} — zsh is default; bash always present
      njust chsh        switch (default: zsh)
      njust chsh bash   stay on bash

    ${B}Other njust recipes${R}
      njust                       list every recipe
      njust chezmoi               chezmoi cheatsheet (personal dotfiles)
      njust chezmoi-init <repo>   bootstrap chezmoi from your dotfiles repo
      njust apply-defaults        no-op note (defaults apply at activation)
      njust gdrive-setup          set up Google Drive auto-mount at ~/gdrive
      njust gdrive-remove         disable auto-mount; optionally wipe config
      njust update                nixos-rebuild switch --upgrade
      njust theme <wallpaper>     regenerate Material 3 palette (ghostty + helix)
      njust niri                  niri keybind cheatsheet

    EOF
    echo "    Source: $(_urllink "https://github.com/athenabriana/sideral" "github.com/athenabriana/sideral")"
    echo

# Bootstrap chezmoi from your dotfiles repo. The image-defaults seed is
# applied by home-manager at activation; this recipe is the escape hatch
# for users who bring their own dotfiles repo on top.
#
# Examples:
#   njust chezmoi-init https://github.com/yourname/dotfiles
#   njust chezmoi-init git@github.com:yourname/dotfiles.git
[group('Setup')]
chezmoi-init repo="":
    #!/usr/bin/env bash
    set -euo pipefail
    target="{{repo}}"
    if [ -z "$target" ]; then
        echo "Usage: njust chezmoi-init <repo-url>" >&2
        echo "Example: njust chezmoi-init https://github.com/yourname/dotfiles" >&2
        exit 1
    fi
    if ! command -v chezmoi >/dev/null 2>&1; then
        echo "chezmoi not found — should ship via os/modules/cli-tools" >&2
        exit 1
    fi
    if [ -d "$HOME/.local/share/chezmoi" ] && [ -n "$(ls -A "$HOME/.local/share/chezmoi" 2>/dev/null)" ]; then
        echo "$HOME/.local/share/chezmoi is not empty — chezmoi is already initialised."
        echo "Use \`chezmoi update\` to pull latest, or remove the dir to re-init."
        exit 1
    fi
    chezmoi init --apply "$target"

# Disable the auto-mount and unmount ~/gdrive. Leaves the rclone remote
# config in place by default so re-running \`njust gdrive-setup\` later
# is a one-step re-enable (no OAuth re-walk).
[group('Setup')]
gdrive-remove:
    #!/usr/bin/env bash
    set -euo pipefail
    target="$HOME/gdrive"

    if systemctl --user is-enabled rclone-gdrive.service >/dev/null 2>&1 \
       || systemctl --user is-active rclone-gdrive.service >/dev/null 2>&1; then
        echo "Disabling rclone-gdrive.service..."
        systemctl --user disable --now rclone-gdrive.service || true
    else
        echo "rclone-gdrive.service already disabled."
    fi

    if mountpoint -q "$target" 2>/dev/null; then
        echo "Force-unmounting $target..."
        fusermount3 -u "$target" 2>/dev/null || fusermount -u "$target" 2>/dev/null || true
    fi

    echo
    echo "Auto-mount disabled. Google Drive will not mount on next login."
    echo "rclone gdrive: remote config is still in place — re-run"
    echo "\`njust gdrive-setup\` to turn it back on without OAuth."
    echo

    if command -v gum >/dev/null 2>&1 && gum confirm "Also remove the rclone gdrive: remote config?"; then
        if command -v rclone >/dev/null 2>&1 \
           && rclone listremotes 2>/dev/null | grep -q '^gdrive:$'; then
            rclone config delete gdrive
            echo "Removed rclone gdrive: remote."
        fi
        if [ -d "$target" ] && [ -z "$(ls -A "$target" 2>/dev/null)" ]; then
            rmdir "$target"
            echo "Removed empty $target directory."
        elif [ -d "$target" ]; then
            echo "Leaving $target in place — directory not empty."
        fi
    fi

# One-command Google Drive setup. Idempotent — safe to run multiple
# times. Walks rclone OAuth on first run, enables the rclone-gdrive
# systemd user unit, mounts at ~/gdrive.
[group('Setup')]
gdrive-setup:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v rclone >/dev/null 2>&1; then
        echo "rclone not found — should ship via os/modules/cli-tools" >&2
        exit 1
    fi

    if rclone listremotes 2>/dev/null | grep -q '^gdrive:$'; then
        echo "rclone gdrive: remote already configured — skipping OAuth."
    else
        echo "Setting up Google Drive remote in rclone."
        echo "Your browser will open for the Google OAuth consent screen."
        echo "Say YES when prompted to use auto-config."
        echo
        rclone config create gdrive drive
    fi

    systemctl --user enable --now rclone-gdrive.service
    sleep 1
    if mountpoint -q "$HOME/gdrive" 2>/dev/null; then
        echo
        echo "Done. Google Drive is mounted at $HOME/gdrive and will"
        echo "auto-mount on every login from now on."
    else
        echo
        echo "Service enabled but mount didn't come up — check:" >&2
        echo "  journalctl --user -u rclone-gdrive.service" >&2
        exit 1
    fi

# Pull updated image defaults. On NixOS, defaults are materialised at
# activation by home-manager and the system module evaluator — this
# recipe is informational only.
[group('Setup')]
apply-defaults:
    @echo "Defaults are applied at activation; run \`sudo nixos-rebuild switch --flake .#sideral\` to refresh them."

# Pull image updates. Equivalent to \`rpm-ostree upgrade\` on the Fedora
# flavor — runs \`nixos-rebuild switch --upgrade\` against the published
# flake on github:athenabriana/sideral. Variant is read from /etc/os-release.
[group('System')]
update:
    #!/usr/bin/env bash
    set -euo pipefail
    variant="$(. /etc/os-release; echo "${VARIANT_ID:-open-source}")"
    case "$variant" in
        nvidia) target="sideral-nvidia" ;;
        *)      target="sideral" ;;
    esac
    echo "Pulling latest sideral closure (target: $target)..."
    sudo nixos-rebuild switch --upgrade --flake "github:athenabriana/sideral#$target"
    echo
    echo "Done. Reboot only if kernel/initrd changed (\`systemctl reboot\` if so)."

# chezmoi cheatsheet — personal dotfiles. The image-default seed is
# delivered by home-manager at activation; chezmoi is the per-user
# escape hatch for layering your own repo on top.
[group('Help')]
chezmoi:
    #!/usr/bin/env bash
    _urllink() { printf '\e]8;;%s\e\\%s\e]8;;\e\\' "$1" "$2"; }
    B=$'\e[1m'; D=$'\e[2m'; R=$'\e[0m'
    cat <<EOF

    ${B}chezmoi — dotfile manager${R}
    ${D}Manages your personal dotfiles from a git repo.${R}

    ${B}Image defaults${R}
      Image defaults (niri/noctalia/ghostty/mise/bashrc/zshrc/...)
      are materialised by home-manager at \`nixos-rebuild switch\` time.
      No first-login bootstrap. To refresh after an image update:
        sudo nixos-rebuild switch --flake .#sideral

    ${B}Personal dotfiles${R} — your own git repo (optional escape hatch)
      njust chezmoi-init <repo>     bootstrap from your dotfiles repo.
                                    Clones to ~/.local/share/chezmoi/ and
                                    applies all managed files to \$HOME.
      chezmoi update                pull latest from your repo + apply.
      chezmoi diff                  show what would change before applying.
      chezmoi apply                 apply current source state to \$HOME.
      chezmoi add <file>            start tracking a file in your repo.
      chezmoi edit <file>           edit source for a tracked file (\$EDITOR).

    ${B}Interaction with home-manager-managed files${R}
      home-manager writes via Nix store symlinks; chezmoi sees those as
      "not under chezmoi management" and won't touch them on \`chezmoi apply\`
      unless you explicitly \`chezmoi add\` them. If you do, your repo wins.

    ${B}Examples${R}
      njust chezmoi-init https://github.com/yourname/dotfiles
      njust chezmoi-init git@github.com:yourname/dotfiles.git
      chezmoi add ~/.config/ghostty/config
      chezmoi edit ~/.bashrc

    EOF
    echo "    Source: $(_urllink "https://chezmoi.io" "chezmoi.io") | $(_urllink "https://github.com/athenabriana/sideral" "github.com/athenabriana/sideral")"
    echo

# Apply a wallpaper and regenerate the Material 3 palette for ghostty +
# helix via matugen. Noctalia's own wallpaper picker handles the bar /
# launcher / notification recolor through its built-in matugen pipeline;
# this recipe handles the terminal and editor side.
[group('Desktop')]
theme wallpaper="":
    #!/usr/bin/env bash
    set -euo pipefail
    target="{{wallpaper}}"
    if [ -z "$target" ]; then
        echo "Usage: njust theme <path-to-image>" >&2
        echo "Example: njust theme ~/Pictures/wallpaper.jpg" >&2
        exit 1
    fi
    if [ ! -f "$target" ]; then
        echo "File not found: $target" >&2
        exit 1
    fi
    if ! command -v matugen >/dev/null 2>&1; then
        echo "matugen not found — should ship via os/modules/niri-defaults" >&2
        exit 1
    fi
    if [ ! -f "$HOME/.config/matugen/config.toml" ]; then
        mkdir -p "$HOME/.config/matugen/templates"
        if [ -f /etc/xdg/matugen/config.toml ]; then
            cp /etc/xdg/matugen/config.toml "$HOME/.config/matugen/config.toml"
            cp -r /etc/xdg/matugen/templates/. "$HOME/.config/matugen/templates/"
        fi
    fi
    echo "Running matugen on $target..."
    matugen image "$target"
    pkill -USR1 ghostty 2>/dev/null || true
    echo
    echo "Done. ghostty palette written to ~/.config/ghostty/config-matugen"
    echo "      helix theme written to ~/.config/helix/themes/sideral.toml"
    echo
    echo "For the bar / launcher / notifications: use Noctalia's wallpaper"
    echo "picker — Noctalia drives its own matugen pipeline separately."
    echo
    echo "To activate ghostty palette, add to ~/.config/ghostty/config:"
    echo "  config-file = ~/.config/ghostty/config-matugen"
    echo "To activate helix theme, add to ~/.config/helix/config.toml:"
    echo '  [editor]'
    echo '  theme = "sideral"'

# Niri + Noctalia desktop cheatsheet — default keybinds, theming,
# and override paths.
[group('Help')]
niri:
    #!/usr/bin/env bash
    _urllink() { printf '\e]8;;%s\e\\%s\e]8;;\e\\' "$1" "$2"; }
    B=$'\e[1m'; D=$'\e[2m'; R=$'\e[0m'
    cat <<EOF

    ${B}niri — scrollable-tiling Wayland compositor${R}
    ${D}Modifier key is Super (Win/Cmd). Keybinds from /etc/xdg/niri/config.kdl.${R}

    ${B}Session${R}
      Mod+T           open ghostty terminal
      Mod+Space       open Noctalia launcher (app search + run)
      Mod+F           open file manager (nautilus)
      Mod+Q           close focused window
      Mod+Tab         toggle overview

    ${B}Scrollable tiling navigation${R}
      Mod+Left / Right   focus column left / right
      Mod+Up / Down      focus window up / down within a column
      Mod+Shift+Left / Right   move column left / right
      Mod+M           maximize focused column
      Mod+- / =       cycle column width preset back / forward
      Mod+1…9         switch to workspace 1–9
      Mod+Shift+1…9   move focused column to workspace 1–9
      ${D}Windows tile side-by-side in scrollable columns (PaperWM-style).${R}

    ${B}Screenshots${R}
      Print             region → clipboard (drag to select)
      Shift+Print       full screen → clipboard

    ${B}Audio${R}
      XF86AudioRaiseVolume / LowerVolume / Mute / MicMute

    ${B}Theming${R}
      njust theme <image>   regenerate Material 3 palette from a wallpaper

    ${B}Config override paths${R}
      ~/.config/niri/config.kdl              niri keybinds + layout
      ~/.config/matugen/config.toml          matugen template targets
      ~/.config/noctalia/settings.json       Noctalia settings
      /etc/xdg/quickshell/noctalia-shell/    Noctalia QML (system-owned;
                                             override per-user via chezmoi)

    ${B}NVIDIA variant${R}
      debug { disable-cursor-plane } — active by default (VRR cursor fix)
      See os/modules/niri-defaults/README.md for full NVIDIA notes.

    EOF
    echo "    Source: $(_urllink "https://github.com/athenabriana/sideral" "github.com/athenabriana/sideral")"
    echo
