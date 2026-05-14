# silverfox-cli-tools — meta-package pulling the day-to-day CLI tooling.
# Also ships /etc/yum.repos.d/carapace.repo so rpm-ostree upgrade continues
# resolving carapace-bin updates on a running system.
#
# Tools split by source:
#   • Fedora 44 main:         stow, atuin, fzf, bat, eza, ripgrep,
#                             zoxide, gh, git-lfs, gcc, make, cmake, zsh
#   • mise.jdx.dev/rpm:       mise              (repo shipped via silverfox-base)
#   • repo.terra.fyralabs.com: starship, ghostty, zed (repo shipped by this package)
#   • yum.fury.io/rsteube:    carapace-bin      (repo shipped by this package)
#
# zed is set as both $EDITOR and $VISUAL by the /etc/skel-seeded user
# .bashrc / .zshrc. bash is the default shell; zsh is reached via
# `fox chsh zsh`. User dotfiles ship via silverfox-home's /etc/skel tree
# (useradd seeds them once; user-domain thereafter).

Name:           silverfox-cli-tools
Version:        %{?_silverfox_version}%{!?_silverfox_version:0.0.0}
Release:        1%{?dist}
Summary:        silverfox CLI toolset (stow, starship, carapace-bin, mise, zed, ghostty + Fedora RPMs)
License:        MIT
URL:            https://github.com/athenabriana/silverfox
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       stow
Requires:       mise
Requires:       starship
Requires:       carapace-bin
Requires:       atuin
Requires:       fzf
Requires:       bat
Requires:       eza
Requires:       ripgrep
Requires:       zoxide
Requires:       gh
Requires:       git-lfs
Requires:       gcc
Requires:       make
Requires:       cmake
Requires:       zsh
Requires:       zsh-syntax-highlighting
Requires:       zsh-autosuggestions
Requires:       ghostty
Requires:       zed

%description
Meta-package: depends on the RPM-packaged CLI tools silverfox wires into
the user shell. Shell init lives in user-domain ~/.bashrc and ~/.zshrc
(seeded once from /etc/skel by useradd, owned by silverfox-home). Zed is
the default editor for both EDITOR and VISUAL — git, sudoedit, mise
edit, and any tool that spawns an editor opens a Zed buffer and blocks
until it closes (`zed --wait`). bash is the default login shell; zsh is
reached via `fox chsh zsh`. Also ships /etc/yum.repos.d/{carapace,terra}.repo
so post-install `dnf upgrade` keeps carapace-bin + ghostty + zed current
between image rebuilds.

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/

%files
/etc/yum.repos.d/carapace.repo
/etc/yum.repos.d/terra.repo

%changelog
* Mon May 11 2026 GitHub Actions <noreply@github.com> - 0.0.0-14
- Drop Requires: rclone + fuse3 — gdrive integration retired with the
  fox feature. Users wanting Google Drive `rpm-ostree install rclone
  fuse3` and write their own user unit (silverfox doesn't own that
  workflow anymore). Also drops the rclone-gdrive.service unit shipped
  by silverfox-shell-ux + the ujust gdrive-setup/gdrive-remove recipes.
