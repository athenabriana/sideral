# sideral — first-shell bootstrap UX
#
# Sourced by /etc/bashrc and /etc/profile for every interactive shell. In the
# ~1-minute window between first login and sideral-home-manager-setup.service
# completing, the user's shell would otherwise look bare (no starship, mise,
# atuin, gh, zoxide, fzf, eza). This snippet polls the service's marker file
# and sources home-manager's generated env when it appears, so the CURRENT
# shell gets the full environment without a reopen.
#
# 5-minute timeout. Exits silently for non-interactive shells (ssh exec,
# cron) and once the marker exists (i.e., every shell after the first).

# Re-entry guard — .bashrc may be sourced again below; don't recurse.
[ -n "${SIDERAL_HM_STATUS_RAN:-}" ] && return 0
SIDERAL_HM_STATUS_RAN=1

# Interactive-TTY only. Non-interactive shells (ssh cmd, scripts, cron) bail.
case "$-" in
    *i*) ;;
    *) return 0 ;;
esac
[ -t 1 ] || return 0

_sideral_hm_marker="${HOME}/.cache/sideral/home-manager-setup-done"

# Fast path: setup already done.
[ -f "$_sideral_hm_marker" ] && return 0

# If nix itself isn't installed yet (sideral-nix-install.service still running
# or failed), there's nothing to wait for from THIS shell. Bail quietly.
[ -e /nix/var/nix/profiles/default/bin/nix ] || return 0

_sideral_hm_timeout=300   # 5 min
_sideral_hm_interval=2
_sideral_hm_elapsed=0

printf '\n\033[1m────────────────────────────────────────────────────────────\033[0m\n'
printf '  \033[1;34msideral\033[0m · preparing your user environment\n\n'
printf '  home-manager is materializing home.nix: installing packages,\n'
printf '  wiring shell integration, writing ~/.bashrc. Your prompt, mise,\n'
printf '  git, atuin, and GUI software center will appear here automatically.\n\n'
printf '\033[1m────────────────────────────────────────────────────────────\033[0m\n\n'

_sideral_hm_frames='|/-\'
_sideral_hm_fi=0
while [ "$_sideral_hm_elapsed" -lt "$_sideral_hm_timeout" ]; do
    if [ -f "$_sideral_hm_marker" ]; then
        printf '\r\033[K  \033[1;32m[OK]\033[0m home-manager setup complete — sourcing new env\n\n'
        # Pull home-manager's env vars into THIS shell.
        # shellcheck disable=SC1091
        [ -f "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ] \
            && . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
        # Re-source the now-generated .bashrc so starship/mise/atuin activate.
        # shellcheck disable=SC1091
        [ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
        unset _sideral_hm_marker _sideral_hm_timeout _sideral_hm_interval \
              _sideral_hm_elapsed _sideral_hm_frames _sideral_hm_fi
        return 0
    fi
    _sideral_hm_frame=$(printf %s "$_sideral_hm_frames" | cut -c$((_sideral_hm_fi + 1)))
    printf '\r  \033[1;36m%s\033[0m waiting for home-manager-setup-done (%ds)…' \
        "$_sideral_hm_frame" "$_sideral_hm_elapsed"
    sleep "$_sideral_hm_interval"
    _sideral_hm_elapsed=$((_sideral_hm_elapsed + _sideral_hm_interval))
    _sideral_hm_fi=$(( (_sideral_hm_fi + 1) % 4 ))
done

# Timeout path — drop user into a Fedora-default shell with a diagnostic.
printf '\r\033[K'
printf '  \033[1;33m[!]\033[0m home-manager is taking longer than expected (>5 min)\n\n'
printf '  Continuing with Fedora defaults. Tail the setup service to see why:\n'
printf '    journalctl --user -u sideral-home-manager-setup -f\n\n'
printf '  Once it completes, reopen this terminal or run:\n'
printf '    . ~/.nix-profile/etc/profile.d/hm-session-vars.sh\n\n'
printf '\033[1m────────────────────────────────────────────────────────────\033[0m\n\n'

unset _sideral_hm_marker _sideral_hm_timeout _sideral_hm_interval \
      _sideral_hm_elapsed _sideral_hm_frames _sideral_hm_fi _sideral_hm_frame
return 0
