# sideral-specific ujust recipes.
#
# Loaded automatically by /usr/share/ublue-os/justfile via its
# `import? "/usr/share/ublue-os/just/60-custom.just"` line — the `?`
# makes the import optional; this file fills the slot.
#
# Run any recipe with `ujust <name>` (e.g. `ujust chsh fish`).
# Run `ujust` (no args) to list all recipes.

# Switch login shell. With no argument, opens an interactive picker
# (ugum/fzf). Pass a shell name to skip the picker. Uses `sudo usermod
# -s` because ublue-os/main removes setuid `chsh` as part of its
# hardening pass — `usermod` is the equivalent root-only path.
#
# Examples:
#   ujust chsh           # interactive picker (recommended)
#   ujust chsh zsh       # → /usr/bin/zsh
#   ujust chsh fish      # → /usr/bin/fish
#   ujust chsh bash      # → /bin/bash
[group('System')]
chsh shell="":
    #!/usr/bin/bash
    set -euo pipefail
    selected="{{shell}}"
    if [ -z "$selected" ]; then
        # ugum is the ublue gum-or-fzf wrapper; falls through to fzf
        # if gum isn't installed, which it isn't on sideral by default.
        selected="$(ugum choose zsh fish bash)" || exit 0
    fi
    case "$selected" in
        bash) target=/bin/bash ;;
        fish) target=/usr/bin/fish ;;
        zsh)  target=/usr/bin/zsh ;;
        *)
            echo "Unknown shell: $selected (try: bash, fish, zsh)" >&2
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

