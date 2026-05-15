# 10-editor.sh — EDITOR/VISUAL (POSIX).
#
# Zed is the GUI editor for both EDITOR and VISUAL. `--wait` blocks the
# spawning process until the buffer closes, which is what git commit,
# sudoedit, mise edit, crontab -e, less's `v` key, etc. all need.

if command -v zed >/dev/null 2>&1; then
    export EDITOR='zed --wait'
    export VISUAL='zed --wait'
fi
