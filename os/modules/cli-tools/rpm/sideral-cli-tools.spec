# sideral-cli-tools — meta-package pulling the day-to-day CLI tooling.
# Also ships /etc/yum.repos.d/carapace.repo so rpm-ostree upgrade continues
# resolving carapace-bin updates on a running system.
#
# Tools split by source:
#   • Fedora 44 main:         chezmoi, atuin, fzf, bat, eza, ripgrep,
#                             zoxide, gh, git-lfs, gcc, make, cmake,
#                             helix, zsh
#   • copr:atim/nushell:      nushell
#   • mise.jdx.dev/rpm:       mise          (repo shipped via sideral-base)
#   • packages.microsoft.com: code          (repo shipped via sideral-base)
#   • repo.terra.fyralabs.com: starship     (repo shipped via sideral-niri-defaults)
#   • yum.fury.io/rsteube:    carapace-bin  (repo shipped by this package)
#
# helix is set as $EDITOR; code is VISUAL. nushell + zsh are opt-in shells
# via `ujust chsh {nu,zsh}`. All three shells wire up via parallel init
# files in sideral-shell-ux (profile.d, zsh/, nushell vendor autoload).

Name:           sideral-cli-tools
Version:        %{?_sideral_version}%{!?_sideral_version:0.0.0}
Release:        1%{?dist}
Summary:        sideral CLI toolset (chezmoi, nushell, starship, carapace-bin, mise, code + 15 Fedora RPMs)
License:        MIT
URL:            https://github.com/athenabriana/sideral
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       chezmoi
Requires:       mise
Requires:       code
Requires:       starship
Requires:       nushell
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
Requires:       helix
Requires:       zsh
Requires:       zsh-syntax-highlighting
Requires:       zsh-autosuggestions
Requires:       rclone
Requires:       fuse3

%description
Meta-package: depends on the RPM-packaged CLI tools sideral wires into
the user shell via parallel init files for bash, zsh, and nushell
(/etc/profile.d/sideral-cli-init.sh, /etc/zsh/sideral-cli-init.zsh,
/usr/share/nushell/vendor/autoload/sideral-cli-init.nu). VS Code (`code`)
is the GUI editor (VISUAL); Helix (`hx`) is the default terminal editor
(EDITOR). nushell + zsh are opt-in shells via `ujust chsh {nu,zsh}`.
Also ships /etc/yum.repos.d/carapace.repo so post-install `dnf upgrade`
keeps carapace-bin current between image rebuilds.

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/

%files
/etc/yum.repos.d/carapace.repo
/etc/yum.repos.d/nushell.repo

%changelog
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
  sideral; nushell is the third interactive shell. Switch via
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
  history). Both Fedora main, source-loaded by sideral-cli-init.zsh
  with the upstream-required ordering (autosuggestions first, syntax-
  highlighting last so it wraps every ZLE widget). No plugin manager
  needed for two source lines; oh-my-zsh / prezto / zinit remain
  user-level options on top of this.
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-5
- Add Requires: zsh as a third interactive-shell option alongside
  bash (default) and fish. Sideral ships parallel init for all three:
  /etc/profile.d/sideral-cli-init.sh + /etc/fish/conf.d/sideral-cli-
  init.fish + /etc/zsh/sideral-cli-init.zsh. Switch via the new
  `ujust chsh {bash,fish,zsh}` recipe (60-custom.just).
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-4
- Add Requires: fish. Friendly-interactive-shell alternative to bash
  with first-class syntax highlighting, autosuggestions, and smarter
  tab completion built in. Sideral ships parallel init for both
  shells (sideral-shell-ux ships sideral-cli-init.{sh,fish}); per-
  user opt-in via `chsh -s /usr/bin/fish` after deployment.
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-3
- Add Requires: helix. Pairs with /etc/profile.d/sideral-cli-init.sh
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
