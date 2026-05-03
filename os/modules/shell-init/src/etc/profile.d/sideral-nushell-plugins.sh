# sideral-nushell-plugins.sh — register system nushell plugins on login.
# Registers any plugin in /usr/lib/nushell/plugins/ that is not yet in the
# user's plugin registry (~/.config/nushell/plugin.msgpackz). No-op on
# subsequent logins once a plugin is registered. Safe to run multiple times.
command -v nu >/dev/null 2>&1 || return 0
[ -d /usr/lib/nushell/plugins ] || return 0
for _plugin_bin in /usr/lib/nushell/plugins/nu_plugin_*; do
    [ -x "$_plugin_bin" ] || continue
    _plugin_name="$(basename "$_plugin_bin")"
    if ! nu --commands "plugin list | where name == '${_plugin_name}' | is-not-empty | into string" \
            2>/dev/null | grep -q true; then
        nu --commands "plugin add $_plugin_bin" 2>/dev/null || true
    fi
done
unset _plugin_bin _plugin_name
