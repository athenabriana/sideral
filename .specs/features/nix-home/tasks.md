# nix-home Tasks

Break of `.specs/features/nix-home/spec.md` (40 requirements) + `design.md` (6 components) into
atomic, verifiable tasks. Execute in order; `[P]` marks tasks safe to run in parallel with the
preceding task because they touch disjoint file sets.

Status progression: `Pending → Implementing → Verified`.

---

## T01 — Fetch and stage `nix-installer` in `build.sh`

- **What**: Add a pinned `NIX_INSTALLER_VERSION` env var, curl the binary from
  `github.com/NixOS/experimental-nix-installer/releases/…`, install to `/usr/libexec/nix-installer`
  mode 0755.
- **Where**: `build_files/build.sh`
- **Depends on**: —
- **Reuses**: `log()` helper, `set -euo pipefail` header already in the file.
- **Done when**: New block exists near the top of `build.sh` (after `log()` definition, before COPR
  block). Variable pinned inline. `chmod 0755` applied.
- **Tests**: `just lint` passes (shellcheck clean).
- **Gate**: Quick (`just lint`).
- **Satisfies**: NXH-01, NXH-15.

## T02 — Ship `sideral-nix-install.service` (system oneshot) + enablement symlink

- **What**: New unit at `system_files/etc/systemd/system/sideral-nix-install.service` that runs
  `/usr/libexec/nix-installer install ostree --persistence /var/lib/nix --no-confirm`, then
  `restorecon -Rv /nix`, then touches `/var/lib/sideral/nix-setup-done`. Guarded by
  `ConditionPathExists=!/var/lib/sideral/nix-setup-done`. Symlink under
  `multi-user.target.wants/`.
- **Where**: `system_files/etc/systemd/system/sideral-nix-install.service`,
  `system_files/etc/systemd/system/multi-user.target.wants/sideral-nix-install.service` (relative
  symlink).
- **Depends on**: T01 (unit expects `/usr/libexec/nix-installer`).
- **Reuses**: Marker + `ConditionPathExists=!` pattern from `sideral-flatpak-install.service`.
- **Done when**: Both files present. Symlink target is `../sideral-nix-install.service`. Unit parses
  (systemd-analyze verify if available; otherwise INI parse).
- **Tests**: `just build` still succeeds (image builds with the new unit). No `bootc container lint`
  regression.
- **Gate**: Build (`just build`).
- **Satisfies**: NXH-02, NXH-03, NXH-04, NXH-05, NXH-06, NXH-07.

## T03 — Ship starter `home.nix` — the single source of truth `[P]`

- **What**: Create `home/.config/home-manager/home.nix` with the exact contents from design.md §
  Component 4 (identity via `builtins.getEnv`, `home.stateVersion = "24.11"`, `home.packages =
  [ pkgs.mise ]`, `programs.{bash,starship,atuin,git,zoxide,fzf,bat,eza,ripgrep,nix-index,gh}`
  enabled, mise config inlined via `home.file`).
- **Where**: `home/.config/home-manager/home.nix` (new).
- **Depends on**: —
- **Reuses**: Mise toolchain block ported from the current `home/.config/mise/config.toml`, minus
  `act`, `atuin`, `direnv` entries (per D-08, D-09, D-10).
- **Done when**: File exists. All NXH-12..NXH-19 + NXH-34..NXH-40 lines grep-matchable. No trailing
  syntax errors when parsed with `nix-instantiate --parse` (if available).
- **Tests**: `just build` still succeeds (the file flows through existing `COPY home /etc/skel`).
- **Gate**: Build (`just build`).
- **Satisfies**: NXH-12..NXH-19, NXH-34..NXH-40.

## T04 — Ship `sideral-home-manager-setup.service` (user oneshot) + enablement symlink

- **What**: New user unit at
  `system_files/usr/lib/systemd/user/sideral-home-manager-setup.service` that: sources nix profile,
  adds `release-24.11` home-manager channel, runs `nix-channel --update`, `nix-shell
  '<home-manager>' -A install`, `home-manager switch`, then touches
  `%h/.cache/sideral/home-manager-setup-done`. Dual `ConditionPathExists`: `!marker` and
  `/nix/var/nix/profiles/default/bin/nix`. Symlink under `default.target.wants/`.
- **Where**: `system_files/usr/lib/systemd/user/sideral-home-manager-setup.service`,
  `system_files/usr/lib/systemd/user/default.target.wants/sideral-home-manager-setup.service`.
- **Depends on**: T02 (nix must install before this runs — enforced at runtime by the second
  `ConditionPathExists`), T03 (skel-seeded `home.nix` must exist on new user creation).
- **Reuses**: Per-user marker + `WantedBy=default.target` pattern from
  `sideral-vscode-setup.service`.
- **Done when**: Both files present. Unit parses. `TimeoutStartSec=900`. `set -e` wraps the
  ExecStart shell block.
- **Tests**: `just build` succeeds.
- **Gate**: Build (`just build`).
- **Satisfies**: NXH-08, NXH-09, NXH-10, NXH-11.

## T05 — Remove legacy user dotfiles from `home/` `[P]`

- **What**: Delete `home/.bashrc` and `home/.config/mise/config.toml`. Remove empty parent
  `home/.config/mise/` directory. Leave `home/.config/` in place (it will contain
  `home-manager/home.nix` from T03).
