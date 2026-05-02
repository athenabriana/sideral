# sideral — central CLI shell-init wiring (fish edition).
#
# Parallel of /etc/profile.d/sideral-cli-init.sh for users who switch
# their login shell to fish (`chsh -s /usr/bin/fish`). Same tools,
# same agent guard, same Ctrl+P quick-open, same eza/bat aliases —
# just expressed in fish syntax.
#
# Loaded automatically by fish from /etc/fish/conf.d/ at every
# interactive session start (no re-entry guard needed; fish runs
# conf.d once per session).
#
# What you get over the bash init by virtue of being fish:
#   • Syntax highlighting as you type (built in)
#   • Autosuggestions from history (greyed-out, accept with →)
#   • Smarter tab completion (parses --help output, vendor completions
#     from /usr/share/fish/vendor_completions.d/ ship via tool RPMs)

# ── Default editor split — same as bash ─────────────────────────────────
#   EDITOR (terminal)  → helix
#   VISUAL (graphical) → VS Code
if command -v hx >/dev/null 2>&1
    set -gx EDITOR hx
end
if command -v code >/dev/null 2>&1
    set -gx VISUAL code
end

# ── Tool inits ──────────────────────────────────────────────────────────
# Each `tool init fish` (or equivalent) emits fish-syntax setup; pipe
# through `source` to load it into the current shell. `command -v` guards
# match the bash init — removing any one tool via `rpm-ostree override
# remove` doesn't break the rest.

if command -v starship >/dev/null 2>&1
    starship init fish | source
end

if command -v atuin >/dev/null 2>&1
    atuin init fish --disable-up-arrow | source
end

if command -v zoxide >/dev/null 2>&1
    zoxide init fish | source
end

if command -v mise >/dev/null 2>&1
    mise activate fish | source
end

if command -v fzf >/dev/null 2>&1
    fzf --fish | source
end

# ── Agent shell detection ───────────────────────────────────────────────
# Same canonical list as the bash init (verified against agentsmd/
# agents.md#136 + vercel/vercel/packages/detect-agent). `set -q VAR`
# returns true iff VAR is set, even to empty — fine here because
# agent runtimes set their markers to non-empty values.
set -l _sideral_agent_shell
if set -q AGENT;            or set -q AI_AGENT;        or \
   set -q CLAUDECODE;       or \
   set -q CURSOR_AGENT;     or set -q CURSOR_TRACE_ID; or \
   set -q GEMINI_CLI;       or \
   set -q CODEX_SANDBOX;    or \
   set -q AUGMENT_AGENT;    or \
   set -q CLINE_ACTIVE;     or \
   set -q OPENCODE_CLIENT;  or \
   set -q TRAE_AI_SHELL_ID; or \
   set -q ANTIGRAVITY_AGENT; or \
   set -q REPL_ID;          or \
   set -q COPILOT_MODEL;    or \
   set -q SIDERAL_NO_ALIASES
    set _sideral_agent_shell 1
end

# ── eza / bat aliases — only for human-driven shells ────────────────────
# Plain `\ls` / `\cat` (or `command ls` / `command cat`) hit the GNU
# coreutils version regardless. In fish, function-shadowing is the
# more idiomatic approach over alias, but `alias` works fine and
# stays close to the bash init for diff-readability.
if test -z "$_sideral_agent_shell"
    if command -v eza >/dev/null 2>&1
        alias ls 'eza --icons --group-directories-first'
        alias ll 'eza --icons --group-directories-first --long --git --header'
        alias la 'eza --icons --group-directories-first --long --git --header --all'
        alias lt 'eza --icons --tree --level=2'
        alias tree 'eza --icons --tree'
    end
    if command -v bat >/dev/null 2>&1
        alias cat 'bat --paging=never --style=plain'
    end
end

# ── Ctrl-P — VS-Code-style quick-open ──────────────────────────────────
# Pick a file with fzf, open in $VISUAL/$EDITOR. fish's `bind` is
# first-class so this is dramatically simpler than the bash version
# (no `bind -x`, no readline-quoting, no `[[ $- == *i* ]]` interactive
# guard — fish only sources conf.d in interactive sessions anyway).
if command -v fzf >/dev/null 2>&1
    function _sideral_fzf_quick_open
        set -l file
        if command -v rg >/dev/null 2>&1
            set file (rg --files --hidden --follow --glob '!.git' 2>/dev/null \
                      | fzf --height 40% --reverse --prompt 'Open: ')
        else
            set file (find . -type f -not -path '*/.git/*' 2>/dev/null \
                      | fzf --height 40% --reverse --prompt 'Open: ')
        end
        test -z "$file"; and return

        set -l editor
        if test -n "$VISUAL"
            set editor $VISUAL
        else if test -n "$EDITOR"
            set editor $EDITOR
        else if command -v code >/dev/null 2>&1
            set editor code
        else
            set editor vi
        end
        $editor $file
        commandline -f repaint
    end
    bind \cp _sideral_fzf_quick_open
end
