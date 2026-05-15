# ~/.bashrc — silverfox bash interactive-shell wiring.
#
# Stow package from Dotfiles/shell/.bashrc — to customize, replace the
# symlink with a real file and edit. The skel merge (profile.d) copies
# new defaults from /etc/skel on every login.
#
# POSIX-shared config lives in ~/.config/shell/*.sh and is sourced
# below; only bash-specific code (tool inits, readline keybinds) lives
# in this file.
# shellcheck source=/dev/null

# Re-entry guard: harmless to source twice, but skip the work.
[ -n "${SILVERFOX_BASHRC_RAN:-}" ] && return 0
SILVERFOX_BASHRC_RAN=1

# System-wide bashrc — locale, flatpak XDG_DATA_DIRS, completion stub, etc.
[ -f /etc/bashrc ] && source /etc/bashrc

# ── Shared POSIX modules (PATH, EDITOR, NH_FLAKE, aliases, mise shims) ─
_silverfox_modules="${XDG_CONFIG_HOME:-$HOME/.config}/shell"
if [ -d "$_silverfox_modules" ]; then
    for _f in "$_silverfox_modules"/*.sh; do
        [ -r "$_f" ] && . "$_f"
    done
    unset _f
fi
unset _silverfox_modules

# ── Tool inits (bash-specific eval/source) ──────────────────────────────
command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"
command -v atuin >/dev/null 2>&1 && eval "$(atuin init bash --disable-up-arrow)"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"
if command -v mise >/dev/null 2>&1 && [[ $- == *i* ]]; then
    eval "$(mise activate bash)"
fi
command -v fzf >/dev/null 2>&1 && source <(fzf --bash)
command -v carapace >/dev/null 2>&1 && source <(carapace _carapace bash)

# ── Ctrl-P — VS-Code-style fzf quick-open ──────────────────────────────
# Pick a file with fzf, open in $VISUAL/$EDITOR. Uses `rg --files` when
# available (.gitignore-aware + fast); falls back to find.
# Guarded by `[[ $- == *i* ]]` because `bind -x` requires readline —
# non-interactive shells (agent `bash -c …`) silently skip the bind.
if [[ $- == *i* ]] && command -v fzf >/dev/null 2>&1; then
    _silverfox_fzf_quick_open() {
        local file editor
        if command -v rg >/dev/null 2>&1; then
            file=$(rg --files --hidden --follow --glob '!.git' 2>/dev/null \
                   | fzf --height 40% --reverse --prompt 'Open: ') || return
        else
            file=$(find . -type f -not -path '*/.git/*' 2>/dev/null \
                   | fzf --height 40% --reverse --prompt 'Open: ') || return
        fi
        editor="${VISUAL:-${EDITOR:-}}"
        [ -z "$editor" ] && editor='vi'
        eval "$editor \"\$file\""
    }
    bind -x '"\C-p": _silverfox_fzf_quick_open'
fi

# ── Alt-S — toggle `sudo ` prefix on current line ─────────────────────
# Type the command, realize you need root, hit Alt-S. Hit it again to
# remove. READLINE_LINE / READLINE_POINT are bash-readline's editable-
# line variables (zsh equivalent: BUFFER / CURSOR).
if [[ $- == *i* ]]; then
    _silverfox_toggle_sudo() {
        if [[ "$READLINE_LINE" == sudo\ * ]]; then
            READLINE_LINE="${READLINE_LINE#sudo }"
            READLINE_POINT=$((READLINE_POINT - 5))
            (( READLINE_POINT < 0 )) && READLINE_POINT=0
        else
            READLINE_LINE="sudo $READLINE_LINE"
            READLINE_POINT=$((READLINE_POINT + 5))
        fi
    }
    bind -x '"\eS": _silverfox_toggle_sudo'
fi

# ── Ctrl-G — fzf git branch picker → checkout ─────────────────────────
# Pops fzf over local + remote branches (origin/foo de-duped to foo).
# Selection runs `git checkout`. No-ops cleanly outside a git repo.
if [[ $- == *i* ]] && command -v fzf >/dev/null 2>&1; then
    _silverfox_fzf_git_checkout() {
        git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return
        local branch
        branch=$(git for-each-ref --format='%(refname:short)' refs/heads/ refs/remotes/ 2>/dev/null \
                 | sed 's|^origin/||' | awk '!seen[$0]++' \
                 | fzf --height 40% --reverse --prompt 'Checkout: ') || return
        [ -z "$branch" ] && return
        git checkout "$branch"
    }
    bind -x '"\C-g": _silverfox_fzf_git_checkout'
fi
