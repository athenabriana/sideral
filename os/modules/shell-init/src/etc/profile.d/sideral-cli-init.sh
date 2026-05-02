# sideral — central CLI shell-init wiring.
#
# Sourced by /etc/profile and /etc/bashrc for every login + interactive shell.
# Each `eval` is `command -v`-guarded so removing any single tool via
# `rpm-ostree override remove` doesn't break the rest.
#
# Replaces the home-manager `programs.X.enable` declarative wiring that
# nix-home would have shipped (chezmoi-home D-05).

# Re-entry guard: harmless to source twice, but skip the work.
[ -n "${SIDERAL_CLI_INIT_RAN:-}" ] && return 0
SIDERAL_CLI_INIT_RAN=1

# starship prompt
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
fi

# atuin shell history (Ctrl-R), no up-arrow rebind
if command -v atuin >/dev/null 2>&1; then
    eval "$(atuin init bash --disable-up-arrow)"
fi

# zoxide — fuzzy directory jumps via `z <partial>` and `zi` (interactive
# pick via fzf). Stock setup: `cd` keeps standard bash behavior. Earlier
# revisions used `--cmd cd` to alias cd → zoxide, but that clashed with
# mise's __zsh_like_cd chpwd wrapper (whichever loaded last won, and the
# loser silently broke). Plain `z` sidesteps the conflict entirely.
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi

# mise — runtime version manager activation
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate bash)"
fi

# fzf — Ctrl-R / Ctrl-T / Alt-C key bindings (fzf 0.48+ pattern)
if command -v fzf >/dev/null 2>&1; then
    # shellcheck disable=SC1090
    source <(fzf --bash)
fi
