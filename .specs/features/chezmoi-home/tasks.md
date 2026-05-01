# chezmoi-home Tasks

Decomposition of `.specs/features/chezmoi-home/spec.md` (23 requirements). Mechanical implementation work — no new design calls (context.md already locked the 9 decisions). Order matters: repos + packages.txt must exist before build.sh references them; sideral-cli-tools sub-package must exist before sideral-base.spec Requires it.

## Phase 1 — Source-tree edits (no build dependency between them, can run in any order)

### T01 — Strip nix mounts from distrobox.conf · CHM-04
- **Where**: `os/packages/sideral-base/src/etc/distrobox/distrobox.conf`
- **Done when**: file no longer declares `/nix`, `/var/lib/nix`, `/etc/nix` in `container_additional_volumes`. The bashrc/nix-daemon source-line guidance comment is removed. File still parseable by distrobox (set the variable to empty string OR remove the line + comment block entirely).
- **Gate**: `just lint` (no shell scripts touched, but lint is cheap)

### T02 — Ship vscode.repo · CHM-09
- **Where**: NEW `os/packages/sideral-base/src/etc/yum.repos.d/vscode.repo`
- **Done when**: file mirrors `https://packages.microsoft.com/yumrepos/vscode/config.repo` with explicit `gpgkey=https://packages.microsoft.com/keys/microsoft.asc`, `gpgcheck=1`, `enabled=1`. Matches docker-ce.repo formatting (no comment header — it's a config file, not a script).
- **Gate**: file exists, parses as INI

### T03 — Ship mise.repo · CHM-08
- **Where**: NEW `os/packages/sideral-base/src/etc/yum.repos.d/mise.repo`
- **Done when**: file mirrors `https://mise.jdx.dev/rpm/mise.repo` (`baseurl=https://mise.jdx.dev/rpm/`, `gpgcheck=1`, `gpgkey=https://mise.jdx.dev/gpg-key.pub`, `enabled=1`).
- **Gate**: file exists

### T04 — Update sideral-base.spec %files · CHM-08, CHM-09
- **Where**: `os/packages/sideral-base/sideral-base.spec`
- **Done when**: `%files` lists `/etc/yum.repos.d/mise.repo` and `/etc/yum.repos.d/vscode.repo` alongside docker-ce.repo. `%description` mentions both new repos. Changelog entry appended for 2026-05-01 noting addition. (Requires for sideral-cli-tools added later in T08.)
- **Gate**: spec parses (visual check)

### T05 — Create os/features/cli/packages.txt · CHM-23
- **Where**: NEW `os/features/cli/packages.txt`
- **Done when**: file lists 13 Fedora-main RPMs, one per line, with comment header explaining the role: `chezmoi starship atuin fzf bat eza ripgrep zoxide gh git-lfs gcc make cmake`. Same format as `os/features/gnome/packages.txt`.
- **Gate**: file exists, no blank lines mid-list

### T06 — Add `cli` to FEATURES array + register repos in build.sh + drop nix-installer fetch · CHM-01, CHM-08, CHM-09, CHM-23
- **Where**: `os/build.sh`
- **Done when**: 
  - `NIX_INSTALLER_VERSION` and the `curl … nix-installer` block deleted
  - `FEATURES=(cli gnome container fonts gnome-extensions)` — `cli` first so its 13 RPMs install before downstream features that don't depend on them
  - After the docker-ce repo `addrepo` line: two new `addrepo` lines for `mise.repo` and `vscode.repo` (using `--from-repofile=https://mise.jdx.dev/rpm/mise.repo` and `--from-repofile=https://packages.microsoft.com/yumrepos/vscode/config.repo`)
  - One additional `dnf5 install -y --allowerasing --setopt=install_weak_deps=False mise code` line after the FEATURES loop (or inline in the cli feature — but code/mise come from non-Fedora repos so simplest is a dedicated `dnf5 install` after the loop)
  - Repo-strategy comment block updated to mention mise.repo + vscode.repo
- **Gate**: `just lint` (shellcheck passes)

### T07 — Remove nix-related unit files from sideral-services/src/ + clean .spec · CHM-03
- **Where**: `os/packages/sideral-services/src/etc/systemd/system/`, `os/packages/sideral-services/src/usr/lib/systemd/user/`, `os/packages/sideral-services/sideral-services.spec`
- **Done when**: 
  - Deleted: `sideral-nix-install.service`, `sideral-nix-relabel.path`, `sideral-nix-relabel.service`, `sideral-home-manager-setup.service`
  - Deleted: `multi-user.target.wants/sideral-nix-install.service`, `multi-user.target.wants/sideral-nix-relabel.path`, `default.target.wants/sideral-home-manager-setup.service` (target.wants dirs may then be empty — leave them; `cp -a` is harmless)
  - `sideral-services.spec` `%files` no longer lists removed files
  - `sideral-services.spec` `%description`, header comment, and the file-path Requires comment block all stripped of nix references
  - `Summary:` updated (currently "nix install/relabel + home-manager bootstrap" — replace with something neutral or remove the package entirely if no files remain). **Decision**: keep the package in case future units land; current %files becomes empty placeholder OR — preferred — remove the empty sub-package entirely from `os/packages/`. Spec is silent on this. **Implementation**: keep the directory + .spec but mark the package as a placeholder for future system services; %files lists nothing (RPM allows empty package). Update `os/packages/build-rpms.sh` if it requires non-empty %files (it doesn't). Update `sideral-base.spec` if the Requires on sideral-services would break with empty package — it won't (an installed empty meta-package is valid).
  - Changelog entry appended noting nix-unit removal
- **Gate**: `rpm -ql` (post-build) lists no nix-* files for sideral-services

### T08 — Create sideral-cli-tools sub-package · CHM-06, CHM-07
- **Where**: NEW `os/packages/sideral-cli-tools/sideral-cli-tools.spec`, NEW empty `os/packages/sideral-cli-tools/src/` (or no src/ — build-rpms.sh handles missing src/ gracefully per `[ -d "$src" ]` guard at line 32)
- **Done when**:
  - New .spec is a meta-package (no files of its own) with 15 `Requires:` lines: `chezmoi mise starship atuin fzf bat eza ripgrep zoxide gh git-lfs gcc make cmake code`
  - `BuildArch: noarch`, `%files` empty (just a comment), `%description` explains the package role
  - `os/packages/sideral-base/sideral-base.spec` adds `Requires: sideral-cli-tools = %{version}-%{release}` alongside the other sub-package Requires lines
  - sideral-base.spec changelog entry mentions the new sub-package
- **Gate**: `rpmbuild -bb sideral-cli-tools.spec` (will run inside `just build`)

### T09 — Remove sideral-user home-manager skel · CHM-05
- **Where**: `os/packages/sideral-user/src/etc/skel/.config/home-manager/home.nix`, `os/packages/sideral-user/sideral-user.spec`
- **Done when**:
  - File `home.nix` deleted; empty parent dirs removed
  - `sideral-user.spec` `%files` either empty (and the package becomes a placeholder) OR sub-package removed entirely from `os/packages/`. **Implementation**: keep as empty placeholder consistent with T07's choice, OR remove from `os/packages/` AND drop `Requires: sideral-user` from `sideral-base.spec`. **Pick removal** — empty package with no purpose is clutter; an empty sideral-user existed only to hold home.nix. Spec text in CHM-05 says "sideral-user does not ship /etc/skel/.config/home-manager/" but does not mandate keeping the package alive. **Decision**: remove the entire `os/packages/sideral-user/` directory and drop the `Requires: sideral-user` line from `sideral-base.spec`. Update sideral-base.spec changelog.
- **Gate**: `find os/packages/ -name 'home.nix'` returns nothing; `rpm -qa | grep ^sideral-` lists no sideral-user

### T10 — Replace sideral-hm-status.sh with sideral-cli-init.sh + sideral-onboarding.sh · CHM-11, CHM-12, CHM-13, CHM-21, CHM-22
- **Where**: `os/packages/sideral-shell-ux/src/etc/profile.d/`, `os/packages/sideral-shell-ux/sideral-shell-ux.spec`
- **Done when**:
  - Deleted: `sideral-hm-status.sh`
  - NEW `sideral-cli-init.sh` per CHM-11/12 — starship/atuin/zoxide/mise init lines guarded by `command -v`, fzf via `source <(fzf --bash)`, mode 0644, idempotent
  - NEW `sideral-onboarding.sh` per CHM-21/22 — `[ ! -f "$HOME/.cache/sideral/onboarding-shown" ]` gate, single-line tip, then `mkdir -p … 2>/dev/null || :` and `touch …`
  - sideral-shell-ux.spec `%files` lists both new files, removes `sideral-hm-status.sh`, `%description` and `Summary:` rewritten to describe the new role, changelog appended
- **Gate**: `just lint` passes (shellcheck on the two new .sh files)

### T11 — Justfile cleanup · CHM-16
- **Where**: `Justfile`
- **Done when**: `home-edit`, `home-apply`, `home-diff` recipes and the `home_nix` variable removed. No replacement chezmoi recipes added (chezmoi is user-level, not image-build).
- **Gate**: `just --list` runs without error

### T12 — README rewrite · CHM-14, CHM-15
- **Where**: `README.md`
- **Done when**:
  - Tagline updated (currently "Nix + home-manager, mise toolchain" — replace with chezmoi reference)
  - "Quick start" rebase paragraph rewritten ("First boot installs Nix and the flatpak set; first graphical login runs `home-manager switch`…" → describe the chezmoi flow: image is ready immediately on rebase; user runs `chezmoi init --apply <repo>` if they have a dotfiles repo)
  - "What's in the image" table: Editor row points at code RPM via Microsoft repo; Dev tooling row lists the 13 RPMs from sideral-cli-tools; Nix row deleted; User environment row rewritten for chezmoi; User runtime toolchain row points at mise RPM
  - Repo layout block: `home/` line removed; `build.sh` line updated; sideral-cli-tools added under packages/
  - "User environment — home.nix" section replaced with new "Set up dotfiles" section documenting `chezmoi init --apply <your-repo>` (CHM-14)
  - "Nix first-boot notes" + "Distrobox + nix integration" sections deleted
  - "Iterating on dotfiles" section: layer-choice text rewritten — "User-level (shell, prompt, git, mise, per-program configs) → your chezmoi'd dotfiles"
  - NEW retrospective paragraph "Why not nix?" linking to `.specs/features/chezmoi-home/context.md` D-01 — single short paragraph (CHM-15)
- **Gate**: `grep -ri 'home-manager\|home\.nix\|nix-installer' README.md` returns only the retrospective paragraph or nothing

### T13 — Update Containerfile banner · cosmetic
- **Where**: `os/Containerfile` lines 1-16
- **Done when**: banner reflects chezmoi instead of home-manager; comment about RPM layer mentions `sideral-cli-tools`. Build comment block (line 59) updated to remove the old "container feature did docker-ce/containerd.io install" reference if irrelevant — actually it's still correct, leave it.
- **Gate**: visual review

### T14 — Mark nix-home as retired in spec.md + update STATE.md + ROADMAP.md · CHM-18, CHM-19, CHM-20
- **Where**: `.specs/features/nix-home/spec.md`, `.specs/project/STATE.md`, `.specs/project/ROADMAP.md`
- **Done when**:
  - `nix-home/spec.md` gets a "## Retired" section at the top (after the title) noting drop date 2026-05-01 and linking to `chezmoi-home/context.md` D-01
  - STATE.md "Current feature" already reflects chezmoi-home — verify; "chezmoi-home implementation status" section gets a status update at the bottom (move from "pending" to "in progress"/"shipped" per actual state)
  - ROADMAP.md "Current" already lists chezmoi-home; non-goals section already mentions Nix as user-level package manager — verify both. (CHM-20 may already be complete from prior work; confirm.)
- **Gate**: `grep -l 'chezmoi-home' .specs/project/STATE.md .specs/project/ROADMAP.md` returns both

## Phase 2 — Verification

### T15 — Build verification: `just build` · CHM-01..CHM-13, CHM-23, CHM-21..22
- **Where**: full repo
- **Done when**: `just build` exits 0; bootc lint passes; no nix-* in the final image; `rpm -qa | grep ^sideral-` lists 8 packages (the existing 7 minus sideral-user, plus sideral-cli-tools)
- **Gate**: `just lint && just build`

## Notes

- Empty / removed sub-packages: T07 keeps `sideral-services` as an empty placeholder; T09 deletes `sideral-user` outright. Spec doesn't mandate either choice — these are implementation-time calls anchored on simplicity.
- Spec's "9 sub-packages" claim in CHM-06 test text and "Image size" estimate count `sideral-base + 7 existing + sideral-cli-tools = 9`. With sideral-user removed in T09, that becomes 8. Update sideral-base.spec changelog and STATE.md if needed (the count will drift); mention in T15 verification.
