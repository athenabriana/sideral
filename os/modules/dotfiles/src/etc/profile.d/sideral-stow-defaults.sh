# sideral-stow-defaults.sh — symlink image dotfile defaults on first login.
# Sourced by /etc/profile.d/ for every login shell. Fires exactly once per
# user account (marker file guards subsequent logins). stow guard means
# removing stow via rpm-ostree override remove is safe — no effect here.
[ -f "$HOME/.local/state/sideral/stow-defaults-applied" ] && return 0
command -v stow >/dev/null 2>&1 || return 0
[ -d /usr/share/sideral/stow ] || return 0
mkdir -p "$HOME/.local/state/sideral"
for _pkg in /usr/share/sideral/stow/*/; do
    _name="$(basename "$_pkg")"
    stow --target="$HOME" --dir=/usr/share/sideral/stow --restow --no-folding "$_name" 2>/dev/null || true
done
unset _pkg _name
touch "$HOME/.local/state/sideral/stow-defaults-applied"
