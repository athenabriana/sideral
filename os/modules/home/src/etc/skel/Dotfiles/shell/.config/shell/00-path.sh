# 00-path.sh — PATH manipulation (POSIX, sourced by bash/zsh).
#
# Adds ~/.local/bin (XDG per-user bin for cargo install --root, pipx,
# pip install --user, manually-dropped binaries) idempotently.

case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) PATH="$HOME/.local/bin:$PATH" ;;
esac
export PATH
