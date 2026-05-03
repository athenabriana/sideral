# sideral — central CLI shell-init wiring (nushell vendor autoload).
#
# Loaded automatically from /usr/share/nushell/vendor/autoload/ at every
# interactive nushell session. Runs in env-phase — only env-safe constructs
# here. Config-phase items (mise activate, keybindings, carapace external
# completer) live in the seeded ~/.config/nushell/config.nu (see D-01, D-03).

# ── Default editor split ────────────────────────────────────────────────
if (which hx | is-not-empty) {
    $env.EDITOR = "hx"
}
if (which code | is-not-empty) {
    $env.VISUAL = "code"
}

# ── Tool inits ──────────────────────────────────────────────────────────
# starship, atuin, zoxide each emit nushell init via `init nu`. The output
# is saved to a temp file and sourced — nushell requires a file path for
# `source`, not a string from a subexpression.

if (which starship | is-not-empty) {
    starship init nu | save --force /tmp/sideral-starship-init.nu
    source /tmp/sideral-starship-init.nu
}

if (which atuin | is-not-empty) {
    atuin init nu --disable-up-arrow | save --force /tmp/sideral-atuin-init.nu
    source /tmp/sideral-atuin-init.nu
}

if (which zoxide | is-not-empty) {
    zoxide init nushell | save --force /tmp/sideral-zoxide-init.nu
    source /tmp/sideral-zoxide-init.nu
}

# ── Agent shell detection ───────────────────────────────────────────────
# Same canonical 14-marker list as bash/zsh. $env | get --ignore-errors
# returns null (not an error) for absent vars — safe for the check below.
let _sideral_agent = (
    ($env | get --ignore-errors AGENT           | is-not-empty) or
    ($env | get --ignore-errors AI_AGENT        | is-not-empty) or
    ($env | get --ignore-errors CLAUDECODE      | is-not-empty) or
    ($env | get --ignore-errors CURSOR_AGENT    | is-not-empty) or
    ($env | get --ignore-errors CURSOR_TRACE_ID | is-not-empty) or
    ($env | get --ignore-errors GEMINI_CLI      | is-not-empty) or
    ($env | get --ignore-errors CODEX_SANDBOX   | is-not-empty) or
    ($env | get --ignore-errors AUGMENT_AGENT   | is-not-empty) or
    ($env | get --ignore-errors CLINE_ACTIVE    | is-not-empty) or
    ($env | get --ignore-errors OPENCODE_CLIENT | is-not-empty) or
    ($env | get --ignore-errors TRAE_AI_SHELL_ID | is-not-empty) or
    ($env | get --ignore-errors ANTIGRAVITY_AGENT | is-not-empty) or
    ($env | get --ignore-errors REPL_ID         | is-not-empty) or
    ($env | get --ignore-errors COPILOT_MODEL   | is-not-empty) or
    ($env | get --ignore-errors SIDERAL_NO_ALIASES | is-not-empty)
)

# ── view command — syntax-highlighted file viewer ───────────────────────
# Uses nu_plugin_highlight when registered; falls back to plain open --raw.
# Available in both human and agent shells (it's a command, not an alias).
# No ls/cat aliases in nushell — built-in ls returns structured data (D-07).
def view [file: path] {
    if (plugin list | where name == "nu_plugin_highlight" | is-not-empty) {
        open --raw $file | highlight
    } else {
        open --raw $file
    }
}
