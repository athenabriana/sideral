# ~/.config/nushell/env.nu — nushell environment (env-phase).
#
# Managed by chezmoi (source: dot_config/nushell/env.nu). Edit freely
# after first apply; chezmoi only re-applies when you run `chezmoi
# apply`. Run `ujust apply-defaults` to restore the sideral default.
#
# ~/.local/share/nushell/vendor/autoload/sideral-cli-init.nu wires the
# editor split, agent guard, and `view` command. Per-tool prompt/history/
# jump inits (starship, atuin, zoxide, mise) are pre-generated into
# sibling files there by chezmoi's run_onchange_after_install-nu-prompts.sh.
# Add your own $env assignments below.

# mise shims — tools available before the activate hook fires and in
# non-interactive contexts. `mise activate nu` (loaded from vendor
# autoload) takes over for interactive per-directory switching after
# the first prompt.
let _mise_shims = ($env.HOME | path join ".local/share/mise/shims")
if ($_mise_shims | path exists) {
    $env.PATH = ($env.PATH | prepend $_mise_shims)
}

# ~/.local/bin — XDG per-user bin dir for cargo/pipx/manual installs.
# Membership check before prepend so re-sourcing or nested nu sessions
# don't grow PATH.
let _local_bin = ($env.HOME | path join ".local/bin")
if not ($env.PATH | any {|p| $p == $_local_bin }) {
    $env.PATH = ($env.PATH | prepend $_local_bin)
}
