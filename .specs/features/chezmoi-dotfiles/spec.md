# chezmoi-dotfiles Specification

## Problem Statement

sideral's per-user dotfile seeding uses two mechanisms that cannot update existing users:

1. **`/etc/skel/`** — copied once at `useradd` time. Never updated. Any new default added
   to niri config, noctalia settings, or matugen templates after first login is invisible to
   existing users.
2. **`sideral-shell-seed.service`** — idempotent write-once seeding of `.bashrc`, `.zshrc`,
   nushell env/config, and mise config. Also never updates files the user has customized.

Result: users who upgrade the image get new packages but their shell and compositor configs
stay frozen at whatever was seeded on first login. Adding a new default keybind to niri
config, changing the matugen template, or improving the nushell baseline requires the user
to manually diff and copy — or wait for a fresh install.

chezmoi is already in the image (CHM-06). It tracks source state vs destination state and
can apply changes to clean files silently while showing diffs for files the user has
customized. Shipping a chezmoi source tree at `/usr/share/sideral/chezmoi/` gives the
update semantics that skel + shell-seed cannot provide.

---

## Goals

- Replace `/etc/skel/.config/niri/`, `/etc/skel/.config/noctalia/`, `/etc/skel/.config/matugen/`
  (one-time copy) with chezmoi-managed defaults that can be updated on image upgrade
- Replace `sideral-shell-seed.service` / `sideral-shell-seed` script seeding of `.bashrc`,
  `.zshrc`, nushell `env.nu` + `config.nu`, `mise/config.toml`
- Ship `/usr/share/sideral/chezmoi/` in the image with all managed files in chezmoi source
  format (`dot_` prefixed names, mirroring `~/.local/share/chezmoi/` layout)
- Auto-apply image defaults on first login (no user action required)
- On image upgrade: user runs one command to pull in new defaults; customized files get a
  diff prompt, clean files update silently

---

## Out of Scope

| Feature | Reason |
|---|---|
| User's personal chezmoi dotfiles repo | Handled by `chezmoi-home` (CHM-14); independent of image defaults |
| Auto-applying image updates on reboot/upgrade | User-triggered; forced auto-update would silently clobber customizations |
| chezmoi templates (`.tmpl` variables) in image source | Not needed for static stubs; keeps the source readable without chezmoi knowledge |
| Git-backed image chezmoi source | `/usr/share/sideral/chezmoi/` is read-only filesystem path, not a git remote |
| Migrating existing skel-seeded users automatically | First-login marker doesn't exist on pre-existing users; chezmoi-update recipe covers them |

---

## Managed Files

All ten files currently seeded by skel or `sideral-shell-seed`:

| Destination path | Current source | chezmoi source name |
|---|---|---|
| `~/.config/niri/config.kdl` | `/etc/skel/.config/niri/config.kdl` | `dot_config/niri/config.kdl` |
| `~/.config/noctalia/settings.json` | `/etc/skel/.config/noctalia/settings.json` | `dot_config/noctalia/settings.json` |
| `~/.config/matugen/config.toml` | `/etc/skel/.config/matugen/config.toml` | `dot_config/matugen/config.toml` |
| `~/.config/matugen/templates/ghostty` | `/etc/skel/.config/matugen/templates/ghostty` | `dot_config/matugen/templates/ghostty` |
| `~/.config/matugen/templates/helix.toml` | `/etc/skel/.config/matugen/templates/helix.toml` | `dot_config/matugen/templates/helix.toml` |
| `~/.bashrc` | `sideral-shell-seed` (inline heredoc) | `dot_bashrc` |
| `~/.zshrc` | `sideral-shell-seed` (inline heredoc) | `dot_zshrc` |
| `~/.config/nushell/env.nu` | `sideral-shell-seed` (inline heredoc) | `dot_config/nushell/env.nu` |
| `~/.config/nushell/config.nu` | `sideral-shell-seed` (inline heredoc) | `dot_config/nushell/config.nu` |
| `~/.config/mise/config.toml` | `sideral-shell-seed` (inline heredoc) | `dot_config/mise/config.toml` |

---

## User Stories

