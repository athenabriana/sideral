# chezmoi-home Specification

## Problem Statement

sideral's user-config layer was migrated to nix + home-manager via the `nix-home` feature (40 requirements, implemented locally, never VM-verified). Research surfaced three documented, still-unresolved frictions that hit Fedora atomic 42+ specifically:

1. **composefs vs the nix-installer ostree planner** — [`nix-installer#1445`](https://github.com/DeterminateSystems/nix-installer/issues/1445), [`nix#11689`](https://github.com/NixOS/nix/issues/11689). composefs makes `/` immutable; the planner can't `chattr -i /` to create `/nix`.
2. **SELinux mislabel of `/nix` store paths** — [`nix-installer#1383`](https://github.com/DeterminateSystems/nix-installer/issues/1383), open since 2023, no upstream fix as of late 2025. Recurs after every `nix profile install`.
3. **`/nix` and nix-daemon disappearing after `rpm-ostree upgrade`** — multiple Universal Blue forum reports on F42+ ([`8500`](https://universal-blue.discourse.group/t/nix-installation-is-gone-after-getting-fedora-42/8500)). Some users abandoned nix entirely.

silverblue-main:43 is in the impact zone for all three. Nix's unique value on atomic Fedora — per-user `nix profile install` for ad-hoc CLI tools — is not a workload sideral exercises heavily, and the declarative-home-config benefit is recoverable without nix.

This feature retires `nix-home` before it ships and replaces it with a chezmoi-based dotfile workflow + RPM-layered CLI tools. chezmoi is a static Go binary in Fedora's repos with no daemon, no `/nix` store, no SELinux dance, and no composefs interaction. CLI tools that lived in `home.nix` (mise, starship, atuin, fzf, bat, eza, ripgrep, zoxide, gh, git-lfs, gcc/make/cmake, vscode) move back to RPM via Fedora's repos, `mise.jdx.dev/rpm`, or `packages.microsoft.com`. Shell-init wiring (the `eval "$(starship init bash)"` snippets that home-manager's `programs.X.enable` auto-emitted) is centralized in a single `/etc/profile.d/sideral-cli-init.sh` shipped by `sideral-shell-ux`, gated on `command -v` checks.

Result: same declarative-on-first-boot UX, fewer moving parts, no nix-shaped failure modes.

## Goals

- [ ] All nix-related artifacts removed: installer binary at `/usr/libexec/nix-installer`, `sideral-nix-install.service`, `sideral-nix-relabel.{path,service}`, `sideral-home-manager-setup.service`, `/etc/distrobox/distrobox.conf` `/nix` mounts, `/etc/skel/.config/home-manager/home.nix`, and the obsolete `/etc/profile.d/sideral-hm-status.sh` home-manager bootstrap waiter
- [ ] New `sideral-cli-tools` meta sub-package with `Requires:` on 14 small Fedora-main / mise / Microsoft RPMs: chezmoi, mise, starship, atuin, fzf, bat, eza, ripgrep, zoxide, gh, git-lfs, gcc, make, cmake — plus `code`
- [ ] VS Code restored as RPM via `packages.microsoft.com/yumrepos/vscode` (restores ATH-14/15)
- [ ] mise restored as RPM via `mise.jdx.dev/rpm/` (persistent repo, same pattern as docker-ce)
- [ ] Shell-init wiring via `/etc/profile.d/sideral-cli-init.sh` in `sideral-shell-ux`
- [ ] User runs `chezmoi init --apply <repo-url>` themselves on first login (manual, not auto); README documents this
- [ ] `nix-home` feature directory archived; STATE.md notes the dropped-pre-VM rationale; ROADMAP.md adds "Nix as user-level package manager" to non-goals

## Out of Scope

| Feature | Reason |
|---|---|
| Shipping a sideral-flavored chezmoi source tree as default | User brings their own dotfiles repo; sideral provides the bootstrap path, not the contents |
| Auto-bootstrap chezmoi on first login via systemd | Avoids env-var-from-systemd chicken-and-egg; manual `chezmoi init --apply` is one command |
| Bitwarden CLI as first-class secret integration | User can layer via shell helpers (`bw get` in `~/.bash_profile.d/`) or use chezmoi's built-in `bitwarden` template func; not load-bearing for the image |
| Migrating existing nix state on already-deployed images | User-side mutable state under `/var/lib/nix` is left alone; README documents `sudo rm -rf /var/lib/nix /nix` to reclaim space |
| `nix-index` / `comma` package-discovery wrapper | `dnf provides` covers binary-to-package resolution on Fedora |
| VSCodium instead of proprietary VS Code | Remote-SSH + Remote-Containers extensions only ship on the proprietary build, which is the load-bearing dev workflow |

## User Stories

### P1: Nix layer fully removed ⭐ MVP

**Story**: A `just build` of the chezmoi-home Containerfile produces an image with zero nix artifacts. Anyone who rebases gets no nix install attempt, no `/nix` bind mount, no nix daemon.

**Acceptance**:
1. **CHM-01** — `os/build.sh` does not fetch any `nix-installer` binary. The `NIX_INSTALLER_VERSION` env var is removed.
2. **CHM-02** — Built image does not contain `/usr/libexec/nix-installer`.
3. **CHM-03** — `sideral-services` (per `os/packages/sideral-services/sideral-services.spec`) does not ship `sideral-nix-install.service`, `sideral-nix-relabel.path`, `sideral-nix-relabel.service`, or `sideral-home-manager-setup.service`. Their wants-symlinks under `multi-user.target.wants/` and `default.target.wants/` are also removed. The `.spec` is cleaned of any nix-specific `%post` / `%postun` scriptlets, `Requires:` lines, and inline comments referring to removed units — the .spec stops mentioning nix entirely.
4. **CHM-04** — `/etc/distrobox/distrobox.conf` (in `sideral-base`) does not declare auto-mounts for `/nix`, `/var/lib/nix`, or `/etc/nix`. The bashrc snippet does not source `nix-daemon.sh`.
5. **CHM-05** — `sideral-user` does not ship `/etc/skel/.config/home-manager/`. `/etc/skel/.config/home-manager/home.nix` is absent. The repo's top-level `home/` directory is removed.

**Test**: `find / -name '*nix-installer*'` returns nothing in the built image. `rpm -ql sideral-services` lists no `nix-*` unit. `rpm -qf /etc/skel/.config/home-manager/home.nix` reports no owner.

---

### P1: CLI tools available as RPMs ⭐ MVP

**Story**: All CLI tools previously declared in `home.nix` (`mise`, `starship`, `atuin`, `fzf`, `bat`, `eza`, `ripgrep`, `zoxide`, `gh`, `git-lfs`, `gcc`, `make`, `cmake`, `chezmoi`) plus VS Code are present in the built image as Fedora-style RPMs.

**Acceptance**:
1. **CHM-06** — New sub-package `sideral-cli-tools` (with spec at `os/packages/sideral-cli-tools/sideral-cli-tools.spec`). Meta-package, no files of its own. `Requires:`: `chezmoi`, `mise`, `starship`, `atuin`, `fzf`, `bat`, `eza`, `ripgrep`, `zoxide`, `gh`, `git-lfs`, `gcc`, `make`, `cmake`, `code`. Sub-package included in `os/packages/build-rpms.sh`.
2. **CHM-07** — `sideral-base.spec` `Requires:` is extended with `sideral-cli-tools` (matches the existing pattern for `sideral-flatpaks`).
3. **CHM-08** — `os/packages/sideral-base/src/etc/yum.repos.d/mise.repo` is shipped (mirrors `https://mise.jdx.dev/rpm/mise.repo`). `os/build.sh` registers it inline at build time (same persistent-repo pattern as `docker-ce.repo`) and runs `dnf5 install -y mise`. The repo file is `enabled=1` in the shipped image so `rpm-ostree upgrade` can pull mise updates.
4. **CHM-09** — `os/packages/sideral-base/src/etc/yum.repos.d/vscode.repo` is shipped (mirrors `https://packages.microsoft.com/yumrepos/vscode/config.repo` with `gpgkey=https://packages.microsoft.com/keys/microsoft.asc` and `gpgcheck=1`). `os/build.sh` registers it inline at build time (same persistent-repo pattern as `mise.repo` / `docker-ce.repo`) and runs `dnf5 install -y code`. The repo file is `enabled=1` in the shipped image so `rpm-ostree upgrade` can pull VS Code updates between rebuilds.
5. **CHM-10** — `code`, `chezmoi`, `mise`, `starship`, `atuin`, `fzf`, `bat`, `eza`, `ripgrep`, `zoxide`, `gh`, `git-lfs`, `gcc`, `make`, `cmake` are all on `$PATH` in a fresh shell after rebase. `command -v <tool>` succeeds for each.
6. **CHM-23** — Install order satisfies `sideral-cli-tools.rpm`'s `Requires:` *before* the inline-rpmbuild RUN block runs. Concrete: a new `os/features/cli/packages.txt` lists the 13 Fedora-main RPMs (`chezmoi starship atuin fzf bat eza ripgrep zoxide gh git-lfs gcc make cmake`) and `os/build.sh` runs the existing per-feature dnf install loop against it, plus the inline `dnf5 install -y mise code` from CHM-08/09. All 15 Requires-targets are present in the image at the moment `rpm -Uvh /tmp/rpmbuild/RPMS/noarch/sideral-cli-tools-*.rpm` runs in the inline-RPM RUN block. Same pattern as `bazaar` was previously satisfied (build.sh dnf-install, then rpm-build, then rpm -Uvh).

**Test**: `rpm -q sideral-cli-tools chezmoi mise starship atuin fzf bat eza ripgrep zoxide gh git-lfs gcc make cmake code` reports all installed. `rpm -qa | grep ^sideral-` lists 7 packages (sideral-base + 6 sub-packages: services, flatpaks, dconf, shell-ux, signing, cli-tools — sideral-user and sideral-selinux dropped during chezmoi-home implementation). `rpm -V sideral-cli-tools` finds no missing-dep failures.

---

### P1: Shell-init wiring shipped centrally ⭐ MVP

**Story**: A user opening a fresh bash shell on a sideral image gets starship, atuin, zoxide, mise, and fzf integrations active without editing any dotfiles — same UX as nix-home's `programs.X.enable` magic, but via a single `/etc/profile.d/` script.

**Acceptance**:
1. **CHM-11** — `sideral-shell-ux` (per `os/packages/sideral-shell-ux/sideral-shell-ux.spec`) ships `/etc/profile.d/sideral-cli-init.sh`. Each integration line is guarded by `command -v <tool> >/dev/null 2>&1` so the file is robust against any single tool being uninstalled. The integrations:
   - `eval "$(starship init bash)"`
   - `eval "$(atuin init bash --disable-up-arrow)"`
   - `eval "$(zoxide init bash --cmd cd)"` (binds `z` and overrides `cd`)
   - `eval "$(mise activate bash)"`
   - `source <(fzf --bash)` (Ctrl-R / Ctrl-T / Alt-C bindings; fzf 0.48+ pattern)
2. **CHM-12** — Mode `0644` (sourced, not executed). Idempotent: sourcing twice does not duplicate bindings.
3. **CHM-13** — `sideral-shell-ux.spec` `%files` lists `/etc/profile.d/sideral-cli-init.sh` and (per CHM-21) `/etc/profile.d/sideral-onboarding.sh`. The obsolete `/etc/profile.d/sideral-hm-status.sh` (home-manager bootstrap waiter) is **removed** from `%files` and from `packages/sideral-shell-ux/src/etc/profile.d/`. `rpm -qf /etc/profile.d/sideral-cli-init.sh` returns `sideral-shell-ux`; `rpm -qf /etc/profile.d/sideral-hm-status.sh` reports no owner.

**Test**: `bash -l -c 'type starship && type atuin && command -v z && command -v mise && (bind -p | grep -i fzf)'` succeeds and shows all integrations present.

---

### P2: README + Justfile cleanup

**Story**: All references to nix, home-manager, and the `home/` dotfiles tree are removed from the repo. README documents the chezmoi-init flow.

**Acceptance**:
1. **CHM-14** — `README.md` contains a "Set up dotfiles" section documenting `chezmoi init --apply <your-repo>` as the first-login flow. Section explains that sideral provides chezmoi but ships no default dotfiles repo.
2. **CHM-15** — `README.md` does not mention "nix", "home-manager", "/nix", or "home.nix" except in a single retrospective "Why not nix?" paragraph that links to `.specs/features/chezmoi-home/context.md` D-01.
3. **CHM-16** — `Justfile` recipes `home-edit`, `home-apply`, `home-diff` are removed. No replacement chezmoi recipes added — chezmoi is a user-level tool, not an image-build tool.
4. **CHM-17** — Repo top-level `home/` directory is removed (was: `home/.config/home-manager/home.nix`).

**Test**: `grep -ri 'home-manager\|home\.nix\|nix-installer' README.md Justfile` returns zero matches outside the explicit retrospective paragraph and any markdown link to chezmoi-home/context.md.

---

### P2: nix-home retired in tracking docs

**Story**: `.specs` cleanly reflects that `nix-home` was considered, implemented, but dropped before VM verification. Future contributors can find the rationale.

**Acceptance**:
1. **CHM-18** — `.specs/features/nix-home/spec.md` gets a "## Retired" section at the top noting: dropped 2026-05-01 in favor of `chezmoi-home`, reason links to `chezmoi-home/context.md` D-01. The feature directory is otherwise preserved as historical reference (not deleted).
2. **CHM-19** — `.specs/project/STATE.md` "Current feature" reflects `chezmoi-home`, and the previous `nix-home` "verified-pending-VM" entry is replaced with "retired pre-shipping".
3. **CHM-20** — `.specs/project/ROADMAP.md` "Current" entry switched from `nix-home` to `chezmoi-home`. The non-goals list adds "Nix as user-level package manager" with a dated rationale linking to chezmoi-home/context.md D-01.

**Test**: Reading STATE.md, ROADMAP.md, and `nix-home/spec.md` from a cold start, a contributor can answer "why isn't this image using nix?" without asking.

---

### P3: Onboarding hint on first shell

**Story**: A first-time user opens a shell and sees a one-line hint pointing them to the chezmoi-init flow, shown once per user.

**Acceptance**:
1. **CHM-21** — `sideral-shell-ux` ships `/etc/profile.d/sideral-onboarding.sh`. Gated on `[ ! -f "$HOME/.cache/sideral/onboarding-shown" ]`. On first run: prints a single line — `Tip: run \`chezmoi init --apply <your-repo>\` if you have a dotfiles repo to apply.` — then `mkdir -p "$HOME/.cache/sideral"` and `touch "$HOME/.cache/sideral/onboarding-shown"`.
2. **CHM-22** — Subsequent shells silently skip (marker exists). The hint never repeats. The script is `0644` (sourced, not executed); errors writing to `$HOME/.cache/sideral/` (e.g., read-only home) fail silently and do not abort shell startup (`mkdir -p ... 2>/dev/null || :`).

**Test**: First login on a fresh user → message appears, `~/.cache/sideral/onboarding-shown` exists. Second shell — silent.

---

## Edge Cases

- **User rebased from a `nix-home` image to `chezmoi-home`**: `/var/lib/nix` and `/nix` (mutable state under `/var`) persist across rebases. No daemon runs (units are gone). `/etc/distrobox/distrobox.conf` mounts are gone. README documents `sudo rm -rf /var/lib/nix /nix` to reclaim space. Image upgrade does not auto-purge.
- **User without a chezmoi repo**: `chezmoi` is on `$PATH` but the user never runs `init`. `/etc/profile.d/sideral-cli-init.sh` still wires shell integrations. Image works fully; dotfiles stay system defaults.
- **chezmoi source tree conflicts with `/etc/skel`-shipped files**: sideral ships nothing user-facing under `/etc/skel/.bashrc`, `/etc/skel/.config/git/`, etc. Only file under `/etc/skel/` after this feature: nothing (was: `home.nix`, now removed).
- **User's chezmoi'd dotfiles duplicate `/etc/profile.d/sideral-cli-init.sh`'s integrations**: harmless. `eval "$(starship init bash)"` twice is idempotent. Same for atuin/zoxide/mise/fzf.
- **Tool removed by user via `rpm-ostree override remove zoxide`**: `command -v` guard skips its eval line. No shell error. Other integrations continue.
- **Microsoft repo or mise repo unreachable at build time**: image build fails on the affected dnf install. Same failure mode as today's docker-ce.repo / ublue-os COPR. No regression.
- **VS Code's bundled extensions (Remote SSH, Remote Containers) absent on first launch**: user installs from marketplace once. Could be automated later via `code --install-extension` in /etc/profile.d/ but not worth the time-to-first-shell penalty.

---

## Requirement Traceability

| Story | Requirement IDs | Count |
|---|---|---|
| P1: Nix layer fully removed | CHM-01 … CHM-05 | 5 |
| P1: CLI tools as RPMs | CHM-06 … CHM-10, CHM-23 | 6 |
| P1: Shell-init wiring | CHM-11 … CHM-13 | 3 |
| P2: README + Justfile cleanup | CHM-14 … CHM-17 | 4 |
| P2: nix-home retired in tracking | CHM-18 … CHM-20 | 3 |
| P3: Onboarding hint | CHM-21 … CHM-22 | 2 |

**Total**: 23 testable requirements (vs. nix-home's 40 — roughly half the surface area). CHM-23 is appended out-of-sequence to keep CHM-11..22 stable across the 2026-05-01 review pass; numerical gap is intentional.

---

## Supersedes

This feature retires `nix-home` (`.specs/features/nix-home/`) entirely. All NXH-01..40 are superseded; the feature directory is preserved as historical reference (not deleted).

This feature also restores the following requirements from `.specs/features/sideral/spec.md` that `nix-home` had previously superseded:

| ID (sideral) | Status before this feature | Restored to |
|---|---|---|
| ATH-14 (vscode.repo file) | Removed by nix-home (vscode came from `programs.vscode`) | Restored: shipped at `/etc/yum.repos.d/vscode.repo` (CHM-09) |
| ATH-15 (vscode RPM install) | Removed by nix-home | Restored: dnf-installed `code` from Microsoft repo at build time (CHM-09) |
| ATH-17 (mise install path) | Replaced by `home.packages = [ pkgs.mise ]` | Restored as RPM via mise.jdx.dev (CHM-08), but **at image-build time**, not via first-login service |
| ATH-23 (mise config in `/etc/skel/`) | Inlined in home.nix | **Not** restored. mise config is now user-managed via chezmoi |
| ATH-24 (skel `.bashrc` activation) | Removed by nix-home | Replaced by `/etc/profile.d/sideral-cli-init.sh` in sideral-shell-ux (CHM-11). User's `~/.bashrc` is theirs alone |
| ATH-26 (sideral-mise-install.service) | Removed by nix-home | **Not** restored. Mise installs at image-build time; no first-login service needed |

---

## Success Criteria

- [ ] `just build` succeeds with the chezmoi-home Containerfile (CHM-01..10, CHM-23).
- [ ] `rpm -qa | grep ^sideral-` lists 7 packages (sideral-base + services + flatpaks + dconf + shell-ux + signing + cli-tools). sideral-user and sideral-selinux dropped during implementation.
- [ ] `bootc container lint` passes as the final RUN.
- [ ] Image size: VS Code adds ~115 MB and 14 small RPMs add ~30 MB; nix-installer (~25 MB) and /nix-related infra are removed. Net delta vs. sideral-rpms Phase R image: estimated +100 to +120 MB. Acceptable trade for dropping nix.
- [ ] Cosign signing + push to ghcr.io still succeeds (no change to ACR-27..29).
- [ ] On a fresh VM rebased to the new image: opening a shell shows starship prompt, `z` works, Ctrl-R hits atuin, `mise --version` works, `chezmoi --version` works, `code --version` works. No `/nix` directory exists. `systemctl --user list-units` shows no `sideral-home-manager-setup`. `systemctl list-units` shows no `sideral-nix-install`.
- [ ] User runs `chezmoi init --apply https://github.com/<user>/dotfiles` and their declared dotfiles materialize.
- [ ] CI build remains under 12 minutes (was 6m24s for sideral-rpms Phase R; this feature adds ~14 dnf installs but removes the nix-installer fetch).
