# sideral-shell-migrate.sh — fix broken login shell on login.
# If the user's login shell binary no longer exists (e.g. /usr/bin/fish
# was removed when fish was replaced by nushell), switch to zsh silently.
# Uses sudo -n (non-interactive) so a missing sudoers entry fails fast
# rather than blocking login with a password prompt.
_current_shell="$(getent passwd "$USER" | cut -d: -f7)"
if [ -n "$_current_shell" ] && [ ! -x "$_current_shell" ]; then
    if command -v sudo >/dev/null 2>&1; then
        sudo -n usermod -s /usr/bin/zsh "$USER" 2>/dev/null || true
    fi
fi
unset _current_shell
