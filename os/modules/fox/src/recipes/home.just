# home.just — `fox home <verb>` module. Loaded as `mod home` from
# sideral.justfile. Only edge-cases here; everyday verbs (sync, diff,
# edit, doctor) are top-level in sideral.justfile.

# Hard-reset sideral-managed paths in $HOME from /etc/skel
factory-reset *args:
    /usr/libexec/sideral/home-factory-reset.sh {{args}}
