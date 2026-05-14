# chezmoi-home Tasks

Decomposition of `.specs/features/chezmoi-home/spec.md` (23 requirements). Mechanical implementation work — no new design calls (context.md already locked the 9 decisions). Order matters: repos + packages.txt must exist before build.sh references them; silverfox-cli-tools sub-package must exist before silverfox-base.spec Requires it.

## Phase 1 — Source-tree edits (no build dependency between them, can run in any order)

### T01 — Strip nix mounts from distrobox.conf · CHM-04
- **Where**: `os/packages/silverfox-base/src/etc/distrobox/distrobox.conf`
- **Done when**: file no longer declares `/nix`, `/var/lib/nix`, `/etc/nix` in `container_additional_volumes`. The bashrc/nix-daemon source-line guidance comment is removed. File still parseable by distrobox (set the variable to empty string OR remove the line + comment block entirely).
- **Gate**: `just lint` (no shell scripts touched, but lint is cheap)

### T02 — Ship vscode.repo · CHM-09
- **Where**: NEW `os/packages/silverfox-base/src/etc/yum.repos.d/vscode.repo`
- **Done when**: file mirrors `https://packages.microsoft.com/yumrepos/vscode/config.repo` with explicit `gpgkey=https://packages.microsoft.com/keys/microsoft.asc`, `gpgcheck=1`, `enabled=1`. Matches docker-ce.repo formatting (no comment header — it's a config file, not a script).
- **Gate**: file exists, parses as INI

### T03 — Ship mise.repo · CHM-08
- **Where**: NEW `os/packages/silverfox-base/src/etc/yum.repos.d/mise.repo`
- **Done when**: file mirrors `https://mise.jdx.dev/rpm/mise.repo` (`baseurl=https://mise.jdx.dev/rpm/`, `gpgcheck=1`, `gpgkey=https://mise.jdx.dev/gpg-key.pub`, `enabled=1`).
- **Gate**: file exists

### T04 — Update silverfox-base.spec %files · CHM-08, CHM-09
- **Where**: `os/packages/silverfox-base/silverfox-base.spec`
- **Done when**: `%files` lists `/etc/yum.repos.d/mise.repo` and `/etc/yum.repos.d/vscode.repo` alongside docker-ce.repo. `%description` mentions both new repos. Changelog entry appended for 2026-05-01 noting addition. (Requires for silverfox-cli-tools added later in T08.)
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

### T07 — Remove nix-related unit files from silverfox-services/src/ + clean .spec · CHM-03
- **Where**: `os/packages/silverfox-services/src/etc/systemd/system/`, `os/packages/silverfox-services/src/usr/lib/systemd/user/`, `os/packages/silverfox-services/silverfox-services.spec`
- **Done when**: 
  - Deleted: `silverfox-nix-install.service`, `silverfox-nix-relabel.path`, `silverfox-nix-relabel.service`, `silverfox-home-manager-setup.service`
  - Deleted: `multi-user.target.wants/silverfox-nix-install.service`, `multi-user.target.wants/silverfox-nix-relabel.path`, `default.target.wants/silverfox-home-manager-setup.service` (target.wants dirs may then be empty — leave them; `cp -a` is harmless)
  - `silverfox-services.spec` `%files` no longer lists removed files
  - `silverfox-services.spec` `%description`, header comment, and the file-path Requires comment block all stripped of nix references
  - `Summary:` updated (currently "nix install/relabel + home-manager bootstrap" — replace with something neutral or remove the package entirely if no files remain). **Decision**: keep the package in case future units land; current %files becomes empty placeholder OR — preferred — remove the empty sub-package entirely from `os/packages/`. Spec is silent on this. **Implementation**: keep the directory + .spec but mark the package as a placeholder for future system services; %files lists nothing (RPM allows empty package). Update `os/packages/build-rpms.sh` if it requires non-empty %files (it doesn't). Update `silverfox-base.spec` if the Requires on silverfox-services would break with empty package — it won't (an installed empty meta-package is valid).
  - Changelog entry appended noting nix-unit removal
- **Gate**: `rpm -ql` (post-build) lists no nix-* files for silverfox-services

### T08 — Create silverfox-cli-tools sub-package · CHM-06, CHM-07
- **Where**: NEW `os/packages/silverfox-cli-tools/silverfox-cli-tools.spec`, NEW empty `os/packages/silverfox-cli-tools/src/` (or no src/ — build-rpms.sh handles missing src/ gracefully per `[ -d "$src" ]` guard at line 32)
- **Done when**:
  - New .spec is a meta-package (no files of its own) with 15 `Requires:` lines: `chezmoi mise starship atuin fzf bat eza ripgrep zoxide gh git-lfs gcc make cmake code`
  - `BuildArch: noarch`, `%files` empty (just a comment), `%description` explains the package role
  - `os/packages/silverfox-base/silverfox-base.spec` adds `Requires: silverfox-cli-tools = %{version}-%{release}` alongside the other sub-package Requires lines
  - silverfox-base.spec changelog entry mentions the new sub-package
- **Gate**: `rpmbuild -bb silverfox-cli-tools.spec` (will run inside `just build`)

### T09 — Remove silverfox-user home-manager skel · CHM-05
- **Where**: `os/packages/silverfox-user/src/etc/skel/.config/home-manager/home.nix`, `os/packages/silverfox-user/silverfox-user.spec`
- **Done when**:
  - File `home.nix` deleted; empty parent dirs removed
  - `silverfox-user.spec` `%files` either empty (and the package becomes a placeholder) OR sub-package removed entirely from `os/packages/`. **Implementation**: keep as empty placeholder consistent with T07's choice, OR remove from `os/packages/` AND drop `Requires: silverfox-user` from `silverfox-base.spec`. **Pick removal** — empty package with no purpose is clutter; an empty silverfox-user existed only to hold home.nix. Spec text in CHM-05 says "silverfox-user does not ship /etc/skel/.config/home-manager/" but does not mandate keeping the package alive. **Decision**: remove the entire `os/packages/silverfox-user/` directory and drop the `Requires: silverfox-user` line from `silverfox-base.spec`. Update silverfox-base.spec changelog.
- **Gate**: `find os/packages/ -name 'home.nix'` returns nothing; `rpm -qa | grep ^silverfox-` lists no silverfox-user

### T10 — Replace silverfox-hm-status.sh with silverfox-cli-init.sh + silverfox-onboarding.sh · CHM-11, CHM-12, CHM-13, CHM-21, CHM-22
- **Where**: `os/packages/silverfox-shell-ux/src/etc/profile.d/`, `os/packages/silverfox-shell-ux/silverfox-shell-ux.spec`
- **Done when**:
  - Deleted: `silverfox-hm-status.sh`
  - NEW `silverfox-cli-init.sh` per CHM-11/12 — starship/atuin/zoxide/mise init lines guarded by `command -v`, fzf via `source <(fzf --bash)`, mode 0644, idempotent
  - NEW `silverfox-onboarding.sh` per CHM-21/22 — `[ ! -f "$HOME/.cache/silverfox/onboarding-shown" ]` gate, single-line tip, then `mkdir -p … 2>/dev/null || :` and `touch …`
  - silverfox-shell-ux.spec `%files` lists both new files, removes `silverfox-hm-status.sh`, `%description` and `Summary:` rewritten to describe the new role, changelog appended
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
  - "What's in the image" table: Editor row points at code RPM via Microsoft repo; Dev tooling row lists the 13 RPMs from silverfox-cli-tools; Nix row deleted; User environment row rewritten for chezmoi; User runtime toolchain row points at mise RPM
  - Repo layout block: `home/` line removed; `build.sh` line updated; silverfox-cli-tools added under packages/
  - "User environment — home.nix" section replaced with new "Set up dotfiles" section documenting `chezmoi init --apply <your-repo>` (CHM-14)
  - "Nix first-boot notes" + "Distrobox + nix integration" sections deleted
  - "Iterating on dotfiles" section: layer-choice text rewritten — "User-level (shell, prompt, git, mise, per-program configs) → your chezmoi'd dotfiles"
  - NEW retrospective paragraph "Why not nix?" linking to `.specs/features/chezmoi-home/context.md` D-01 — single short paragraph (CHM-15)
- **Gate**: `grep -ri 'home-manager\|home\.nix\|nix-installer' README.md` returns only the retrospective paragraph or nothing

### T13 — Update Containerfile banner · cosmetic
- **Where**: `os/Containerfile` lines 1-16
- **Done when**: banner reflects chezmoi instead of home-manager; comment about RPM layer mentions `silverfox-cli-tools`. Build comment block (line 59) updated to remove the old "container feature did docker-ce/containerd.io install" reference if irrelevant — actually it's still correct, leave it.
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
- **Done when**: `just build` exits 0; bootc lint passes; no nix-* in the final image; `rpm -qa | grep ^silverfox-` lists 8 packages (the existing 7 minus silverfox-user, plus silverfox-cli-tools)
- **Gate**: `just lint && just build`

## Notes

- Empty / removed sub-packages: T07 keeps `silverfox-services` as an empty placeholder; T09 deletes `silverfox-user` outright. Spec doesn't mandate either choice — these are implementation-time calls anchored on simplicity.
- Spec's "9 sub-packages" claim in CHM-06 test text and "Image size" estimate count `silverfox-base + 7 existing + silverfox-cli-tools = 9`. With silverfox-user removed in T09, that becomes 8. Update silverfox-base.spec changelog and STATE.md if needed (the count will drift); mention in T15 verification.
