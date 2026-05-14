# fox-enhancements Specification

## Problem Statement

The `fox` feature (shipped 2026-05-11) introduced `/usr/bin/fox` as silverfox's operator CLI, replacing the ublue `ujust` extension slot (`60-custom.just`). However, the underlying `ublue-os-just` RPM (inherited from `silverblue-main:44`) is still present in the image. This creates two problems:

1. **`ujust` still works** — `ujust --list` shows 26 stock ublue recipes alongside `fox`'s 9 verbs. Two operator CLIs for one image: confusing surface, split muscle memory.

2. **`ublue-os-just` ships dependencies silverfox doesn't use** — `/usr/lib/ujust/libformatting.sh`, `/usr/lib/ujust/ujust.sh`, the full justfile module tree at `/usr/share/ublue-os/just/*.just`, and the `ublue-motd` binary. Dead weight and source of surprise behavior (e.g., `ujust chsh` from ublue's stock 60-custom.just still works if the old 60-custom.just was only deleted from silverfox's tree — wait, it was deleted. But ublue-os-just also has its own 60-custom.just template slot that doesn't exist anymore in silverfox. Actually, the issue is just that `ublue-os-just` ships recipes that fox duplicates or supersedes.)

3. **Removing `ublue-os-just` kills `/etc/profile.d/user-motd.sh`** — this is the mechanism that displays the `fox`-referencing motd banner on every login. Without a replacement, the motd vanishes.

Some ujust recipes *are* genuinely useful and should be ported to fox before the RPM is removed. Others (bios, broadcom-wl, DaVinci Resolve, etc.) have no place in a personal dev-focused image.

## Goals

- [ ] `ublue-os-just` RPM removed from both `silverfox` and `silverfox-nvidia` image variants
- [ ] `/usr/bin/ujust` no longer exists in the image
- [ ] `/etc/profile.d/silverfox-motd.sh` ships in `silverfox-shell-ux`, replacing ublue's `user-motd.sh` — same behavior (double-source guard, `~/.config/no-show-user-motd` opt-out, `cat /etc/user-motd`)
- [ ] Useful ujust recipes ported to fox before removal
- [ ] `%changelog` entries in silverfox specs cleaned of future-irrelevant ujust references (historical entries left intact)
- [ ] `README.md`, `Justfile` (build-side), `STATE.md`, `ROADMAP.md` updated

## Out of Scope

| Feature | Reason |
|---|---|
| `fox-home-sync` v2 (declarative manifests) | Separate backlog feature |
| Replacing shell-level fzf bindings | Unchanged |
| Auto-completion for new fox verbs | Deferred to v1.1 (same as fox spec D-09) |
| Removing `just` (upstream task runner) | Still used by `fox` dispatcher + build-side `Justfile` |

## User Stories

### P1: fox gains new verbs (ported from ujust) ⭐ MVP

**Story**: Before `ublue-os-just` is removed, fox absorbs the useful ujust recipes so no capability is lost.

**Acceptance**:

1. **FOXEN-01** — `fox toggle-banner` toggles `~/.config/no-show-user-motd`. Implemented as a recipe in `silverfox.justfile`:
   ```
   # Toggle display of the login banner (motd)
   toggle-banner:
       #!/usr/bin/bash
       if test -e "${HOME}/.config/no-show-user-motd"; then
         rm -f "${HOME}/.config/no-show-user-motd"
         @echo "Banner enabled on next login."
       else
         mkdir -p "${HOME}/.config"
         touch "${HOME}/.config/no-show-user-motd"
         @echo "Banner disabled."
       fi
   ```
   Recipe signature: `toggle-banner:` (no args). Ported from ublue's `toggle-user-motd` (5 lines). `fox toggle-banner` invokes the recipe via just.

2. **FOXEN-02** — `fox cleanup` expanded from `rpm-ostree cleanup -prm` only to also run:
   - `podman image prune -af`
   - `flatpak uninstall --unused`
   Matching ublue's `clean-system` recipe. Recipe body:
   ```
   # Clean up old podman images, unused flatpaks, and rpm-ostree metadata
   cleanup *args:
       #!/usr/bin/bash
       if [ $# -eq 0 ]; then
         podman image prune -af
         flatpak uninstall --unused
         rpm-ostree cleanup -prm
       else
         rpm-ostree cleanup "$@"
       fi
   ```
   When called with explicit args (`fox cleanup -bm`), passes through to rpm-ostree only (preserving existing behavior for power users).

