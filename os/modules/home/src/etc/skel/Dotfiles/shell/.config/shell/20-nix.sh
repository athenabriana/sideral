# 20-nix.sh — Nix env (POSIX).
#
# NH_FLAKE points `nh` (nix-helper) at the user's home flake.

if command -v nh >/dev/null 2>&1; then
    export NH_FLAKE="$HOME/Dotfiles/nix"
fi
