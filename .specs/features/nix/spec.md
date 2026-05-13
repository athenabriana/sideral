# Sideral — Nix + nh

## Problem Statement

Sideral's user-level config is split across RPM-layered CLI tools (`sideral-cli-tools`), mise-managed runtimes, system-level flatpak installs, and a stow tree of dotfiles. Adding, removing, or updating anything requires touching at least two places (e.g., rebuild the image for a new RPM, or edit flake.nix + run a command). There is no single source of truth for "what packages does this user want."

This spec ships **nix + [nh](https://github.com/nix-community/nh)** as the declarative user backend. Nix is installed by a first-boot oneshot (Determinate installer, ostree planner). `nh` replaces `home-manager switch` and `nix-collect-garbage` with a unified CLI (`nh home switch`, `nh clean`). The stow tree continues to own dotfiles (bashrc, starship, ghostty, zed config). Fox wraps common operations: `fox home sync/diff/edit`.

## Goals

- [ ] After `rpm-ostree rebase` + reboot + first-boot oneshot, `nix --version` resolves and `nix-daemon.service` is active
- [ ] `/nix/store` and per-user nix profiles survive `rpm-ostree upgrade` between image rebases
- [ ] `nh` is installed via user's nix profile and provides `nh home`, `nh clean`, `nh search`
- [ ] A starter `flake.nix` ships at `~/.config/nix/flake.nix` with working nh-compatible home configuration (packages + programs + services)
- [ ] `fox home sync` runs `nh home switch` to apply the flake
- [ ] `fox home edit` opens the flake.nix, `fox home diff` shows pending changes
- [ ] Existing sideral integrations (rpm-ostree, podman, mise, stow seeds) coexist with nix without conflict

## Out of Scope

| Feature | Reason |
|---|---|
| NixOS modules | Sideral remains rpm-ostree atomic, not NixOS. |
| Pinned nixpkgs revision in the image | User pins in their own `flake.lock`. |
| Migration of existing RPM-layered tools to nix | Per-user manual choice. `sideral-cli-tools` still ships image-default tools. |
| nix-flatpak / home-manager | `nh home` replaces both. |
| `fox.toml` → flake generator | User writes `flake.nix` directly. No extra abstraction layer. |

---

## User Stories

### P1: Nix ready after first boot ⭐ MVP

**Story:** Rebase to a sideral image including this feature, reboot — nix is available system-wide without running any installer.

**Acceptance:**

1. **NIX-01** — Determinate `nix-installer` binary is pre-downloaded at image build time and staged at `/usr/libexec/nix-installer`.
2. **NIX-02** — `sideral-nix-bootstrap.service` runs on first boot (system oneshot, `After=network-online.target ostree-remount.service`), executes `nix-installer install ostree --persistence /var/lib/nix --no-confirm`.
3. **NIX-03** — Service is guarded by `ConditionPathExists=!/var/lib/sideral/nix-setup-done`; writes marker on success, retries on failure.
4. **NIX-04** — After service completes, `nix --version` resolves on every user shell (bash + zsh).
5. **NIX-05** — `/nix` is a bind-mount from `/var/lib/nix` (verified by `findmnt /nix`).
6. **NIX-06** — `nix-daemon.service` is active and enabled, created by the installer.
7. **NIX-07** — Sudoers snippet at `/etc/sudoers.d/nix-sudo-env` adds `/nix/var/nix/profiles/default/bin` to `secure_path`.
8. **NIX-08** — Works with any composefs state (enabled, disabled, root.transient) — no `prepare-root.conf` changes needed.

**Test:** Fresh VM rebase → reboot → `systemctl status sideral-nix-bootstrap.service` (exited 0) → `nix --version` → `findmnt /nix` shows `/var/lib/nix` source.

---

### P1: Persistence across upgrades ⭐ MVP

**Story:** Packages installed via nix survive image rebases — CI rebuilds don't blow away user state.

**Acceptance:**

1. **NIX-09** — After `rpm-ostree upgrade` to a new image commit + reboot, prior `nix profile install` packages still resolve.
2. **NIX-10** — `rpm-ostree rollback` preserves `/var/lib/nix` (state in `/var`, preserved across ostree generations).
3. **NIX-11** — `nh clean` (or `nix-collect-garbage -d`) removes unreferenced store paths without affecting other users.

**Test:** Install package → CI rerun → `rpm-ostree upgrade` → reboot → package still on `$PATH`.

---

### P1: `nh` bootstraps on first `fox home init` ⭐ MVP

**Story:** User runs `fox home init` once — it copies the stow tree, installs `nh` via `nix profile`, and runs the starter config.

**Acceptance:**

1. **NIX-12** — A starter `flake.nix` and `flake.lock` ship at `/etc/skel/.config/sideral/stow/nix/.config/nix/flake.nix`.
2. **NIX-13** — `fox home init` copies stow tree, runs `stow -R nix`, then `nix profile install nixpkgs#nh` and `nh home switch -c $(whoami)` (NH_FLAKE resolves to ~/.config/nix).
3. **NIX-14** — `nh` is NOT pre-installed in the image — `nix profile install` fetches it on first init.
4. **NIX-15** — After init, `nh home --version` resolves and `nh home switch` succeeds.

**Test:** New user → `fox home init` → `nh home switch` succeeds → `nh clean --help` resolves.

---

### P2: Starter flake.nix with nh

**Story:** The image ships a working starter `flake.nix` with packages and services wired in — user just uncomments what they want.

**Acceptance:**

1. **NIX-16** — Starter flake has `homeConfigurations."USER"` output using `builtins.getEnv "USER"` for username.
2. **NIX-17** — Starter flake has a commented `home.packages` section with common CLI tools (bat, eza, ripgrep, jq, yq, nh) as examples.
3. **NIX-18** — `nh` is listed in `home.packages` (managed by nh itself, self-referential but works).
4. **NIX-19** — Starter flake has commented `programs.mise.enable = true` section.
5. **NIX-20** — Starter flake has commented `services.flatpak.packages` section with flathub remote.

**Test:** `cat /etc/skel/.config/sideral/stow/nix/.config/nix/flake.nix` shows all sections with examples.

---

### P2: Flake is a stow package

**Story:** The `flake.nix` lives in the stow tree — it's a symlink, directly editable, managed by the same stow workflow as other dotfiles.

**Acceptance:**

1. **NIX-21** — `~/.config/nix/flake.nix` is a symlink to `~/.config/sideral/stow/nix/.config/nix/flake.nix`.
2. **NIX-22** — `fox home sync` runs `stow -R nix` before `nh home switch` — stow re-asserts broken symlinks.
3. **NIX-23** — `fox home edit` opens `~/.config/nix/flake.nix` (the symlink target, directly editable).
4. **NIX-24** — `fox home diff` runs `nh home switch --dry` (or equivalent build-only mode) and shows closure diff.
5. **NIX-25** — `fox home factory-reset` preserves `~/.config/nix/flake.nix` (skips the nix stow package during wipe).

**Test:** `ls -la ~/.config/nix/flake.nix` shows symlink. Edit → `fox home sync` applies. `fox home diff` shows diff.

---

### P2: NH_FLAKE set in shell init

**Story:** The `NH_FLAKE` environment variable is set in user's shell rc so `nh home switch` resolves without an explicit path.

**Acceptance:**

1. **NIX-26** — `NH_FLAKE` is exported in `~/.bashrc` and `~/.zshrc` via the stow tree (guarded by `command -v nh`).
2. **NIX-27** — Value is `"$HOME/.config/nix"` — the stow-managed flake directory.

**Test:** `source ~/.bashrc && echo "$NH_FLAKE"` prints `$HOME/.config/nix`.

---

### P2: nix-daemon multi-user mode

1. **NIX-28** — `nix-daemon.service` active + enabled at boot.
2. **NIX-29** — Non-privileged users install via daemon socket, no setuid.
3. **NIX-30** — Systemd `Restart=always` within 5s on crash.
4. **NIX-31** — nixbld UIDs 30000-30031 created at image build time, stable across rebuilds.

---

### P2: SELinux compatibility (validation gate)

1. **NIX-32** — No AVC denials related to `/nix` in default-enforcing mode.
2. **NIX-33** — Contexts retained across rebase (inherited from `/var/lib/nix`, labeled `var_t`).

---

### P3: `fox nix-doctor`

1. **NIX-34** — `fox nix-doctor` prints: nix version, nix-daemon status, `/nix` mount info, SELinux context of `/nix/store`, current user profile status, nh version, NH_FLAKE value.
2. **NIX-35** — On failure, prints one-line remediation hint.

---

## Edge Cases

- **First boot offline**: `sideral-nix-bootstrap.service` fails, marker absent, retries on next boot. No user-facing error.
- **`/nix` absent after failed bootstrap**: `fox nix-doctor` flags bootstrap-not-done, hints `systemctl start sideral-nix-bootstrap`.
- **`fox home init` before nix bootstrap completes**: Fails with clear "nix not ready" message. User waits for bootstrap or reboots.
- **Fresh rebase with new starter `flake.nix`**: Existing user's `~/.config/nix/flake.nix` is untouched (skel only applies at `fox home init` time).
- **`fox home factory-reset` with custom flake**: The nix stow package is preserved. Factory-reset seeds bash/zsh/ghostty/zed stow packages from skel but does NOT touch `~/.config/nix/flake.nix`.
- **`rpm-ostree rollback` to pre-nix deployment**: nix-daemon absent, `/var/lib/nix` intact. Rolling forward restores nix without data loss.
- **Composefs state change**: Works regardless — `.mount` unit binds `/var/lib/nix` (in `/var`) to `/nix`, independent of composefs.

---

## Requirement Traceability

| ID | Story | Phase | Status |
|---|---|---|---|
| NIX-01 | P1: nix-installer binary pre-downloaded at build | Design | Pending |
| NIX-02 | P1: first-boot oneshot runs installer | Design | Pending |
| NIX-03 | P1: oneshot guarded by marker, retries on failure | Design | Pending |
| NIX-04 | P1: `nix --version` resolves after bootstrap | Design | Pending |
| NIX-05 | P1: `/nix` is bind-mount from `/var/lib/nix` | Design | Pending |
| NIX-06 | P1: `nix-daemon.service` active + enabled | Design | Pending |
| NIX-07 | P1: sudoers snippet for nix profile bin | Design | Pending |
| NIX-08 | P1: composefs-independent (no prepare-root.conf) | Design | Pending |
| NIX-09 | P1: packages survive rpm-ostree upgrade | Design | Pending |
| NIX-10 | P1: rollback preserves `/var/lib/nix` | Design | Pending |
| NIX-11 | P1: `nh clean` per-user | Design | Pending |
| NIX-12 | P1: starter flake.nix + lock in skel stow tree | Design | Pending |
| NIX-13 | P1: `fox home init` copies stow + installs nh + runs | Design | Pending |
| NIX-14 | P1: nh fetched via nix profile (no pre-install) | Design | Pending |
| NIX-15 | P1: nh resolves after init | Design | Pending |
| NIX-16 | P2: starter flake has `builtins.getEnv "USER"` | Design | Pending |
| NIX-17 | P2: starter flake has commented `home.packages` | Design | Pending |
| NIX-18 | P2: nh in home.packages | Design | Pending |
| NIX-19 | P2: starter flake has mise section | Design | Pending |
| NIX-20 | P2: starter flake has flatpak section | Design | Pending |
| NIX-21 | P2: `flake.nix` is a stow symlink | Design | Pending |
| NIX-22 | P2: `fox home sync` runs stow then nh home switch | Design | Pending |
| NIX-23 | P2: `fox home edit` opens the flake | Design | Pending |
| NIX-24 | P2: `fox home diff` shows closure diff | Design | Pending |
| NIX-25 | P2: factory-reset preserves flake.nix | Design | Pending |
| NIX-26 | P2: NH_FLAKE in bashrc/zshrc (guarded) | Design | Pending |
| NIX-27 | P2: NH_FLAKE value = "$HOME/.config/nix" | Design | Pending |
| NIX-28 | P2: nix-daemon active at boot | Design | Pending |
| NIX-29 | P2: non-root user install via daemon socket | Design | Pending |
| NIX-30 | P2: daemon Restart=always on crash | Design | Pending |
| NIX-31 | P2: stable nixbld UIDs 30000-30031 | Design | Pending |
| NIX-32 | P2: no AVC denials in enforcing mode | Design | Pending |
| NIX-33 | P2: SELinux contexts retained across rebase | Design | Pending |
| NIX-34 | P3: `fox nix-doctor` prints diagnostics | Design | Pending |
| NIX-35 | P3: `fox nix-doctor` remediation hints | Design | Pending |

**Total:** 35 requirements.

---

## Success Criteria

- [ ] First-boot oneshot completes → `nix --version` resolves → `nix profile install nixpkgs#hello && hello` prints "Hello, world!"
- [ ] `nix-daemon.service` shows zero failures after a week of daily use
- [ ] After 4 CI-triggered rebases, user's installed nix packages still resolve
- [ ] `fox home init` on a new user account installs nh and applies the starter flake
- [ ] `fox home sync` applies changes to `flake.nix` without reboot
- [ ] `fox home edit` opens the correct file; editing and re-running sync applies changes
- [ ] `ausearch -m AVC -ts boot` shows zero denials related to `/nix`
- [ ] `fox home factory-reset` does not wipe the user's `flake.nix`
- [ ] `nh --version` resolves; `nh home switch` applies flake changes; `nh clean` runs without error
