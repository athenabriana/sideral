# ~/.config/nushell/config.nu — nushell config (config-phase).
# Config-phase constructs that cannot live in vendor autoload (D-01, D-03).

# mise activate — directory-switching version hook (config-phase only).
# Writes a hook script and sources it; the save+source pattern is required
# because nushell cannot `source` from a subexpression string.
if (which mise | is-not-empty) {
    mise activate nu | save --force /tmp/sideral-mise-init.nu
    source /tmp/sideral-mise-init.nu
}

# carapace external completer — native tab completions for 839+ CLIs.
if (which carapace | is-not-empty) {
    $env.config = ($env.config | upsert completions.external {
        enable: true
        completer: {|spans|
            carapace $spans.0 nushell ...$spans | from json | default []
        }
    })
}

# Ctrl-P — fzf quick-open (VS Code style).
# Ctrl-R is handled by atuin. No Alt-S or Ctrl-G (D-03).
if (which fzf | is-not-empty) {
    $env.config = ($env.config | upsert keybindings (
        ($env.config.keybindings? | default []) ++ [{
            name: fzf_quick_open
            modifier: control
            keycode: char_p
            mode: [emacs vi_normal vi_insert]
            event: {
                send: ExecuteHostCommand
                cmd: "
                    let _file = if (which rg | is-not-empty) {
                        (rg --files --hidden --follow --glob \"!.git\" 2>/dev/null
                         | fzf --height 40% --reverse --prompt \"Open: \")
                    } else {
                        (find . -type f -not -path \"*/.git/*\" 2>/dev/null
                         | fzf --height 40% --reverse --prompt \"Open: \")
                    }
                    if ($_file | is-not-empty) {
                        let _ed = if ($env | get --ignore-errors VISUAL | is-not-empty) {
                            $env.VISUAL
                        } else if ($env | get --ignore-errors EDITOR | is-not-empty) {
                            $env.EDITOR
                        } else {
                            \"vi\"
                        }
                        ^$_ed $_file
                    }
                "
            }
        }]
    ))
}
