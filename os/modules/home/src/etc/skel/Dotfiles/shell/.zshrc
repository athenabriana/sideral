# ~/.zshrc — silverfox zsh interactive-shell wiring.
#
# Stow package from Dotfiles/zsh/.zshrc — to customize, replace the
# symlink with a real file and edit. The skel merge (profile.d) copies
# new defaults from /etc/skel on every login.

# ── ~/.local/bin on PATH ────────────────────────────────────────────────
# XDG per-user bin dir for cargo/pipx/manual installs. Idempotent via
# case-glob so re-sourcing or nested shells don't grow PATH.
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# ── Default editor ──────────────────────────────────────────────────────
# Zed is the GUI editor for both EDITOR and VISUAL. `--wait` (a.k.a. `-w`)
# blocks the spawning process until the buffer closes, which is what git
# commit, sudoedit, mise edit, crontab -e, less's `v` key, etc. all need.
if (( ${+commands[zed]} )); then
    export EDITOR='zed --wait'
    export VISUAL='zed --wait'
fi

# ── Nix flake path (nh) ────────────────────────────────────────────
# nh uses NH_FLAKE to find the home-manager-compatible flake.
# Resolve the real path: stow creates file-level symlinks inside
# ~/.config/nix/ and Nix won't follow them when evaluating the flake.
if (( ${+commands[nh]} )); then
    _sf_nf="${HOME}/.config/nix/flake.nix"
    [[ -L "$_sf_nf" ]] && _sf_nf="$(readlink -f "$_sf_nf")"
    export NH_FLAKE="${_sf_nf%/flake.nix}"
    unset _sf_nf
fi

# ── compinit — load completion system before tool inits ────────────────
# atuin, zoxide, mise, fzf, and carapace each emit `compdef …` lines
# from their `init zsh` output. Those run at source-time and need
# `compdef` already defined, which only happens after `compinit` runs.
# Without this, every fresh zsh prints `command not found: compdef`.
#
# `-u` skips the security check on group-writable completion dirs
# (rpm-ostree's /usr is read-only and group-owned, which compinit
# otherwise flags interactively). `-d` pins the dump file under
# $XDG_CACHE_HOME so we don't litter $HOME with .zcompdump.
autoload -Uz compinit
compinit -u -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"

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
    export PATH="$HOME/.local/share/mise/shims:$PATH"
    if [[ -o interactive ]]; then
        eval "$(mise activate zsh)"
    fi
fi
if (( ${+commands[fzf]} )); then
    source <(fzf --zsh)
fi

# carapace — 839+ CLI completions; needs compinit (above).
# Must load before zsh-syntax-highlighting (last rule).
if (( ${+commands[carapace]} )); then
    source <(carapace _carapace zsh)
fi

# ── Fish-parity plugins ─────────────────────────────────────────────────
# zsh-autosuggestions: greyed-out completion from history; → / End to
# accept. zsh-syntax-highlighting: invalid commands red, paths blue, etc.
# Order per upstream README: autosuggestions first, syntax-highlighting
# last (it wraps every existing ZLE widget at source time).
if [[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# ── Agent shell detection ───────────────────────────────────────────────
# Same canonical 14-marker list as bash. ${(P)v} is zsh's indirect
# parameter expansion (equivalent of bash's ${!v}).
local _silverfox_agent_shell=
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
          SILVERFOX_NO_ALIASES; do
    if [[ -n "${(P)_v}" ]]; then
        _silverfox_agent_shell=1
        break
    fi
done
unset _v

# ── eza / bat aliases — only for human-driven shells ────────────────────
if [[ -z "$_silverfox_agent_shell" ]]; then
    if (( ${+commands[eza]} )); then
        alias ls='eza --icons --group-directories-first'
        alias ll='eza --icons --group-directories-first --long --git --header'
        alias la='eza --icons --group-directories-first --long --git --header --all'
        alias tree='eza --icons --tree --level=5 --git-ignore'
    fi
    if (( ${+commands[bat]} )); then
        alias cat='bat --paging=never --style=plain'
    fi
fi
unset _silverfox_agent_shell

# ── Ctrl-P — VS-Code-style fzf quick-open ──────────────────────────────
# zsh's ZLE (line editor) is the equivalent of bash's readline.
# `zle -N` registers a widget; `bindkey '^P'` binds Ctrl-P.
if (( ${+commands[fzf]} )); then
    _silverfox_fzf_quick_open() {
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
            if (( ${+commands[zed]} )); then editor='zed --wait'; else editor=vi; fi
        fi
        eval "$editor \"\$file\""
        zle reset-prompt 2>/dev/null
    }
    zle -N _silverfox_fzf_quick_open
    bindkey '^P' _silverfox_fzf_quick_open
fi

# ── Alt-S — toggle `sudo ` prefix on current line ─────────────────────
# BUFFER / CURSOR are zsh's editable-line variables (equivalent of
# bash's READLINE_LINE / READLINE_POINT).
_silverfox_toggle_sudo() {
    if [[ "$BUFFER" == sudo\ * ]]; then
        BUFFER="${BUFFER#sudo }"
        (( CURSOR -= 5 ))
        (( CURSOR < 0 )) && CURSOR=0
    else
        BUFFER="sudo $BUFFER"
        (( CURSOR += 5 ))
    fi
}
zle -N _silverfox_toggle_sudo
bindkey '^[s' _silverfox_toggle_sudo  # ^[ = ESC = Alt prefix; s = lowercase

# ── Ctrl-G — fzf git branch picker → checkout ─────────────────────────
if (( ${+commands[fzf]} )); then
    _silverfox_fzf_git_checkout() {
        git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return
        local branch
        branch=$(git for-each-ref --format='%(refname:short)' refs/heads/ refs/remotes/ 2>/dev/null \
                 | sed 's|^origin/||' | awk '!seen[$0]++' \
                 | fzf --height 40% --reverse --prompt 'Checkout: ')
        [[ -z "$branch" ]] && return
        git checkout "$branch"
        zle reset-prompt 2>/dev/null
    }
    zle -N _silverfox_fzf_git_checkout
    bindkey '^G' _silverfox_fzf_git_checkout
fi

# ── Syntax highlighting (MUST load last) ────────────────────────────────
# zsh-syntax-highlighting wraps every existing ZLE widget at source time.
# Loading last means Ctrl+P / Alt-S / Ctrl-G widgets above also get
# colored. Upstream README requires this ordering.
if [[ -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
