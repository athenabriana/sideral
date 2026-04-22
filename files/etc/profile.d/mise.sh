# Activate mise in every interactive bash shell.
# Per-user tool versions still come from ~/.config/mise/config.toml and .mise.toml files.

case "$-" in
    *i*)
        if [ -n "$BASH_VERSION" ] && command -v mise >/dev/null 2>&1; then
            eval "$(mise activate bash)"
        fi
        ;;
esac
