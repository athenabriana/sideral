# sideral-cli-tools — meta-package pulling the day-to-day CLI tooling.
#
# No files of its own; just Requires:. Installs alongside sideral-base so
# `rpm-ostree override remove sideral-cli-tools` lets users opt out per-deployment.
#
# Tools split by source:
#   • Fedora main:           chezmoi, atuin, fzf, bat, eza, ripgrep,
#                            zoxide, gh, git-lfs, gcc, make, cmake,
#                            helix, nushell, zsh
#   • mise.jdx.dev/rpm:      mise          (persistent repo, see sideral-base)
#   • packages.microsoft.com: code         (persistent repo, see sideral-base)
#   • upstream binary:       starship      (pinned tarball baked into
#                                           /usr/bin by build.sh — not RPM-tracked)
#                            carapace      (pinned tarball baked into
#                                           /usr/bin by build.sh — not RPM-tracked)
#
# The RPM tools above are dnf-installed in build.sh before the inline
# rpmbuild step; rpm -Uvh of this package then verifies they're in the
# rpmdb. starship and carapace are NOT listed in Requires: because no RPM
# owns them. helix is set as $EDITOR by sideral-shell-ux's cli-init.{sh,zsh}
# so git, sudoedit, mise, etc. spawn it by default. nushell + zsh are
# opt-in shells; switch via `ujust chsh {nu,zsh}` (sideral-shell-ux ships
# parallel init under /etc/profile.d/ + /etc/zsh/ + vendor autoload).

Name:           sideral-cli-tools
Version:        %{?_sideral_version}%{!?_sideral_version:0.0.0}
Release:        1%{?dist}
Summary:        sideral CLI toolset (chezmoi + 15 small RPMs + mise + code; starship baked separately)
License:        MIT
URL:            https://github.com/athenabriana/sideral
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       chezmoi
Requires:       mise
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
Requires:       code
Requires:       helix
Requires:       nushell
Requires:       zsh
Requires:       zsh-syntax-highlighting
Requires:       zsh-autosuggestions
Requires:       rclone
Requires:       fuse3

%description
Meta-package: depends on the RPM-packaged CLI tools sideral wires into
the user shell via parallel init files for bash, zsh, and nushell
(/etc/profile.d/sideral-cli-init.sh, /etc/zsh/sideral-cli-init.zsh,
/usr/share/nushell/vendor/autoload/sideral-cli-init.nu). Plus VS Code
(`code`) as the GUI editor (VISUAL), Helix (`hx`) as the default
terminal editor (EDITOR), and nushell + zsh as opt-in alternatives to
bash (per-user opt-in via `ujust chsh {nu,zsh}`). starship and carapace
ship as pinned upstream binaries baked into /usr/bin — outside this
package's Requires: because no RPM owns those files.

%prep
%setup -q

%files
# Intentionally empty — meta-package, no payload.

%changelog
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