3. **FOXEN-03** — `fox upgrade-firmware` wraps `fwupdmgr`:
   ```
   # Update device firmware
   upgrade-firmware:
       fwupdmgr refresh --force
       fwupdmgr get-updates
       fwupdmgr update
   ```
   Recipe signature: `upgrade-firmware:` (no args). Verbatim from ublue's `update-firmware` (3 lines). `fox upgrade-firmware` streams output.

4. **FOXEN-04** — `fox upgrade` expanded from `rpm-ostree upgrade` only to also run `flatpak update` and `distrobox upgrade -a` after the ostree update. The current split (`fox upgrade` = rpm-ostree, `fox update` = flatpak) is confusing — `upgrade` should mean "update everything". Implementation:
   ```
   upgrade *args:
       #!/usr/bin/bash
       rpm-ostree upgrade "$@"
       echo "--- flatpak update ---"
       flatpak update -y
       if command -v distrobox >/dev/null 2>&1; then
         echo "--- distrobox upgrade ---"
         distrobox upgrade -a
       fi
       @echo "Reboot to apply the staged deployment."
   ```
   `fox update` stays as `flatpak update {{args}}` (lightweight, no reboot needed). `fox upgrade` becomes the comprehensive "update everything and reboot" verb. `distrobox upgrade` gated on `command -v` so the verb doesn't fail if no distroboxes exist.

5. **FOXEN-05** — All new verbs pass `just fox-lint` (shellcheck on inline bash within recipe bodies is NOT checked by shellcheck — just recipes contain bash that just evaluates; the pre-flight test coverage (FOXEN-06) covers this gap). `bash -n` on any extracted libexec scripts if the recipe body grows past 10 lines.

**Test**: `just fox-lint && just fox-test` passes. New verbs manually verified: `fox toggle-motd` creates/deletes the marker; `fox cleanup` doesn't error on a system with no podman images; `fox firmware` runs fwupdmgr; `fox upgrade` runs all three update commands.

---

### P1: motd.sh replacement ⭐ MVP

**Story**: When `ublue-os-just` is removed, the login banner still appears.

**Acceptance**:

1. **FOXEN-06** — `/etc/profile.d/silverfox-motd.sh` ships in `silverfox-shell-ux`:
   ```bash
   # Prevent doublesourcing
   if [ -z "$SILVERFOX_MOTD_SOURCED" ]; then
     SILVERFOX_MOTD_SOURCED="Y"
     if test -d "$HOME"; then
       if test ! -e "$HOME"/.config/no-show-user-motd; then
         if test -s "/etc/user-motd"; then
           cat /etc/user-motd
         fi
       fi
     fi
   fi
   ```
   Same behavior as ublue's `user-motd.sh`: double-source guard, opt-out file check, cats `/etc/user-motd`. Different var name (`SILVERFOX_MOTD_SOURCED`) to avoid collision if the ublue version runs first (won't happen after removal, but defensive).

2. **FOXEN-07** — `silverfox-shell-ux.spec` `%files` adds `/etc/profile.d/silverfox-motd.sh`.

3. **FOXEN-08** — `/etc/user-motd` content unchanged (already references `fox` verbs from the fox feature). Verify:
   - `fox` (discovery)
   - `man silverfox` / `fox cheatsheet`
   - `fox upgrade` / `fox rollback` / `fox update`
   - `fox home factory-reset`
   - No `ujust` references remain

**Test**: Reboot/login shows the silverfox motd banner. `touch ~/.config/no-show-user-motd; login` hides it. `rm ~/.config/no-show-user-motd; login` shows it again.

---

### P1: `ublue-os-just` removed from image ⭐ MVP

**Story**: The image no longer ships ublue's justfile ecosystem.

**Acceptance**:

1. **FOXEN-09** — `os/lib/install-packages.sh` (or equivalent Layer-1 steps) does NOT install `ublue-os-just`. If currently inherited as a dependency of the base image, it must be explicitly removed in the prune step of `os/lib/install-packages.sh`. (Check: `rpm -e ublue-os-just` or add to the prune list alongside firefox/firefox-langpacks/dconf-editor/gnome-software/gnome-software-rpm-ostree.)

2. **FOXEN-10** — After removal:
   - `/usr/bin/ujust` not present
   - `/etc/profile.d/user-motd.sh` not present
   - `/usr/share/ublue-os/justfile` not present
   - `/usr/share/ublue-os/just/` tree not present
   - `/usr/lib/ujust/` not present
   - `/usr/libexec/ublue-motd` not present

