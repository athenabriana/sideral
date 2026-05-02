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

# Source order matters here: any tool that overrides `cd` (mise's chpwd
# hook does, via __zsh_like_cd) must initialize BEFORE zoxide, because
# zoxide's `--cmd cd` replaces `cd` with a fuzzy-matching wrapper and we
# want that wrapper to be the last writer. If mise loads after zoxide
# its __zsh_like_cd overrides zoxide's cd, leaving `cd partial` as a
# plain `builtin cd` that fails on anything that isn't an exact subdir.
# Verified: previously `cd sideral` from outside the dir produced "No
# such file or directory" instead of a zoxide jump.

# starship prompt
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
fi

# atuin shell history (Ctrl-R), no up-arrow rebind
if command -v atuin >/dev/null 2>&1; then
    eval "$(atuin init bash --disable-up-arrow)"
fi

# mise — runtime version manager activation. Must come BEFORE zoxide
# because mise's chpwd-style cd override would otherwise clobber zoxide's.
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate bash)"
fi

# zoxide — fuzzy `cd <partial>` jumps. Loaded LAST among cd-touching
# tools so its override is the live one.
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash --cmd cd)"
fi

# fzf — Ctrl-R / Ctrl-T / Alt-C key bindings (fzf 0.48+ pattern)
if command -v fzf >/dev/null 2>&1; then
    # shellcheck disable=SC1090
    source <(fzf --bash)
fi
