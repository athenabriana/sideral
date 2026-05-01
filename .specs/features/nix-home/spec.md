# nix-home Specification

## Retired

**Status: dropped pre-VM-verification on 2026-05-01.** Replaced by `chezmoi-home`.

This feature was implemented locally (40 requirements, 15 locked decisions, 9 of 9 tasks complete) but never verified on a real VM. Three documented frictions on Fedora atomic 42+ — composefs vs the nix-installer ostree planner ([nix-installer#1445](https://github.com/DeterminateSystems/nix-installer/issues/1445)), SELinux mislabel of `/nix` store paths ([#1383](https://github.com/DeterminateSystems/nix-installer/issues/1383), open since 2023), and `/nix` + nix-daemon disappearing after `rpm-ostree upgrade` — made the production-cost trajectory worse than pivoting before shipping. silverblue-main:43 is in the impact zone for all three.

See `.specs/features/chezmoi-home/context.md` D-01 for the full rationale, and `.specs/features/chezmoi-home/spec.md` for the replacement design (drops nix entirely; user-config layer is chezmoi + RPM-layered CLI tools).

The remainder of this file is preserved as historical reference. Do not implement against it.

---

## Problem Statement

User-level configuration on sideral is currently split across four independent systems: `/etc/skel`
dotfiles, a per-user curl-installed mise, RPM-layered shell tools, and a mise-managed preload of CLI
helpers. This is non-declarative, non-atomic, and inconsistent tool-to-tool. This feature migrates sideral
to a two-layer model — **system (RPM image layer)** and **user (nix + home-manager)** — with a single
`home.nix` as the source of truth for all user-level config. Nix is installed at first boot via the
pre-baked upstream `nix-installer` with the ostree planner; home-manager bootstraps on first login and
materializes the declared user environment. `/etc/skel` collapses to a single `home.nix` file. `mise` moves
out of the RPM layer entirely and is managed by home-manager like any other user tool.

## Goals

- [ ] Nix installed and persisted across OSTree upgrades via a pre-baked `nix-installer` + first-boot oneshot
- [ ] home-manager bootstrapped on first login via channels (no flakes); user environment materialized from a single `home.nix`
- [ ] `home.nix` is the sole source of truth for all user-level config (bash, starship, git, atuin, mise, CLI QoL)
- [ ] `mise` migrated from upstream RPM repo to nix (`home.packages`); RPM repo + user install unit removed
- [ ] `/etc/skel` reduced to a single file: `~/.config/home-manager/home.nix`
- [ ] Justfile recipes aligned with the home.nix workflow (`home-edit` / `home-apply` / `home-diff`)
- [ ] Nix CLI behaves like default NixOS (flakes off, channels-based nixpkgs, no `/etc/nix/nix.conf` override)

## Out of Scope

| Feature | Reason |
|---|---|
| Flake-based workflow + `nix-direnv` seeding | Flakes stay off (default NixOS). User enables per-user via `~/.config/nix/nix.conf` if desired. Without flakes, `nix-direnv` isn't needed. |
| Determinate Nix | Chose upstream CppNix via `NixOS/experimental-nix-installer` for portability + community alignment |
| `home-manager` NixOS module | Using standalone mode since sideral is not NixOS |
| `direnv` | User declined — no per-directory env workflow needed |
| `act`, `devenv`, `home-manager` NixOS-module mode | Available via `nix profile install` on demand |
| Per-machine `home.nix` overrides | User composes local overrides in their live `~/.config/home-manager/home.nix` |
| git identity (name/email) | Per-user; set manually after first login |

---

## User Stories

### P1: Nix ready after first boot ⭐ MVP

**Story**: Rebase any Fedora-atomic host to `sideral:latest`, reboot, wait for first-boot service to complete — `nix --version` works and `/nix` survives every subsequent `rpm-ostree upgrade`.

**Acceptance**:

1. **NXH-01** — `build.sh` fetches `nix-installer` from `github.com/NixOS/experimental-nix-installer/releases/download/<VERSION>/nix-installer-x86_64-unknown-linux-gnu` (version pinned in a single `NIX_INSTALLER_VERSION` env var at top of `build.sh`) and stages it at `/usr/libexec/nix-installer` with mode `0755`.
2. **NXH-02** — `sideral-nix-install.service` (system oneshot, `After=network-online.target ostree-remount.service`) runs on first boot and executes `/usr/libexec/nix-installer install ostree --persistence /var/lib/nix --no-confirm`.
3. **NXH-03** — Service is guarded by `ConditionPathExists=!/var/lib/sideral/nix-setup-done`; on success writes the marker; on failure the marker is absent and the service re-runs on next boot. Failures log to the system journal.
4. **NXH-04** — After install, `/nix` is a bind mount from `/var/lib/nix` (verified by `findmnt /nix` showing `/var/lib/nix` source).
5. **NXH-05** — `ExecStartPost=/usr/sbin/restorecon -Rv /nix` relabels the store after install.
6. **NXH-06** — After `rpm-ostree upgrade` + reboot, `/nix` is still present, `nix --version` still works, user-installed packages intact, `nix-daemon.service` + `nix-daemon.socket` active.
7. **NXH-07** — `/etc/nix/nix.conf` is whatever the installer writes; sideral ships no override in `system_files/`.

**Test**: Fresh VM, rebase, reboot, wait for `sideral-nix-install.service` (journalctl), `nix --version` returns installed version, `findmnt /nix` shows `/var/lib/nix` source, `systemctl status nix-daemon` is active.

---

### P1: home-manager bootstraps on first login ⭐ MVP

**Story**: A new user logs in for the first time, waits for the user-level first-login service to complete, and their shell, git, starship, atuin, and mise are all configured from a single `home.nix`.

**Acceptance**:

1. **NXH-08** — `/etc/skel/.config/home-manager/home.nix` ships the starter declarative config (contents defined in Story 3).
2. **NXH-09** — `sideral-home-manager-setup.service` (user unit, shipped at `/usr/lib/systemd/user/`) runs on first login. Guarded by `ConditionPathExists=!%h/.cache/sideral/home-manager-setup-done`; on success writes the marker; on failure the marker is absent and the service re-runs on next login. Failures log to the user journal.
3. **NXH-10** — Service adds the pinned home-manager channel (`release-24.11`), updates channels, runs `nix-shell '<home-manager>' -A install`, then `home-manager switch`.
4. **NXH-11** — After switch, user has `~/.bashrc` (home-manager-managed), `~/.config/git/config`, `~/.config/mise/config.toml`, `~/.config/atuin/config.toml`, `~/.config/starship.toml` all materialized from home.nix.

**Test**: Add a new user on a fresh sideral VM, log in, wait for service, `mise --version` works, `starship --version` works, `atuin --version` works, `git config --global --list` shows default values, `~/.bashrc` is present.

---

### P2: Single home.nix owns all user config

**Story**: All user-level bash, prompt, history, git config, and tool-manager installation is declared in one home.nix file — editing one file changes the whole user environment.

**Acceptance**:

1. **NXH-12** — home.nix declares `programs.bash.enable = true` with mise activation in `initExtra`: `if command -v mise >/dev/null 2>&1; then eval "$(mise activate bash)"; fi`.
2. **NXH-13** — home.nix declares `programs.starship.enable = true`.
3. **NXH-14** — home.nix declares `programs.git.enable = true` (name/email left unset; user fills in).
4. **NXH-15** — home.nix declares `programs.atuin.enable = true`.
5. **NXH-16** — home.nix includes `pkgs.mise` in `home.packages`.
6. **NXH-17** — Mise config inlined as `home.file.".config/mise/config.toml".text` with 12 tools: node, bun, python, java, kotlin, gradle, go, rust, zig, android-sdk, pnpm, uv. No `act`, no `atuin`, no `direnv` entries.
7. **NXH-18** — `home.username` and `home.homeDirectory` use `builtins.getEnv "USER"` and `builtins.getEnv "HOME"` so a single file works for any user.
8. **NXH-19** — `home.stateVersion = "24.11"`.

**Test**: `cat ~/.config/home-manager/home.nix` shows all 5 `programs.*.enable = true` lines and the mise config block; modifying any value + `home-manager switch` changes the running environment without a reboot.

---

### P2: /etc/skel migrated to single-file home.nix

**Story**: The image's `/etc/skel` contains only the home.nix bootstrap. No separate dotfiles are shipped at the skel layer.

**Acceptance**:

1. **NXH-20** — `/etc/skel/.bashrc` is not present. (home-manager writes `~/.bashrc` on switch.)
2. **NXH-21** — `/etc/skel/.config/mise/` is not present. (mise config is inlined in home.nix.)
3. **NXH-22** — `/etc/skel/.config/home-manager/home.nix` is present and is the sole user-facing config artifact in skel.
4. **NXH-23** — Subsequent logins (after the setup service completes once) always source the home-manager-managed `~/.bashrc`.

**Test**: On a fresh install, immediately after user creation, `ls /home/<user>/.config/home-manager/` contains only `home.nix`. After first login + setup service, `ls /home/<user>/.config/` shows `git/`, `mise/`, `atuin/`, `starship.toml`, `home-manager/`.

---

### P2: Mise moves from RPM to nix

**Story**: The image no longer ships a mise RPM, no mise-specific repo file, and no mise-install user unit. Mise arrives via home.nix like any other user tool.

**Acceptance**:

1. **NXH-24** — `build.sh` does not register `https://mise.jdx.dev/rpm/mise.repo`.
2. **NXH-25** — `system_files/etc/yum.repos.d/mise.repo` is not present.
3. **NXH-26** — `system_files/usr/lib/systemd/user/sideral-mise-install.service` is not present.
4. **NXH-27** — After `home-manager switch`, `which mise` returns `~/.nix-profile/bin/mise`.
5. **NXH-28** — `mise ls` lists the 12 declared tools as installable; `mise install` pulls declared tools into `~/.local/share/mise` on demand.

**Test**: `grep -r 'mise.jdx.dev\|sideral-mise-install' build_files/ system_files/` returns no results. `which mise` resolves to the nix profile after switch.

---

### P3: Justfile recipes track home.nix workflow

**Story**: Editing user config means editing `home/.config/home-manager/home.nix` in the repo, then applying via `just home-apply`. The old `capture-home` / `apply-home` / `diff-home` recipes are gone.

**Acceptance**:

1. **NXH-29** — `just home-edit` opens `home/.config/home-manager/home.nix` in `$EDITOR` (fallback `vi`).
2. **NXH-30** — `just home-apply` runs `home-manager switch -f home/.config/home-manager/home.nix` (or equivalent flag pointing at the repo's copy).
3. **NXH-31** — `just home-diff` runs `home-manager build -f home/.config/home-manager/home.nix` and prints the Nix-generation diff against the running activation.
4. **NXH-32** — Old Justfile recipes `capture-home`, `apply-home`, `diff-home` are removed.
5. **NXH-33** — Repo layout: `home/.config/home-manager/home.nix` is the single source; no other files under `home/`.

**Test**: `just --list` shows `home-edit`, `home-apply`, `home-diff` and does not show `capture-home` / `apply-home` / `diff-home`. Editing `home.nix`, running `just home-apply`, and verifying the change took effect with no reboot.

---

### P3: CLI quality-of-life modules (declared in home.nix)

**Story**: Common CLI quality-of-life tools (smart cd, fuzzy finder, syntax-highlighted cat, modern ls, package-to-binary lookup, GitHub CLI) are declared once in `home.nix` and activated via home-manager with their shell integration wired in automatically — no ad-hoc `nix profile install` calls, no manual shell-init snippets.

**Acceptance**:

1. **NXH-34** — `home.nix` enables `programs.zoxide.enable = true` (smart `cd` replacement; binds `z`/`zi`).
2. **NXH-35** — `home.nix` enables `programs.fzf.enable = true` (Ctrl+R / Ctrl+T / Alt+C fuzzy pickers wired in).
3. **NXH-36** — `home.nix` enables `programs.bat.enable = true` (`cat` with syntax highlighting).
4. **NXH-37** — `home.nix` enables `programs.eza.enable = true` with `icons = true` and `git = true` (modern `ls`).
5. **NXH-38** — `home.nix` enables `programs.ripgrep.enable = true` (faster `grep`).
6. **NXH-39** — `home.nix` enables `programs.nix-index.enable = true` (non-NixOS users need this for "which package provides `$cmd`"; unlocks the `comma` / `,` wrapper workflow).
7. **NXH-40** — `home.nix` enables `programs.gh.enable = true` (GitHub CLI; user runs `gh auth login` themselves on first use).

**Test**: `z <tab>` offers frecency-based dir completions, `fzf --version` works, `bat README.md` prints with syntax highlighting, `eza -la --git` works, `rg --version` works, `nix-locate bin/foo` resolves binary-to-package, `gh --version` works. All provided by `~/.nix-profile/bin/` after `home-manager switch`.

---

## Edge Cases

- **Offline at first boot** → `sideral-nix-install.service` fails, marker absent, retries on next boot. No user-facing error.
- **SELinux `default_t` bug recurs after `nix profile install`** → user runs `sudo restorecon -Rv /nix`. Documented in README; revisit if upstream fixes issue #1383.
- **composefs on silverblue-main:43** → confirmed during implementation; if composefs is enabled by default, add `rd.systemd.unit=root.transient` kernel argument note to README, or disable composefs in the image.
- **User opens shell between first login and home-manager-switch completion** → shell uses Fedora's `/etc/bashrc`; no mise/starship/atuin activation. One-time per user, <1 minute on typical network. Acceptable.
- **`home-manager switch` fails** (disk full, channel unreachable, eval error) → marker absent, retries on next login; previous generation remains active; rollback via `home-manager generations` + `switch <gen>`.
- **Fresh rpm-ostree upgrade pulls new image with updated starter home.nix** → existing users' `~/.config/home-manager/home.nix` is untouched (skel only applies at user creation). User can `git diff` against the repo's current version to see drift.
- **Multiple users** → each has their own home.nix from /etc/skel; each first-login service runs independently.

---

## Requirement Traceability

| Story | Requirement IDs | Count |
|---|---|---|
| P1: Nix ready after first boot | NXH-01 … NXH-07 | 7 |
| P1: home-manager bootstraps on first login | NXH-08 … NXH-11 | 4 |
| P2: Single home.nix owns all user config | NXH-12 … NXH-19 | 8 |
| P2: /etc/skel migrated to single-file home.nix | NXH-20 … NXH-23 | 4 |
| P2: Mise moves from RPM to nix | NXH-24 … NXH-28 | 5 |
| P3: Justfile recipes track home.nix workflow | NXH-29 … NXH-33 | 5 |
| P3: CLI quality-of-life modules | NXH-34 … NXH-40 | 7 |

**Total**: 40 testable requirements. Status values: Pending → In Tasks → Implementing → Verified.

---

## Supersedes (in parent `sideral` spec)

This feature supersedes or modifies the following requirements in `.specs/features/sideral/spec.md`:

| Old | New behavior |
|---|---|
| **ATH-17** (sideral-mise-install service installs mise via curl on first login) | Superseded by NXH-26 (unit removed) + NXH-27 (mise from nix profile) |
| **ATH-23** (mise config in `/etc/skel/.config/mise/config.toml`) | Superseded by NXH-17 + NXH-21 (inlined in home.nix, skel file removed) |
| **ATH-24** (`/etc/skel/.bashrc` activates starship + mise + atuin + direnv) | Superseded by NXH-12 … NXH-15 (home.nix) + NXH-20 (skel .bashrc removed); **direnv dropped entirely** |
| **ATH-26** (`sideral-mise-install.service` eagerly installs act + atuin + direnv) | Removed entirely — atuin now via `programs.atuin`, direnv dropped, act available via `nix profile install` |

The parent `sideral/spec.md` will be updated to reflect these changes once `nix-home` reaches Verified status.

---

## Success Criteria

- [ ] `/nix` survives `rpm-ostree upgrade` + reboot with user-installed packages intact
- [ ] New user's first login → home-manager switch completes in under 5 minutes on a typical connection
- [ ] `grep -r 'mise.jdx.dev\|sideral-mise-install\|direnv' build_files/ system_files/` returns zero matches
- [ ] Image size delta vs. current sideral is under 50 MB
- [ ] CI build remains under 15 minutes
- [ ] `just home-apply` applies a change to `home.nix` and the new config is live without reboot