### P1: Image ships chezmoi source tree ⭐ MVP

**Story**: `/usr/share/sideral/chezmoi/` in the built image contains all ten managed files
in chezmoi source format. Content matches the current skel / shell-seed defaults exactly.

**Acceptance**:

1. **CDT-01** — A new sub-package `sideral-chezmoi-defaults` (spec at
   `os/modules/chezmoi-defaults/rpm/sideral-chezmoi-defaults.spec`) ships
   `/usr/share/sideral/chezmoi/` with the ten files from the table above. The package
   `Requires: chezmoi` (already in `sideral-cli-tools` via CHM-06).

2. **CDT-02** — The ten chezmoi source files exist at the correct paths under
   `/usr/share/sideral/chezmoi/`. Their content is identical to the current
   `/etc/skel/...` and `sideral-shell-seed` inline content (no behavior change on first
   install; only the lifecycle mechanism changes).

3. **CDT-03** — File permissions: `644` for all source files; `755` for all directories.
   No executable bit on config content.

**Test**: `find /usr/share/sideral/chezmoi -type f | wc -l` returns 10 in the built image.
`chezmoi apply --source /usr/share/sideral/chezmoi --dry-run --diff` on a fresh user home
shows all ten files would be created.

---

### P1: First-login auto-apply ⭐ MVP

**Story**: A new user's first shell session applies all image defaults without any
prompts or manual steps.

**Acceptance**:

1. **CDT-04** — `sideral-chezmoi-defaults` ships
   `/etc/profile.d/sideral-chezmoi-defaults.sh` (mode `0644`, sourced not executed).
   Guarded by:
   ```sh
   [ -f "$HOME/.local/share/sideral/chezmoi-defaults-applied" ] && return 0
   ```

