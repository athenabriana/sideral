# .bashrc — Athens OS default.
# Shipped via /etc/skel → copied into every new user's home.
# Also applied to existing users via `just apply-home`.
# Lives in HOME, so distrobox shells inherit it too.

# ── System defaults ──
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# ── Starship prompt ──
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
fi

# ── Mise (user-local install at ~/.local/bin/mise) ──
export PATH="$HOME/.local/bin:$PATH"
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate bash)"
fi

# ── Atuin (better shell history) — installed via mise ──
if command -v atuin >/dev/null 2>&1; then
    eval "$(atuin init bash)"
fi

# ── Direnv (per-project env vars) — installed via mise ──
if command -v direnv >/dev/null 2>&1; then
    eval "$(direnv hook bash)"
fi

# ── User additions below this line ──
