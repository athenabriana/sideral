# 20-nix.sh — Nix env (POSIX).
#
# NH_HOME_FLAKE points `nh home …` at the user's home-manager flake.

if command -v nh >/dev/null 2>&1; then
    export NH_HOME_FLAKE="$HOME/Dotfiles/home-manager"
fi
