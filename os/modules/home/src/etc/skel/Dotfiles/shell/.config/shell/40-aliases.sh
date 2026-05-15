# 40-aliases.sh — eza / bat aliases (POSIX).
#
# Skipped for AI agent shells (see 30-agent-detect.sh). Agents read
# command output as raw strings to feed back into context, so icons /
# ANSI escapes / git decoration / line numbers from eza/bat would
# pollute the parse path. Plain `\ls` / `\cat` (backslash-escaped)
# still hit the GNU coreutils binary regardless.

if [ -z "${SILVERFOX_AGENT_SHELL:-}" ]; then
    if command -v eza >/dev/null 2>&1; then
        alias ls='eza --icons --group-directories-first'
        alias ll='eza --icons --group-directories-first --long --git --header'
        alias la='eza --icons --group-directories-first --long --git --header --all'
        alias tree='eza --icons --tree --level=5 --git-ignore'
    fi
    if command -v bat >/dev/null 2>&1; then
        alias cat='bat --paging=never --style=plain'
        # bare `bat` keeps the full pager + theme + line numbers
    fi
fi
