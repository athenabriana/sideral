# sideral-cli-tools — meta-package pulling the day-to-day CLI tooling.
#
# No files of its own; just Requires:. Installs alongside sideral-base so
# `rpm-ostree override remove sideral-cli-tools` lets users opt out per-deployment.
#
# Tools split by source:
#   • Fedora main:           chezmoi, atuin, fzf, bat, eza, ripgrep,
#                            zoxide, gh, git-lfs, gcc, make, cmake,
#                            helix, fish, zsh
#   • mise.jdx.dev/rpm:      mise          (persistent repo, see sideral-base)
#   • packages.microsoft.com: code         (persistent repo, see sideral-base)
#   • upstream binary:       starship      (pinned tarball baked into
#                                           /usr/bin by build.sh — not RPM-tracked)
#
# The 17 RPM tools above are dnf-installed in build.sh before the inline
# rpmbuild step; rpm -Uvh of this package then verifies they're in the
# rpmdb. starship is NOT listed in Requires: because no RPM owns it.
# helix is set as $EDITOR by sideral-shell-ux's cli-init.{sh,fish,zsh}
# so git, sudoedit, mise, etc. spawn it by default. fish + zsh are
# alternative interactive shells; per-user opt-in via `ujust chsh
# {fish,zsh}` (sideral-shell-ux ships parallel init for all three
# shells under /etc/profile.d/ + /etc/fish/conf.d/ + /etc/zsh/).

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
Requires:       fish
Requires:       zsh
Requires:       zsh-syntax-highlighting
Requires:       zsh-autosuggestions

Meta-package: depends on the 17 RPM-packaged CLI tools sideral wires
into the user shell via parallel init files for bash, fish, and zsh
(/etc/profile.d/sideral-cli-init.sh, /etc/fish/conf.d/sideral-cli-
init.fish, /etc/zsh/sideral-cli-init.zsh). Plus VS Code (`code`) as
the GUI editor (VISUAL), Helix (`hx`) as the default terminal editor
(EDITOR), and fish + zsh as alternatives to the default bash login
shell (per-user opt-in via `ujust chsh {fish,zsh}`). starship ships
alongside as a pinned upstream binary baked into /usr/bin (see
build.sh) — outside this package's Requires: because no RPM owns
the file. Replaces the home-manager `home.packages` list
that nix-home would have shipped.

%prep
%setup -q

%files
# Intentionally empty — meta-package, no payload.

%changelog
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