- Add `just` to the cli-tools/packages.txt (NOT as a Requires here —
  it's a Requires of silverfox-fox, but installed in Layer 1 so
  silverfox-fox's rpm -Uvh in Layer 2 resolves its dep graph).
* Mon May 11 2026 GitHub Actions <noreply@github.com> - 0.0.0-13
- Swap editors: drop Requires: helix + code, add Requires: zed. Zed
  is the GPU-accelerated GUI editor from Terra (stable channel) and
  now serves as both $EDITOR and $VISUAL — silverfox-stow-defaults'
  bash/zsh rcs export EDITOR='zed --wait' and VISUAL='zed --wait'
  so git commit, sudoedit, mise edit, crontab -e, less's `v` key, etc.
  all open a Zed buffer and block until close. The terra.repo this
  package already ships handles `dnf upgrade` continuity for zed;
  /etc/yum.repos.d/vscode.repo retires from silverfox-base in lockstep.
* Sun May 04 2026 GitHub Actions <noreply@github.com> - 0.0.0-12
- Restore nushell via atim/nushell COPR (not in Fedora 44 main or Terra).
  Ship /etc/yum.repos.d/nushell.repo (gpg-signed COPR) so rpm-ostree
  upgrade keeps nushell current between image rebuilds.
* Sun May 04 2026 GitHub Actions <noreply@github.com> - 0.0.0-11
- Drop Requires: nushell again — not in Fedora 44 or Terra repos.
  F44 bump mistakenly re-added it; reverting to pre-0.0.0-10 state.
* Sun May 04 2026 GitHub Actions <noreply@github.com> - 0.0.0-10
- F44 bump: add Requires for nushell (Fedora 44 main), starship (Terra),
  carapace-bin (fury.io). Add Requires: code (was installed by deleted
  mise-code-install.sh). Ship /etc/yum.repos.d/carapace.repo so
  carapace-bin upgrades flow via rpm-ostree upgrade on running systems.
  Delete starship-install.sh, nushell-install.sh, carapace-install.sh,
  mise-code-install.sh (all replaced by packages.txt + dnf).
* Sun May 03 2026 GitHub Actions <noreply@github.com> - 0.0.0-9
- Drop Requires: nushell — nushell is not in Fedora main repos and is
  now installed via nushell-install.sh (upstream binary tarball baked
  into /usr/bin, same pattern as starship/carapace). No RPM owns the
  binary so Requires would never resolve. nu_plugin_* are placed in
  /usr/bin by the same script for nushell-plugins-install.sh to find.
* Sun May 03 2026 GitHub Actions <noreply@github.com> - 0.0.0-8
- Replace Requires: fish with Requires: nushell. Fish removed from
  silverfox; nushell is the third interactive shell. Switch via
  `ujust chsh nu`. carapace added as sole tab-completion backend
  for bash, zsh, and nushell (pre-built binary, see build.sh).
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-7
- Add Requires: rclone + fuse3. rclone is the CLI cloud-storage
  frontend (Google Drive, S3, B2, Dropbox, etc.); fuse3 is the
  kernel-side dependency for `rclone mount`. Powers the new
  `ujust gdrive-{init,mount,unmount}` recipes that make mounting a
  Google Drive remote at ~/gdrive a one-line operation. See
  60-custom.just for the recipe shape.
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-6
- Add Requires: zsh-syntax-highlighting + zsh-autosuggestions. Brings
  vanilla zsh to fish-parity for the two killer interactive features
  (red-on-invalid command coloring + greyed-out autosuggestions from
  history). Both Fedora main, source-loaded by silverfox-cli-init.zsh
  with the upstream-required ordering (autosuggestions first, syntax-
  highlighting last so it wraps every ZLE widget). No plugin manager
  needed for two source lines; oh-my-zsh / prezto / zinit remain
  user-level options on top of this.
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-5
- Add Requires: zsh as a third interactive-shell option alongside
  bash (default) and fish. Silverfox ships parallel init for all three:
  /etc/profile.d/silverfox-cli-init.sh + /etc/fish/conf.d/silverfox-cli-
  init.fish + /etc/zsh/silverfox-cli-init.zsh. Switch via the new
  `ujust chsh {bash,fish,zsh}` recipe (60-custom.just).
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-4
- Add Requires: fish. Friendly-interactive-shell alternative to bash
  with first-class syntax highlighting, autosuggestions, and smarter
  tab completion built in. Silverfox ships parallel init for both
  shells (silverfox-shell-ux ships silverfox-cli-init.{sh,fish}); per-
  user opt-in via `chsh -s /usr/bin/fish` after deployment.
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-3
- Add Requires: helix. Pairs with /etc/profile.d/silverfox-cli-init.sh
  exporting EDITOR=hx (and VISUAL=code split, since -4), so git,
  sudoedit, mise, less, and every other CLI tool that spawns an
  editor drops into Helix by default. VS Code (`code`) remains the
  GUI editor for project work.
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-2
- Drop Requires: starship — starship is no longer sourced from a
  Fedora RPM (atim/starship COPR retired). Now baked into /usr/bin
  as the latest upstream binary fetched at image build (see
  os/build.sh), so Requires: would not resolve. The shell-ux init
  still detects it via `command -v`.
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: meta sub-package replacing the home-manager `home.packages` list
  retired alongside `nix-home` (see chezmoi-home D-03).