# Cheatsheet of behavior differences vs. a stock Fedora install — what
# you actually need to know after installing sideral. Skips the
# drop-in-replacement tools (eza, bat, rg, podman) past one summary
# line each since their interfaces match what they replace; spends
# space on the things that change muscle memory.
[group('Help')]
tools:
    #!/usr/bin/bash
    # Urllink renders modern terminal hyperlinks (OSC 8); falls back
    # gracefully on terminals that ignore the escape.
    source /usr/lib/ujust/libformatting.sh
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
      zi              ${D}NEW.${R} interactive zoxide picker (fzf-backed).
      Ctrl+P          ${D}NEW.${R} fzf-driven file picker → opens in \$VISUAL.
                      Like VS Code's Quick Open but shell-side.
      Ctrl+R          ${D}REPLACED.${R} atuin replaces bash's reverse-i-search.
                      Adds: fuzzy match, cwd/exit-code/duration metadata,
                      cross-shell history, optional sync.
      Ctrl+T          ${D}NEW.${R} fzf — paste a file path at cursor.
      Alt+C           ${D}NEW.${R} fzf — cd into a subdir picked from the tree.
      Alt+S           ${D}NEW.${R} toggle \`sudo \` prefix on the current line.
                      Useful for "type cmd → realize you need root → Alt+S".
      Ctrl+G          ${D}NEW.${R} fzf-driven git branch picker → checkout.
                      No-op outside a git repo.

    ${B}Containers${R} — there is no docker daemon
      \`docker ...\`    runs podman (via podman-docker shim). No daemon
                      to start, rootless by default. \$DOCKER_HOST points
                      at the per-user podman socket so testcontainers,
                      IDE plugins, and docker-compose binaries that
                      consult \$DOCKER_HOST all see the rootless engine.
      podman-compose  drop-in for \`docker compose up\`. ~95% spec parity;
                      known gaps: Compose-spec \`extends\`, some BuildKit-
                      specific build args, host-network on rootless.

    ${B}Runtime versions${R}
      mise            polyglot version manager (Node, Python, Go, Ruby,
                      Rust, etc.) driven by .mise.toml per project. PATH
                      switches automatically when you cd into a managed
                      directory. Replaces nvm/pyenv/rbenv/asdf with one
                      tool. \`mise install\`, \`mise use python@3.13\`.

    ${B}Drop-in replacements${R} — same interface, just better
      ls / ll / la / lt / tree    → eza (icons, git status, grouping)
      cat <file>                  → bat (syntax color when output is TTY)
      grep -r                     → rg (respects .gitignore, faster)
      ${D}\\\\ls / \\\\cat skip the alias and hit GNU coreutils for scripts.${R}

    ${B}Skipped from this list${R} — you already know these
      gh, chezmoi, git-lfs, gcc, make, cmake, kubectl, kind, helm,
      starship, fzf — install fine, work as you'd expect.

    ${B}Shells${R} — bash is always present
      ujust chsh        switch (default: zsh — bash-compat + highlight + autosuggest)
      ujust chsh fish   alternative — non-POSIX syntax, cleanest interactive UX
      ujust chsh bash   stay on bash
      ${D}All three share the same starship/atuin/zoxide/mise/fzf wiring,${R}
      ${D}same Ctrl+P, same eza/bat aliases, same agent-shell guard.${R}

    ${B}Other ujust recipes${R}
      ujust                       list every recipe (sideral + ublue stock)
      ujust chezmoi-init          bootstrap dotfiles from a chezmoi git repo
      ujust gdrive-setup          set up Google Drive auto-mount at ~/gdrive
                                  (one-time; mounts on every login after)
      ujust gdrive-remove         disable auto-mount; optionally wipe config
      ujust update                rpm-ostree upgrade + flatpak update

    EOF
    echo "    Source: $(Urllink "https://github.com/athenabriana/sideral" "github.com/athenabriana/sideral")"
    echo

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
# One-command Google Drive setup. Idempotent — safe to run multiple
# times. Combines what used to be three separate recipes (init / mount
# / unmount) into a single auto-mount-on-login flow:
#
#   1. If rclone has no `gdrive:` remote, walk the OAuth flow
#      (browser → Google consent → tokens written to ~/.config/rclone/).
#   2. Enable the rclone-gdrive.service systemd USER unit shipped at
#      /usr/lib/systemd/user/rclone-gdrive.service. From then on the
#      mount auto-starts on every login (WantedBy=default.target),
#      survives reboots, and self-restarts on transient network drops.
#   3. Start it now so you don't have to log out + back in.
#
# Net result after one `ujust gdrive-setup`: `~/gdrive` is mounted,
# stays mounted across reboots, no further commands needed.
#
# To turn it off:  systemctl --user disable --now rclone-gdrive.service
# To inspect:      systemctl --user status rclone-gdrive.service
# To see logs:     journalctl --user -u rclone-gdrive.service
# Disable the auto-mount and unmount ~/gdrive. Leaves the rclone remote
# config in place by default so re-running `ujust gdrive-setup` later
# is a one-step re-enable (no OAuth re-walk). Confirms at the end
# whether to also wipe the rclone config + ~/gdrive directory for a
# fully clean removal.
[group('Setup')]
gdrive-remove:
    #!/usr/bin/bash
    set -euo pipefail
    target="$HOME/gdrive"

    # Stop + disable the systemd user unit. --now makes one command
    # both stop the running service and disable it for next login.
    if systemctl --user is-enabled rclone-gdrive.service >/dev/null 2>&1 \
       || systemctl --user is-active rclone-gdrive.service >/dev/null 2>&1; then
        echo "Disabling rclone-gdrive.service..."
        systemctl --user disable --now rclone-gdrive.service || true
    else
        echo "rclone-gdrive.service already disabled."
    fi

    # ExecStop in the unit handles the unmount, but be defensive in case
    # the service was killed without running its stop hook.
    if mountpoint -q "$target" 2>/dev/null; then
        echo "Force-unmounting $target..."
        fusermount3 -u "$target" 2>/dev/null || fusermount -u "$target" 2>/dev/null || true
    fi

    echo
    echo "Auto-mount disabled. Google Drive will not mount on next login."
    echo "rclone gdrive: remote config is still in place — re-run"
    echo "\`ujust gdrive-setup\` to turn it back on without OAuth."
    echo

    # Optional deeper cleanup. Skipped silently if the user just wants
    # the auto-mount off.
    if ugum confirm "Also remove the rclone gdrive: remote config?"; then
        if command -v rclone >/dev/null 2>&1 \
           && rclone listremotes 2>/dev/null | grep -q '^gdrive:$'; then
            rclone config delete gdrive
            echo "Removed rclone gdrive: remote."
        fi
        # Only remove the dir if it's empty — never wipe user data.
        if [ -d "$target" ] && [ -z "$(ls -A "$target" 2>/dev/null)" ]; then
            rmdir "$target"
            echo "Removed empty $target directory."
        elif [ -d "$target" ]; then
            echo "Leaving $target in place — directory not empty."
        fi
    fi

[group('Setup')]
gdrive-setup:
    #!/usr/bin/bash
    set -euo pipefail
    if ! command -v rclone >/dev/null 2>&1; then
        echo "rclone not found — should ship via sideral-cli-tools" >&2
        exit 1
    fi

    # Step 1: rclone remote. Skip OAuth if `gdrive:` already configured.
    if rclone listremotes 2>/dev/null | grep -q '^gdrive:$'; then
        echo "rclone gdrive: remote already configured — skipping OAuth."
    else
        echo "Setting up Google Drive remote in rclone."
        echo "Your browser will open for the Google OAuth consent screen."
        echo "Say YES when prompted to use auto-config."
        echo
        rclone config create gdrive drive
    fi

    # Step 2 + 3: enable + start the systemd user unit.
    # --now combines `enable` (link into default.target.wants) + `start`
    # so a single command both arms auto-mount-on-login and mounts now.
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

[group('Setup')]
chezmoi-init repo="":
    #!/usr/bin/bash
    set -euo pipefail
    target="{{repo}}"
    if [ -z "$target" ]; then
        # No URL passed — confirm the user actually wants this prompt
        # since it's irreversible on a fresh $HOME (chezmoi apply
        # overwrites tracked files).
        echo "ujust chezmoi-init bootstraps your dotfiles from a chezmoi git repo."
        echo "Example: https://github.com/yourname/dotfiles"
        echo
        ugum confirm "Proceed?" || exit 0
        echo -n "Repo URL: "
        read -r target
    fi
    if [ -z "$target" ]; then
        echo "No repo URL — aborting." >&2
        exit 1
    fi
    if [ ! -x /usr/bin/chezmoi ]; then
        echo "chezmoi not found — should ship via sideral-cli-tools" >&2
        exit 1
    fi
    chezmoi init --apply "$target"
