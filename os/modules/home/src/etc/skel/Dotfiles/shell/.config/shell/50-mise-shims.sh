# 50-mise-shims.sh — mise shims on PATH (POSIX).
#
# Shims work in non-interactive shells (scripts, SSH exec) where the
# interactive `mise activate` hook isn't loaded. Each rc file then
# runs `mise activate` for interactive sessions on top of this.

if command -v mise >/dev/null 2>&1; then
    case ":$PATH:" in
        *":$HOME/.local/share/mise/shims:"*) ;;
        *) PATH="$HOME/.local/share/mise/shims:$PATH" ;;
    esac
    export PATH
fi
