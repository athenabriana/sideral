# nix-home — Locked Decisions

Decisions recorded during `/spec-create`. Each entry notes what was chosen, what was considered, and
why this path was picked. Reference the decision ID in commits/PRs when revisiting.

---

## D-01 · Nix distribution: upstream CppNix via `experimental-nix-installer`

**Chose**: [`NixOS/experimental-nix-installer`](https://github.com/NixOS/experimental-nix-installer) (community-maintained upstream installer with the `ostree` planner).

**Considered**:
- Determinate Nix via `DeterminateSystems/nix-installer` — becomes the default from Jan 2026 when the `--prefer-upstream-nix` flag is removed.
- Fedora `nix` RPM (layered via dnf) — RPM creates `/nix` at root, fights OSTree immutability.
- Lix installer — no ostree planner, not viable on atomic Fedora.

**Why**:
- Broader ecosystem alignment — NixOS Discourse, r/NixOS, nix.dev, every tutorial assume upstream CppNix.
- No vendor lock-in; Determinate is a commercial entity and their fork's roadmap may drift.
- Portability optionality if the user ever moves to NixOS or nix-darwin.
- Same `ostree` planner code (upstream forked cleanly from Determinate's installer), so OSTree support quality is equivalent.
- Since we bake a pinned binary in the image, Determinate's 2026 default-shift doesn't affect us either way.

---

## D-02 · No `/etc/nix/nix.conf` shipped — default NixOS behavior

**Chose**: Do not ship a custom `/etc/nix/nix.conf`. Let `experimental-nix-installer` write its defaults.

**Considered**:
- Seed `experimental-features = nix-command flakes` globally so flakes work out of the box.
- Ship a commented-out template for discoverability.

**Why**:
- User's stated preference: "nix CLI should behave like default NixOS."
- Flakes are still technically experimental; enabling them globally puts sideral ahead of upstream NixOS defaults.
- Users who want flakes add one line to `~/.config/nix/nix.conf` — reversible, discoverable, per-user.
- Classic CLI (`nix-env`, `nix-shell`, `nix-channel`) works without any config.

---

## D-03 · `/nix` persistence via `/var/lib/nix` bind mount

**Chose**: `nix-installer install ostree --persistence /var/lib/nix` — installer handles the bind mount, `nix.mount` unit, daemon unit overrides.

**Considered**:
- Manual `tmpfiles.d` rule (`L /nix - - - - /var/lib/nix`) + hand-rolled `nix.mount` unit — reimplements the installer.
- Fedora RPM + custom unit — requires SELinux + composefs workarounds we'd have to maintain.

**Why**:
- The `ostree` planner is the only battle-tested code path for this problem.
- `/var` is persistent + mutable on OSTree, so `/nix` survives upgrades and rebases for free.
- No bespoke systemd engineering needed on our side.

---

## D-04 · SELinux handling: `restorecon` as `ExecStartPost`

**Chose**: `ExecStartPost=/usr/sbin/restorecon -Rv /nix` after installer completes.

**Considered**:
- Custom `.pp` SELinux policy module shipped in the image (robust but requires policy-authoring expertise).
- Defer entirely — let user discover and workaround (bad UX).

**Why**:
- Simplest fix for [issue #1383](https://github.com/DeterminateSystems/nix-installer/issues/1383) (`/nix` store paths land as `default_t`).
- Works for the initial install. User may need to re-run `restorecon -Rv /nix` after large `nix profile install` batches until upstream fixes it — documented in README.
- Revisit if the workaround proves insufficient in practice.

---

## D-05 · First-boot failure mode: idempotent retry via marker file

**Chose**: Marker file at `/var/lib/sideral/nix-setup-done`; unit runs while the marker is absent.

**Considered**: Fail loudly once; require manual `systemctl start` to retry.

**Why**:
- Matches the existing `sideral-flatpak-install` and former `sideral-mise-install` patterns.
- Survives offline first boot, transient failures, VMs created without network.
- User friendly: boot again tomorrow, problem fixes itself.

---

## D-06 · home-manager install path: channels, not flakes

**Chose**: `nix-channel --add https://github.com/nix-community/home-manager/archive/release-24.11.tar.gz home-manager` + `nix-shell '<home-manager>' -A install` + `home-manager switch`.

**Considered**: Flakes-based install (`home-manager switch --flake .#user`).

**Why**:
- Consistent with D-02 (default NixOS behavior = channels).
- Works without enabling experimental features.
- release-24.11 is the current stable channel; pinned in the install script.

---

## D-07 · mise: move from RPM to nix via home.packages

**Chose**: `home.packages = [ pkgs.mise ]` in home.nix. No RPM, no repo file, no user unit.

**Considered**: Keep `mise.jdx.dev/rpm/` repo + system-layered `/usr/bin/mise`.

**Why**:
- With home-manager as the source of user-level config, splitting tooling between RPM + home.nix was arbitrary.
- One lifecycle (home-manager switch) owns everything.
- First-shell-before-switch degradation is acceptable (one-time, <1 min).
- mise still has its role: per-project `.nvmrc` / `.python-version` / `.mise.toml` detection in projects without flakes.

---

## D-08 · `direnv` dropped entirely

**Chose**: Remove `direnv` from all layers (RPM, mise, home.nix).

**Considered**: Ship via Fedora RPM; enable via `programs.direnv` in home.nix; seed `nix-direnv` alongside.

**Why**:
- User declined — no per-directory env workflow currently in use.
- Without `direnv`, nix dev shells require manual `nix develop` (acceptable).
- Removing simplifies the spec.
- User can add later as a minor home.nix edit if needs change.

---

## D-09 · `atuin` stays, managed by home-manager

**Chose**: `programs.atuin.enable = true` in home.nix.

**Considered**: Drop entirely (user initially said "idk what they do" about atuin + direnv).

**Why**:
- After explanation, user opted to keep atuin (shell history upgrade, Ctrl+R fuzzy search).
- home-manager's `programs.atuin` handles install + shell integration + config cleanly.

---

## D-10 · `act` dropped from preload

**Chose**: Remove from mise config; install on-demand via `nix profile install nixpkgs#act`.

**Why**:
- Rare use — not worth preloading.
- Clean example of the "ad-hoc CLI tools go through nix" pattern.

---

## D-11 · Host-only — drop "host + distrobox" invariant

**Chose**: mise and nix are both host-only. Distrobox containers install their own tooling if needed.

**Considered**: Vendor mise binary in image, copy to `~/.local/bin/` at first boot so shared `$HOME` carries it into distroboxes.

**Why**:
- Distrobox's value is isolation; host tooling leaking in erodes that.
- `distrobox-host-exec` handles the "run host binary from container" case.
- Flakes (+ nix-direnv, when user opts in) subsume the "same env everywhere" use case more cleanly than distrobox + mise sharing.
- The prior ATH-24 wording "host + distrobox" was a default, not a load-bearing requirement.

---

## D-12 · Full skel migration — `home.nix` is the sole skel artifact

**Chose**: `/etc/skel/.config/home-manager/home.nix` is the only user-level file shipped in skel. No `.bashrc`, no separate mise config.

**Considered**: Keep a minimal bootstrap `.bashrc` that sources `hm-session-vars.sh` as a fallback.

**Why**:
- Fedora's `/etc/bashrc` + `/etc/profile` provide baseline system defaults.
- Between first login and home-manager switch completion, the shell uses Fedora defaults (acceptable, <1 min).
- One file = one source of truth. No drift between skel and home.nix.

---

## D-13 · home-manager scope: include with full starter home.nix

**Chose**: Ship a fully declarative starter `home.nix` with bash/initExtra + starship + git + atuin + mise + mise-config-inlined.

**Considered**: Minimal starter (empty home.packages, no programs.* modules) → user fills in; defer home-manager entirely to a follow-up feature.

**Why**:
- User's explicit choice after understanding what home-manager provides.
- Provides immediate value — rebase + first login = full environment.
- Starter is the migration target for current `/etc/skel` content, not net-new surface.

---

## D-14 · `home.username` / `home.homeDirectory` via `builtins.getEnv`

**Chose**: `home.username = builtins.getEnv "USER";` and `home.homeDirectory = builtins.getEnv "HOME";`.

**Considered**: Ship placeholder (`CHANGEME`), `sed` at first-boot service.

**Why**:
- Clean — no string munging in systemd units.
- Same home.nix works for any user without modification.
- `builtins.getEnv` resolves at home-manager switch time, so the value is always correct for the invoking user.

---

## D-15 · Version pinning: inline env vars in `build.sh`

**Chose**: `NIX_INSTALLER_VERSION` and `HOME_MANAGER_CHANNEL` pinned at the top of `build.sh` (or the script that installs them).

**Considered**: Separate `VERSIONS.env` file sourced by build.sh.

**Why**:
- Only one or two pins to manage.
- Simpler than an extra file.
- Dependabot can bump via `# dependabot` comments if needed later.

---

## Open implementation concerns (not blocking spec)

- **Composefs state on `silverblue-main:43`** — confirm during implementation. If composefs is on by default (F42+), add `rd.systemd.unit=root.transient` karg instruction to README, or consider disabling composefs in the image. Tracked under NXH-04/06 implementation.
- **Determinate Nix SELinux fix upstream** — monitor [issue #1383](https://github.com/DeterminateSystems/nix-installer/issues/1383); if fixed, remove `restorecon` step.
- **home-manager channels deprecation signals** — channels-based install may become deprecated in favor of flakes in future home-manager releases. Revisit D-06 if that happens.
- **First-shell UX** — if the "between first login and home-manager switch" degradation feels worse than expected in real use, consider a tiny bootstrap `.bashrc` in skel purely to source `hm-session-vars.sh` when it appears.
