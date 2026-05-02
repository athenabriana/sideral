# sideral — central CLI shell-init wiring (zsh edition).
#
# Parallel of /etc/profile.d/sideral-cli-init.sh and
# /etc/fish/conf.d/sideral-cli-init.fish for users who switch their
# login shell to zsh (`ujust chsh zsh`). Same tools, same agent guard,
# same Ctrl+P quick-open, same eza/bat aliases — in zsh syntax.
#
# Sourced by /etc/zshrc (sideral ships /etc/zshrc with one line that
# sources this file plus stock Fedora umask boilerplate).

# ── Default editor split ────────────────────────────────────────────────
if (( ${+commands[hx]} )); then
    export EDITOR=hx
fi
if (( ${+commands[code]} )); then
    export VISUAL=code
fi

# ── Tool inits ──────────────────────────────────────────────────────────
if (( ${+commands[starship]} )); then
    eval "$(starship init zsh)"
fi
if (( ${+commands[atuin]} )); then
    eval "$(atuin init zsh --disable-up-arrow)"
fi
if (( ${+commands[zoxide]} )); then
    eval "$(zoxide init zsh)"
fi
if (( ${+commands[mise]} )); then
    eval "$(mise activate zsh)"
fi
if (( ${+commands[fzf]} )); then
    source <(fzf --zsh)
fi

# ── Agent shell detection ───────────────────────────────────────────────
# Same canonical 14-marker list as the bash and fish inits. ${(P)v} is
# zsh's indirect parameter expansion (equivalent to bash's ${!v}).
local _sideral_agent_shell=
local _v
for _v in AGENT AI_AGENT \
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
    if [[ -n "${(P)_v}" ]]; then
        _sideral_agent_shell=1
        break
    fi
done
unset _v

# ── eza / bat aliases — only for human-driven shells ────────────────────
if [[ -z "$_sideral_agent_shell" ]]; then
    if (( ${+commands[eza]} )); then
        alias ls='eza --icons --group-directories-first'
        alias ll='eza --icons --group-directories-first --long --git --header'
        alias la='eza --icons --group-directories-first --long --git --header --all'
        alias lt='eza --icons --tree --level=2'
        alias tree='eza --icons --tree'
    fi
    if (( ${+commands[bat]} )); then
        alias cat='bat --paging=never --style=plain'
    fi
fi
unset _sideral_agent_shell

# ── Ctrl-P — VS-Code-style quick-open ──────────────────────────────────
# zsh's ZLE (line editor) is the equivalent of bash's readline.
# `zle -N name` registers a widget; `bindkey '^P' name` binds Ctrl-P.
if (( ${+commands[fzf]} )); then
    _sideral_fzf_quick_open() {
        local file
        if (( ${+commands[rg]} )); then
            file=$(rg --files --hidden --follow --glob '!.git' 2>/dev/null \
                   | fzf --height 40% --reverse --prompt 'Open: ')
        else
            file=$(find . -type f -not -path '*/.git/*' 2>/dev/null \
                   | fzf --height 40% --reverse --prompt 'Open: ')
        fi
        [[ -z "$file" ]] && return
        local editor="${VISUAL:-${EDITOR:-}}"
        if [[ -z "$editor" ]]; then
            if (( ${+commands[code]} )); then editor=code; else editor=vi; fi
        fi
        $editor "$file"
        zle reset-prompt 2>/dev/null
    }
    zle -N _sideral_fzf_quick_open
    bindkey '^P' _sideral_fzf_quick_open
fi