2. **CDT-05** — When the marker is absent, the script runs:
   ```sh
   chezmoi apply --source /usr/share/sideral/chezmoi --force --quiet 2>/dev/null || true
   mkdir -p "$HOME/.local/share/sideral"
   touch "$HOME/.local/share/sideral/chezmoi-defaults-applied"
   ```
   `--force` applies without prompting (first-time; user hasn't customized anything yet).
   Errors are suppressed and do not abort shell startup.

3. **CDT-06** — Subsequent logins: marker exists, script returns immediately (no chezmoi
   invocation). The auto-apply fires exactly once per user account lifetime unless the
   marker is deleted.

4. **CDT-07** — The script is also guarded by `command -v chezmoi >/dev/null 2>&1` before
   invoking chezmoi, so removing chezmoi via `rpm-ostree override remove chezmoi` doesn't
   break shell startup.

**Test**: Fresh user → open shell → `ls ~/.config/niri/config.kdl ~/.bashrc ~/.zshrc
~/.config/mise/config.toml` all exist. Marker at
`~/.local/share/sideral/chezmoi-defaults-applied` exists. Open second shell → no chezmoi
invocation (marker present).

---

### P1: Image upgrade update path ⭐ MVP

**Story**: After `rpm-ostree upgrade`, the user can pull in new image defaults. Clean files
apply silently; files they've customized show a diff prompt.

**Acceptance**:

1. **CDT-08** — `os/modules/shell-init/src/usr/share/ublue-os/just/60-custom.just` gains an
   `apply-defaults` recipe (same file that ships `chsh`, `theme`, `chezmoi-init`, etc.):
   ```
   [group('Setup')]
   apply-defaults:
       chezmoi apply --source /usr/share/sideral/chezmoi
   ```
   No `--force`. chezmoi's default conflict behavior: for files that differ from both the
   source state and the destination state (user-customized), chezmoi prompts with a diff.
   For clean files (destination matches previous source state), chezmoi updates silently.

2. **CDT-09** — `README.md` documents: "After `rpm-ostree upgrade`, run
   `ujust apply-defaults` to pull in new default configs. chezmoi will show diffs for files
   you've customized and let you choose."

**Test**: Modify `~/.bashrc` on a test user. Update `/usr/share/sideral/chezmoi/dot_bashrc`
content. Run `ujust apply-defaults`. Confirm chezmoi detects the conflict and prompts
rather than silently overwriting.

---

### P1: Remove replaced mechanisms ⭐ MVP

**Story**: skel config dirs and `sideral-shell-seed` are removed. No duplication between
the two seeding mechanisms.

**Acceptance**:

1. **CDT-10** — `sideral-niri-defaults.spec` `%files` removes:
   - `%dir /etc/skel/.config/niri`
   - `/etc/skel/.config/niri/config.kdl`
   - `%dir /etc/skel/.config/noctalia`
   - `/etc/skel/.config/noctalia/settings.json`
   - `%dir /etc/skel/.config/matugen`
   - `%dir /etc/skel/.config/matugen/templates`
   - `/etc/skel/.config/matugen/config.toml`
   - `/etc/skel/.config/matugen/templates/ghostty`
   - `/etc/skel/.config/matugen/templates/helix.toml`
   The `src/etc/skel/` subtree in `os/modules/desktop-niri/` is deleted.

2. **CDT-11** — `sideral-shell-seed.service` unit and `sideral-shell-seed` script are
   removed from the `sideral-services` package. `sideral-services.spec` `%files` no longer
   lists either. The broken-login-shell migration (checks if login shell binary exists;
   falls back to zsh) is extracted into `/etc/profile.d/sideral-shell-migrate.sh` and
   shipped by `sideral-shell-ux` — this logic is unrelated to dotfile seeding and should
   survive the removal.

3. **CDT-12** — `systemd --user list-units | grep shell-seed` returns nothing on a
   fresh or upgraded session. `/etc/skel/.config/niri/` does not exist in the built image.

**Test**: `rpm -ql sideral-services` lists no `shell-seed` entries.
`find /etc/skel -name 'config.kdl' -o -name 'settings.json' -o -name 'config.toml'`
returns nothing. `rpm -ql sideral-niri-defaults` lists no `/etc/skel/` paths.

---

## Edge Cases

- **Existing user rebasing from a pre-chezmoi-dotfiles sideral image**: The first-login
  marker doesn't exist, so the profile.d script fires on their next login. `--force` will
  overwrite their skel-seeded copies. If they've customized those files, the overwrite
  happens silently on this auto-apply. Mitigation: document `ujust apply-defaults` as the
  safer upgrade path for existing users who want to review diffs first.
- **User who has `chezmoi init <repo>`**: Their `~/.local/share/chezmoi/` (personal source)
  is completely independent. `chezmoi apply --source /usr/share/sideral/chezmoi` only
  reads `/usr/share/sideral/chezmoi/`; it doesn't touch `~/.local/share/chezmoi/`. The
  two sources can manage the same files — last applied wins.
- **User who deletes the marker**: The auto-apply fires again on next login with `--force`,
  re-seeding all managed files from the current image source.
- **`/usr/share/sideral/chezmoi/` changes between reboots (rpm-ostree layering)**: The
  marker is already set, so no auto-apply. The user must run `ujust apply-defaults`
  explicitly.
- **chezmoi not installed** (e.g., overridden out): Profile.d script is a no-op (guarded
  by `command -v chezmoi`). User gets no defaults seeded; the shell starts normally.

---

## Requirement Traceability

| Story | Requirement IDs | Count |
|---|---|---|
| P1: Image ships chezmoi source tree | CDT-01 … CDT-03 | 3 |
| P1: First-login auto-apply | CDT-04 … CDT-07 | 4 |
| P1: Image upgrade update path | CDT-08 … CDT-09 | 2 |
| P1: Remove replaced mechanisms | CDT-10 … CDT-12 | 3 |

**Total**: 12 testable requirements.

---

## Success Criteria

- [ ] `just build` succeeds with `sideral-chezmoi-defaults` package included.
- [ ] Fresh VM: new user opens shell → all ten config files appear in `$HOME` without any
  manual action. No skel copy, no shell-seed service — only the profile.d apply.
- [ ] `ujust apply-defaults` applies clean default updates silently and prompts on
  user-modified files.
- [ ] `systemctl --user list-units | grep shell-seed` returns nothing.
- [ ] `/etc/skel/.config/niri/` does not exist in the built image.
