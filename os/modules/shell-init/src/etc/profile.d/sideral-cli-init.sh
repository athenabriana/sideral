# sideral — central CLI shell-init wiring.
#
# Sourced by /etc/profile and /etc/bashrc for every login + interactive shell.
# Each `eval` is `command -v`-guarded so removing any single tool via
# `rpm-ostree override remove` doesn't break the rest.
#
# Replaces the home-manager `programs.X.enable` declarative wiring that
# nix-home would have shipped (chezmoi-home D-05).

# Re-entry guard: harmless to source twice, but skip the work.
[ -n "${SIDERAL_CLI_INIT_RAN:-}" ] && return 0
SIDERAL_CLI_INIT_RAN=1

# starship prompt
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
fi

# atuin shell history (Ctrl-R), no up-arrow rebind
if command -v atuin >/dev/null 2>&1; then
    eval "$(atuin init bash --disable-up-arrow)"
fi

# zoxide — fuzzy directory jumps via `z <partial>` and `zi` (interactive
# pick via fzf). Stock setup: `cd` keeps standard bash behavior. Earlier
# revisions used `--cmd cd` to alias cd → zoxide, but that clashed with
# mise's __zsh_like_cd chpwd wrapper (whichever loaded last won, and the
# loser silently broke). Plain `z` sidesteps the conflict entirely.
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi

# mise — runtime version manager activation
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate bash)"
fi

# fzf — Ctrl-R / Ctrl-T / Alt-C key bindings (fzf 0.48+ pattern)
if command -v fzf >/dev/null 2>&1; then
    # shellcheck disable=SC1090
    source <(fzf --bash)
fi

# Ctrl-P — VS-Code-style quick-open. Pick a file with fzf, open in
# editor. Uses `rg --files` when available (respects .gitignore + is
# fast on big repos); falls back to find. Editor pick order: $VISUAL,
# $EDITOR, then `code` (sideral ships VS Code), then vi.
#
# Guarded by `[[ $- == *i* ]]` (interactive shell) because `bind -x`
# requires readline. Non-interactive shells — including the way agent
# tools spawn `bash -c …` — silently skip the bind so the Ctrl-P
# slot they may already use stays untouched.
#
# Note: bash's default Ctrl-P is `previous-history`. Up-arrow does
# the same thing and is what most people use, so rebinding Ctrl-P
# rarely surprises anyone. To restore the default, drop this block
# or run `bind '"\C-p": previous-history'` in your shell.
if [[ $- == *i* ]] && command -v fzf >/dev/null 2>&1; then
    _sideral_fzf_quick_open() {
        local file editor
        if command -v rg >/dev/null 2>&1; then
            file=$(rg --files --hidden --follow --glob '!.git' 2>/dev/null \
                   | fzf --height 40% --reverse --prompt 'Open: ') || return
        else
            file=$(find . -type f -not -path '*/.git/*' 2>/dev/null \
                   | fzf --height 40% --reverse --prompt 'Open: ') || return
        fi
        editor="${VISUAL:-${EDITOR:-}}"
        if [ -z "$editor" ]; then
            if command -v code >/dev/null 2>&1; then editor=code; else editor=vi; fi
        fi
        $editor "$file"
    }
    bind -x '"\C-p": _sideral_fzf_quick_open'
fi

# eza / bat aliases — only for human-driven interactive shells.
#
# AI coding agents read command output as raw strings to feed back
# into context. Aliasing `ls` to eza or `cat` to bat injects icons /
# ANSI escapes / git decoration / line numbers that the agent has to
# parse around (and can mistake for real file content).
#
# Two cross-tool conventions are emerging (May 2026):
#   • AGENT     proposed by agentsmd/agents.md#136, implemented by
#               Goose, Amp, and consumed by Bun's isAIAgent() check
#   • AI_AGENT  used by Vercel's @vercel/detect-agent, falls through
#               to a list of tool-specific vars
# Neither is universally adopted, so we check both — plus the canonical
# tool-specific markers (verified against vercel/vercel/packages/
# detect-agent and agentsmd #136). SIDERAL_NO_ALIASES is the manual
# opt-out for anything we've missed (Aider, Continue, etc.).
#
# Trimmed to one marker per tool where the tool sets multiple — the
# additional flags (CODEX_CI, CODEX_THREAD_ID, GOOSE_TERMINAL,
# CLAUDE_CODE, COPILOT_ALLOW_ALL, COPILOT_GITHUB_TOKEN) are either
# subsumed by AGENT/AI_AGENT or unreliable as agent indicators
# (false positives from users with permanent Copilot tokens etc.).
#
#   AGENT, AI_AGENT       cross-tool (proposal + Vercel)
#   CLAUDECODE            Claude Code
#   CURSOR_AGENT          Cursor agent CLI
#   CURSOR_TRACE_ID       Cursor in-editor terminal
#   GEMINI_CLI            Google Gemini CLI
#   CODEX_SANDBOX         OpenAI Codex CLI (set to "seatbelt")
#   AUGMENT_AGENT         Augment
#   CLINE_ACTIVE          Cline
#   OPENCODE_CLIENT       sst/opencode
#   TRAE_AI_SHELL_ID      TRAE AI
#   ANTIGRAVITY_AGENT     Antigravity
#   REPL_ID               Replit
#   COPILOT_MODEL         GitHub Copilot CLI
#   SIDERAL_NO_ALIASES    manual opt-out
#
# Plain `\ls` / `\cat` (backslash-escaped) hit the GNU coreutils
# version regardless — useful in scripts that want deterministic POSIX
# output. Devin (/opt/.devin filesystem marker) intentionally not
# checked; bare-metal Devin runs aren't a sideral target.
_sideral_agent_shell=""
for _v in \
    AGENT AI_AGENT \
    CLAUDECODE \
    CURSOR_AGENT CURSOR_TRACE_ID \
    GEMINI_CLI \
    CODEX_SANDBOX \
    AUGMENT_AGENT \
    CLINE_ACTIVE \
    OPENCODE_CLIENT \
    TRAE_AI_SHELL_ID \
    ANTIGRAVITY_AGENT \
    REPL_ID \
    COPILOT_MODEL \
    SIDERAL_NO_ALIASES; do
    if [ -n "${!_v:-}" ]; then
        _sideral_agent_shell=1
        break
    fi
done
unset _v

if [ -z "$_sideral_agent_shell" ]; then
    if command -v eza >/dev/null 2>&1; then
        alias ls='eza --icons --group-directories-first'
        alias ll='eza --icons --group-directories-first --long --git --header'
        alias la='eza --icons --group-directories-first --long --git --header --all'
        alias lt='eza --icons --tree --level=2'
        alias tree='eza --icons --tree'
    fi
    if command -v bat >/dev/null 2>&1; then
        alias cat='bat --paging=never --style=plain'
        # bare `bat` keeps the full pager + theme + line numbers
    fi
fi
unset _sideral_agent_shell
