# ~/.zshrc — silverfox zsh interactive-shell wiring.
#
# Stow package from Dotfiles/shell/.zshrc — to customize, replace the
# symlink with a real file and edit. The skel merge (profile.d) copies
# new defaults from /etc/skel on every login.
#
# POSIX-shared config lives in ~/.config/shell/*.sh and is sourced
# below; only zsh-specific code (compinit, tool inits, ZLE keybinds,
# zsh plugins) lives in this file.

# ── Shared POSIX modules (PATH, EDITOR, NH_FLAKE, aliases, mise shims) ─
_silverfox_modules="${XDG_CONFIG_HOME:-$HOME/.config}/shell"
if [ -d "$_silverfox_modules" ]; then
    for _f in "$_silverfox_modules"/*.sh; do
        [ -r "$_f" ] && . "$_f"
    done
    unset _f
fi
unset _silverfox_modules

# ── compinit — load completion system before tool inits ────────────────
# atuin, zoxide, mise, fzf, and carapace each emit `compdef …` lines
# from their `init zsh` output. Those run at source-time and need
# `compdef` already defined, which only happens after `compinit` runs.
#
# `-u` skips the security check on group-writable completion dirs
# (rpm-ostree's /usr is read-only and group-owned, which compinit
# otherwise flags interactively). `-d` pins the dump file under
# $XDG_CACHE_HOME so we don't litter $HOME with .zcompdump.
autoload -Uz compinit
compinit -u -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"

# ── Tool inits (zsh-specific eval/source) ──────────────────────────────
(( ${+commands[starship]} )) && eval "$(starship init zsh)"
(( ${+commands[atuin]} )) && eval "$(atuin init zsh --disable-up-arrow)"
(( ${+commands[zoxide]} )) && eval "$(zoxide init zsh)"
if (( ${+commands[mise]} )) && [[ -o interactive ]]; then
    eval "$(mise activate zsh)"
fi
(( ${+commands[fzf]} )) && source <(fzf --zsh)
# carapace — 839+ CLI completions; needs compinit (above).
# Must load before zsh-syntax-highlighting (last rule).
(( ${+commands[carapace]} )) && source <(carapace _carapace zsh)

# ── Fish-parity plugins ─────────────────────────────────────────────────
# zsh-autosuggestions: greyed-out completion from history; → / End to
# accept. zsh-syntax-highlighting: invalid commands red, paths blue, etc.
# Order per upstream README: autosuggestions first, syntax-highlighting
# last (it wraps every existing ZLE widget at source time).
if [[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# ── Ctrl-P — VS-Code-style fzf quick-open ──────────────────────────────
# zsh's ZLE (line editor) is the equivalent of bash's readline.
# `zle -N` registers a widget; `bindkey '^P'` binds Ctrl-P.
if (( ${+commands[fzf]} )); then
    _silverfox_fzf_quick_open() {
        local file editor
        if (( ${+commands[rg]} )); then
            file=$(rg --files --hidden --follow --glob '!.git' 2>/dev/null \
                   | fzf --height 40% --reverse --prompt 'Open: ')
        else
            file=$(find . -type f -not -path '*/.git/*' 2>/dev/null \
                   | fzf --height 40% --reverse --prompt 'Open: ')
        fi
        [[ -z "$file" ]] && return
        editor="${VISUAL:-${EDITOR:-vi}}"
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
