# Activate mise in every fish shell (login, interactive, or subshell).
if command -v mise >/dev/null
    mise activate fish | source
end
