# chezmoi-dotfiles — Tasks

Feature spec: `.specs/features/chezmoi-dotfiles/spec.md`

## Status: COMPLETE

All 12 requirements implemented.

---

## T-01: Create chezmoi-defaults module [CDT-01/02/03] ✅

**Files changed:**
- `os/modules/chezmoi-defaults/rpm/sideral-chezmoi-defaults.spec` (new)
- `os/modules/chezmoi-defaults/src/usr/share/sideral/chezmoi/dot_bashrc` (new)
- `os/modules/chezmoi-defaults/src/usr/share/sideral/chezmoi/dot_zshrc` (new)
- `os/modules/chezmoi-defaults/src/usr/share/sideral/chezmoi/dot_config/niri/config.kdl` (new)
- `os/modules/chezmoi-defaults/src/usr/share/sideral/chezmoi/dot_config/noctalia/settings.json` (new)
- `os/modules/chezmoi-defaults/src/usr/share/sideral/chezmoi/dot_config/matugen/config.toml` (new)
- `os/modules/chezmoi-defaults/src/usr/share/sideral/chezmoi/dot_config/matugen/templates/ghostty` (new)
- `os/modules/chezmoi-defaults/src/usr/share/sideral/chezmoi/dot_config/matugen/templates/helix.toml` (new)
- `os/modules/chezmoi-defaults/src/usr/share/sideral/chezmoi/dot_config/nushell/env.nu` (new)
- `os/modules/chezmoi-defaults/src/usr/share/sideral/chezmoi/dot_config/nushell/config.nu` (new)
- `os/modules/chezmoi-defaults/src/usr/share/sideral/chezmoi/dot_config/mise/config.toml` (new)

**Note:** env.nu is copied verbatim from the shell-seed heredoc including the `$mise_shims` vs `$_mise_shims` variable-name inconsistency (CDT-02: content identical to current source).

---

## T-02: First-login auto-apply script [CDT-04/05/06/07] ✅

**Files changed:**
- `os/modules/chezmoi-defaults/src/etc/profile.d/sideral-chezmoi-defaults.sh` (new)

---

## T-03: apply-defaults ujust recipe [CDT-08] ✅

**Files changed:**
- `os/modules/shell-init/src/usr/share/ublue-os/just/60-custom.just` (modified)
  - Added `[group('Setup')] apply-defaults:` recipe
  - Added `ujust apply-defaults` to the `tools` recipe "Other ujust recipes" list

---

## T-04: README update [CDT-09] ✅

**Files changed:**
- `README.md` (modified)
  - Updated intro paragraph (first-login auto-apply mentioned)
  - Updated "What's in the image" table (User dotfiles row)
  - Updated "Set up dotfiles" section (added apply-defaults docs + personal dotfiles subsection)
  - Updated "What changed from GNOME-era" recipe list (chezmoi-init → chezmoi, apply-defaults added)

---

## T-05: Remove skel from desktop-niri [CDT-10] ✅

**Files changed:**
- `os/modules/desktop-niri/rpm/sideral-niri-defaults.spec` (modified — removed all %files /etc/skel/ entries)
- `os/modules/desktop-niri/src/etc/skel/` subtree deleted

---

## T-06: Remove shell-seed; extract login behaviors [CDT-11] ✅

**Files changed:**
- `os/modules/shell-init/src/usr/lib/systemd/user/sideral-shell-seed.service` (deleted)
- `os/modules/shell-init/src/usr/libexec/sideral-shell-seed` (deleted)
- `os/modules/shell-init/src/etc/profile.d/sideral-shell-migrate.sh` (new)
- `os/modules/shell-init/src/etc/profile.d/sideral-nushell-plugins.sh` (new)
- `os/modules/shell-init/rpm/sideral-shell-ux.spec` (modified)

**SPEC_DEVIATION CDT-11:** The spec only mentions extracting the broken-login-shell migration.
`sideral-shell-seed` also registered nushell plugins from `/usr/lib/nushell/plugins/` into the
user's `plugin.msgpackz`. Six plugins ship in the image (`nu_plugin_highlight`, `nu_plugin_rpm`,
etc.). Silently dropping registration would be a behavior regression. Extracted to
`sideral-nushell-plugins.sh` alongside the migration.

**sudo -n:** Changed from `sudo usermod` (which could prompt on login) to `sudo -n usermod`
(fails fast if no NOPASSWD grant — no login-blocking password prompts).

---

## CDT-12: Verification (no code changes)

Test commands to run in built image:
```bash
# Shell-seed gone
systemctl --user list-units | grep shell-seed   # should return nothing

# Skel gone
find /etc/skel -name 'config.kdl' -o -name 'settings.json' -o -name 'config.toml'  # nothing

# RPM file lists
rpm -ql sideral-services 2>/dev/null | grep shell-seed  # nothing (if package exists)
rpm -ql sideral-niri-defaults | grep /etc/skel          # nothing

# chezmoi source tree
find /usr/share/sideral/chezmoi -type f | wc -l         # 10
chezmoi apply --source /usr/share/sideral/chezmoi --dry-run --diff  # shows 10 creates

# First-login marker
ls ~/.local/share/sideral/chezmoi-defaults-applied      # exists after first shell open
```
