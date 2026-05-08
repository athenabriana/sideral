# sideral-nushell-plugins.sh — register system nushell plugins on login.
# Probes /etc/nushell/plugins/ (NixOS-style, set by os/modules/cli-tools/default.nix)
# first, then /usr/lib/nushell/plugins/ (Fedora-flavor compatibility) — registers
# any plugin not already in the user's plugin registry (~/.config/nushell/plugin.msgpackz).
# No-op on subsequent logins once a plugin is registered.
command -v nu >/dev/null 2>&1 || return 0
_plugin_dir=""
for _candidate in /etc/nushell/plugins /usr/lib/nushell/plugins; do
    if [ -d "$_candidate" ]; then
        _plugin_dir="$_candidate"
        break
    fi
done
[ -n "$_plugin_dir" ] || return 0
for _plugin_bin in "$_plugin_dir"/nu_plugin_*; do
    [ -x "$_plugin_bin" ] || continue
    _plugin_name="$(basename "$_plugin_bin")"
    if ! nu --commands "plugin list | where name == '${_plugin_name}' | is-not-empty | into string" \
            2>/dev/null | grep -q true; then
        nu --commands "plugin add $_plugin_bin" 2>/dev/null || true
    fi
done
unset _plugin_bin _plugin_name _plugin_dir _candidate