3. **FOXEN-11** — `rpm -q ublue-os-just` returns "package ublue-os-just is not installed" in the built image.

**Test**: `just build` succeeds. `podman run --rm localhost/silverfox:dev rpm -q ublue-os-just` exits non-zero with "not installed". `podman run --rm localhost/silverfox:dev ujust` exits 127 (not found).

---

### P2: Housekeeping

**Story**: All documentation and specs reflect the removal.

**Acceptance**:

1. **FOXEN-12** — `README.md` updated:
   - "Common tasks" section references `fox` verbs only (no mention of `ujust`)
   - No references to ublue's stock ujust recipes
   - Note that `ublue-os-just` is removed; `fox` is the operator CLI

2. **FOXEN-13** — `Justfile` (build-side) updated:
   - `fox-lint` recipe unchanged (still checks fox scripts)
   - No ujust references
   - Remove any stale `ujust` comments

3. **FOXEN-14** — `.specs/project/STATE.md` updated:
   - "Operator CLI" section notes ublue-os-just removal
   - New fox verbs listed
   - "Welcome UX" / motd section notes replacement

4. **FOXEN-15** — `.specs/project/ROADMAP.md` updated:
   - fox-enhancements moved to "Previous (shipped)"
   - `fox-home-sync` still in Backlog (unchanged)

5. **FOXEN-16** — `.specs/features/fox/spec.md` NOT modified (historical record of v1). FOXEN requirements live in this spec.

---

### P2: Cleanup of %description blocks

**Story**: RPM `%description` blocks in silverfox modules no longer reference ujust.

**Acceptance**:

1. **FOXEN-17** — `grep -rn 'ujust\|ublue-os-just\|ublue-motd' os/modules/*/rpm/*.spec` returns zero matches outside `%changelog`. All `%description` blocks cleaned up.

---

## Edge Cases

- **Existing systems that have `ublue-os-just` installed**: next rebase (`rpm-ostree upgrade`) removes it automatically since the new image won't include it. Standard atomic workflow.
- **User runs `ujust` from muscle memory after rebase**: `bash: ujust: command not found`. No mitigation needed — single-user image, one-error-then-remember.
- **`distrobox` not installed**: `fox upgrade` gates `distrobox upgrade -a` behind `command -v`, so the verb completes without error.
- **No podman images to prune**: `podman image prune -af` exits 0 with nothing to do. `fox cleanup` is idempotent.
- **No fwupd supported hardware**: `fwupdmgr refresh` fails gracefully. `fox firmware` propagates the error. Acceptable — user checks `fwupdmgr status` first.
- **User created their own `~/.config/no-show-user-motd`**: `fox toggle-motd` removes it (re-enables motd). Second `fox toggle-motd` creates it again (disables). Standard toggle.

## Requirement Traceability

| Story | Requirement IDs | Count |
|---|---|---|
| P1: New fox verbs | FOXEN-01 … FOXEN-05 | 5 |
| P1: motd.sh replacement | FOXEN-06 … FOXEN-08 | 3 |
| P1: ublue-os-just removed | FOXEN-09 … FOXEN-11 | 3 |
| P2: Housekeeping | FOXEN-12 … FOXEN-16 | 5 |
| P2: Spec cleanup | FOXEN-17 | 1 |

**Total**: 17 testable requirements.

## Success Criteria

- [ ] `just build` succeeds; `bootc container lint` passes
- [ ] Image does not contain `ublue-os-just` (verified via `rpm -q` in container)
- [ ] `silverfox.spec/description` `%description` references to `ublue-os-just` cleaned
- [ ] `fox toggle-banner` creates/deletes `~/.config/no-show-user-motd`
- [ ] `fox cleanup` runs podman prune + flatpak unused + rpm-ostree cleanup
- [ ] `fox upgrade-firmware` runs fwupdmgr refresh + get-updates + update
- [ ] `fox upgrade` runs rpm-ostree upgrade + flatpak update + distrobox upgrade
- [ ] `/etc/profile.d/silverfox-motd.sh` ships; motd banner displays on login
- [ ] No `ujust` references remain in `%description` blocks, `README.md`, or build-side `Justfile` (outside `%changelog`)
- [ ] STATE.md + ROADMAP.md updated
