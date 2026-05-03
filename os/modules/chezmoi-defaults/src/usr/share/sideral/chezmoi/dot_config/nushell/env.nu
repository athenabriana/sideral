# ~/.config/nushell/env.nu — nushell environment (env-phase).
# /usr/share/nushell/vendor/autoload/sideral-cli-init.nu is loaded by
# the system and wires starship, atuin, zoxide, and the view command.
# Add your own $env assignments below.

# mise shims — tools available before the activate hook fires and in
# non-interactive contexts. `mise activate nu` (in config.nu) takes over
# for interactive per-directory switching after the first prompt.
let _mise_shims = ($env.HOME | path join ".local/share/mise/shims")
if ($mise_shims | path exists) {
    $env.PATH = ($env.PATH | prepend $_mise_shims)
}
