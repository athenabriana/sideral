# sideral — first-shell onboarding hint.
#
# Prints a single chezmoi tip on the first interactive shell per user,
# then writes a marker so subsequent shells stay silent. Failures
# writing under $HOME (e.g., read-only home) are swallowed.
#
# (chezmoi-home CHM-21 / CHM-22)

# Interactive-only: skip ssh exec, cron, scripts.
case "$-" in
    *i*) ;;
    *) return 0 ;;
esac
[ -t 1 ] || return 0

_sideral_onboarding_marker="${HOME}/.cache/sideral/onboarding-shown"

if [ ! -f "$_sideral_onboarding_marker" ]; then
    printf '\n  \033[1;34msideral\033[0m · Tip: run `chezmoi init --apply <your-repo>` if you have a dotfiles repo to apply.\n\n'
    mkdir -p "${HOME}/.cache/sideral" 2>/dev/null || :
    touch "$_sideral_onboarding_marker" 2>/dev/null || :
fi

unset _sideral_onboarding_marker
