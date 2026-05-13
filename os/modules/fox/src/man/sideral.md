% sideral(7) | Sideral OS
% Athena Freitas
% 2026-05-11

# NAME

sideral — operator CLI and environment overview for the sideral image

# SYNOPSIS

**fox** [*verb*] [*args*]

**man 7 sideral**

# DESCRIPTION

sideral is a personal Fedora atomic desktop derived from
`ublue-os/silverblue-main`. `fox(1)` is its operator CLI: a thin bash
dispatcher around `just -f /usr/share/sideral/sideral.justfile`.

# COMMANDS

`fox` (no arg) and `fox --help` print the recipe list via `just --list`.

`fox --version` prints the image's `VERSION_ID` from `/etc/os-release`.

`fox chsh [bash|zsh]`
:   Switch login shell. No argument opens a `tv` picker (falls back to a
    `read -p` prompt if `tv` is absent). Refuses anything outside the
    `bash`/`zsh` allowlist. Uses `sudo usermod -s` because uBlue's
    hardening pass removes setuid `chsh`.

`fox cheatsheet`
:   Open this manpage (`man 7 sideral`).

`fox home factory-reset [--yes|-y]`
:   Hard-reset sideral-managed paths under `$HOME` from `/etc/skel`:
    `~/.bashrc`, `~/.zshrc`, `~/.bash_profile`, `~/.bash_logout`, and the
    depth-1 children of `~/.config/sideral/`, `~/.config/mise/`,
    `~/.config/ghostty/`, `~/.config/zed/`. Non-sideral subdirectories of
    `~/.config/` (e.g. `firefox/`, `Code/`) are preserved.

`fox update [args]`
:   `flatpak update {args}`. Refreshes installed Flathub apps.

`fox upgrade [args]`
:   `rpm-ostree upgrade {args}` — stages the next sideral deployment.
    Prints a "Reboot to apply" trailer on success.

`fox rollback [args]`
:   `rpm-ostree rollback {args}` — swap to the previous deployment.

`fox status [args]`
:   `rpm-ostree status {args}`. Pass `--json` for structured output.

`fox cleanup [args]`
:   `rpm-ostree cleanup {args}` (defaults to `-prm` when no args given).

`fox changelog [args]`
:   `rpm-ostree db diff {args}` — RPM changes vs the pending or previous
    deployment.

# ENVIRONMENT

## Editor

`EDITOR` and `VISUAL` are both `zed --wait`. Zed runs with `vim_mode`
enabled and `default_mode: helix_normal` for selection-first modal
editing (replaces the older hx/code split). Git commit messages,
`sudoedit`, `mise edit`, `crontab -e`, and `less`'s `v` key all open a
Zed buffer and block until it closes.

## Navigation

- `z <dir>` / `zi` — zoxide jump / interactive
- `Ctrl-P` — fzf quick-open (edit a file from the current directory)
- `Ctrl-R` — atuin history search
- `Ctrl-T` — fzf file picker (insert path at cursor)
- `Alt-C` — fzf cd
- `Alt-S` — toggle `sudo` prefix on the current command
- `Ctrl-G` — fzf git-branch checkout

All shell-level bindings are gated by an AI-agent guard
(`SIDERAL_NO_ALIASES` or any of 14 agent env-var markers) so agents see
plain `ls`/`cat`/`grep` output.

## Containers

Rootless **podman** is the canonical container runtime. `docker` resolves
to the `podman-docker` shim wrapper, which points `DOCKER_HOST` at the
per-user podman socket (auto-enabled by `sideral-services`). Compose
workflows are covered by **podman-compose** with ~95% Compose-v2 parity.
**kind**, **helm**, and **kubectl** are available; `KIND_EXPERIMENTAL_PROVIDER=podman`
ships in `/etc/profile.d/sideral-kind-podman.sh`.

## Runtime versions

**mise** owns user-level toolchains. The default user mise config lives
at `~/.config/mise/config.toml` (seeded once from `/etc/skel` on
`useradd`) and pins 9 toolchains: node, bun, pnpm, python, uv, go, rust,
zig, act. `not_found_auto_install` is enabled — type `node` and mise
installs it on first use.

## Drop-in replacements

When the agent guard is inactive, the following aliases are wired:

- `ls` → `eza --icons` (`la`, `ll`, `lt` variants)
- `cat` → `bat --paging=never`
- `grep` → `rg`

`\ls` and `\cat` always reach GNU coreutils for scripts that want
deterministic output.

## Shells

bash (default) and zsh are the only shells sideral wires. Switch via
`fox chsh [bash|zsh]`. zsh runs with `zsh-syntax-highlighting` +
`zsh-autosuggestions` source-loaded for fish-parity interactivity.

# FILES

`/usr/bin/fox`
:   Bash dispatcher entry point.

`/usr/share/sideral/sideral.justfile`
:   Top-level Justfile (verb recipes).

`/usr/share/sideral/home.just`
:   `home` module Justfile (factory-reset).

`/usr/libexec/sideral/chsh.sh`
:   chsh implementation.

`/usr/libexec/sideral/home-factory-reset.sh`
:   factory-reset implementation.

`/etc/skel/Dotfiles/{bash,zsh,mise,ghostty,zed,nix}/`
:   Image-default dotfile seed. Copied into new user homes by `useradd`;
    user-domain thereafter.

# SEE ALSO

**just**(1), **rpm-ostree**(1), **flatpak**(1), **zed**(1), **mise**(1),
**bootc**(1)
