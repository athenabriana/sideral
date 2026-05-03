# sideral-chezmoi-defaults.sh — apply image dotfile defaults on first login.
# Sourced by /etc/profile.d/ for every login shell. Fires exactly once per
# user account (marker file guards subsequent logins). chezmoi guard means
# removing chezmoi via rpm-ostree override remove is safe — no effect here.
[ -f "$HOME/.local/share/sideral/chezmoi-defaults-applied" ] && return 0
command -v chezmoi >/dev/null 2>&1 || return 0
chezmoi apply --source /usr/share/sideral/chezmoi --force --quiet 2>/dev/null || true
mkdir -p "$HOME/.local/share/sideral"
touch "$HOME/.local/share/sideral/chezmoi-defaults-applied"