- **Where**: repo root.
- **Depends on**: T03 (home.nix inlines the mise config; removal is safe after T03 lands).
- **Reuses**: —
- **Done when**: `ls home/` shows only `.config/home-manager/`. No stale dotfiles in skel.
- **Tests**: `just build` succeeds with `/etc/skel` now holding only `.config/home-manager/home.nix`.
- **Gate**: Build.
- **Satisfies**: NXH-20, NXH-21, NXH-22, NXH-23.

## T06 — Remove `sideral-mise-install.service` and its symlink `[P]`

- **What**: Delete `system_files/usr/lib/systemd/user/sideral-mise-install.service` and
  `system_files/usr/lib/systemd/user/default.target.wants/sideral-mise-install.service`.
- **Where**: repo.
- **Depends on**: T04 (new user unit supersedes this one).
- **Reuses**: —
- **Done when**: Neither file exists. `grep -r 'sideral-mise-install' system_files/ build_files/`
  returns nothing.
- **Tests**: `just build` succeeds.
- **Gate**: Build.
- **Satisfies**: NXH-24, NXH-25, NXH-26 (NXH-24/25 covered by "never introduced"; confirm by grep).

## T07 — Justfile: replace `apply-home`/`capture-home`/`diff-home` with `home-*` recipes

- **What**: Remove the three rsync-based recipes (lines 44-55 in current Justfile). Add
  `home-edit`, `home-apply`, `home-diff` recipes from design.md § Component 5.
- **Where**: `Justfile`.
- **Depends on**: T03 (recipes target `home/.config/home-manager/home.nix`).
- **Reuses**: Existing Just recipe style + comment conventions.
- **Done when**: `just --list` shows `home-edit`, `home-apply`, `home-diff` and does NOT show
  `apply-home`, `capture-home`, `diff-home`.
- **Tests**: `just --list` parses cleanly (no Just syntax errors).
- **Gate**: None (text-only per TESTING.md matrix); `just --list` is the implicit check.
- **Satisfies**: NXH-29, NXH-30, NXH-31, NXH-32, NXH-33.

## T08 — README: document nix-home first-boot + first-login flow

- **What**: Add a section to `README.md` covering (a) the first-boot `sideral-nix-install.service`
  behavior and journalctl location, (b) first-login `sideral-home-manager-setup.service`, (c)
  editing `home.nix` + `just home-apply` workflow, (d) SELinux `restorecon -Rv /nix` note for
  post-install batches, (e) composefs karg note if confirmed as a blocker during implementation.
- **Where**: `README.md`.
- **Depends on**: T01-T07 (doc describes the shipped behavior).
- **Reuses**: Existing README style.
- **Done when**: Section present; no broken existing links; mentions all four above bullets.
- **Tests**: Markdown renders (manual skim).
- **Gate**: None (text-only).
- **Satisfies**: Spec edge cases § SELinux, composefs; Success Criteria support.

## T09 — Final gate: `just lint` + `just build`

- **What**: Run `just lint` and `just build` after all prior tasks ship. Verify `bootc container
  lint` passes.
- **Where**: CLI.
- **Depends on**: T01-T08.
- **Reuses**: —
- **Done when**: Both commands exit 0. No new warnings from bootc lint.
- **Tests**: The gate commands themselves.
- **Gate**: Build (by definition).
- **Satisfies**: Success Criteria (CI build remains under 15 min; image size delta < 50 MB — image
  size measured separately if needed).

---

## Requirement → Task Traceability

| Req | Task | Status |
|---|---|---|
| NXH-01, NXH-15 | T01 | Implemented (version 2.34.5; SPEC-DEV-01 below) |
| NXH-02..NXH-07 | T02 | Implemented (build gate deferred to CI) |
| NXH-08..NXH-11 | T04 | Implemented (build gate deferred to CI) |
| NXH-12..NXH-19 | T03 | Implemented (all 16 grep patterns confirmed) |
| NXH-20..NXH-23 | T05 | Implemented |
| NXH-24..NXH-26 | T06 | Implemented (grep sweep = 0 hits) |
| NXH-27..NXH-28 | T03 + T04 | Verified-pending-VM |
| NXH-29..NXH-33 | T07 | Implemented |
| NXH-34..NXH-40 | T03 | Implemented |

Some acceptance criteria (NXH-06 `rpm-ostree upgrade` survival, NXH-27 `which mise`, NXH-28 `mise
install` workflow) can only be verified on a rebased host. Mark those "Verified-pending-VM" once CI
`just build` passes and a local/remote rebase is done.

## SPEC_DEVIATION

- **SPEC-DEV-01** (NXH-01 URL/asset text): spec says fetch from
  `github.com/NixOS/experimental-nix-installer/releases/download/<VERSION>/nix-installer-x86_64-unknown-linux-gnu`.
  Upstream was renamed to `NixOS/nix-installer` and the x86_64 Linux asset is
  `nix-installer-x86_64-linux` (no `-unknown-linux-gnu` suffix). Implementation uses the canonical
  `github.com/NixOS/nix-installer/releases/download/2.34.5/nix-installer-x86_64-linux` URL. The D-01
  intent ("upstream CppNix installer with ostree planner") is preserved — the `experimental-`
  prefix was dropped by the NixOS org when the installer stopped being experimental. Spec.md
  NXH-01 language should be updated to reflect the new repo/asset names when the feature is
  promoted to Verified.
