# sideral-cli-tools — meta-package pulling the day-to-day CLI tooling.
#
# No files of its own; just Requires:. Installs alongside sideral-base so
# `rpm-ostree override remove sideral-cli-tools` lets users opt out per-deployment.
#
# Tools split by source:
#   • Fedora main:           chezmoi, atuin, fzf, bat, eza, ripgrep,
#                            zoxide, gh, git-lfs, gcc, make, cmake,
#                            helix, fish
#   • mise.jdx.dev/rpm:      mise          (persistent repo, see sideral-base)
#   • packages.microsoft.com: code         (persistent repo, see sideral-base)
#   • upstream binary:       starship      (pinned tarball baked into
#                                           /usr/bin by build.sh — not RPM-tracked)
#
# The 16 RPM tools above are dnf-installed in build.sh before the inline
# rpmbuild step; rpm -Uvh of this package then verifies they're in the
# rpmdb. starship is NOT listed in Requires: because no RPM owns it.
# helix is set as $EDITOR by sideral-shell-ux's cli-init.{sh,fish} so
# git, sudoedit, mise, etc. spawn it by default. fish is the optional
# friendly-interactive-shell alternative to bash; per-user opt-in via
# `chsh -s /usr/bin/fish` after deployment (sideral-shell-ux ships
# parallel init for both shells).

Name:           sideral-cli-tools
Version:        %{?_sideral_version}%{!?_sideral_version:0.0.0}
Release:        1%{?dist}
Summary:        sideral CLI toolset (chezmoi + 14 small RPMs + mise + code; starship baked separately)
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

Meta-package: depends on the 16 RPM-packaged CLI tools sideral wires
into the user shell via /etc/profile.d/sideral-cli-init.sh and the
parallel /etc/fish/conf.d/sideral-cli-init.fish. Plus VS Code (`code`)
as the GUI editor (VISUAL), Helix (`hx`) as the default terminal
editor (EDITOR), and fish as the optional friendly-interactive-shell
alternative to bash (per-user opt-in via `chsh -s /usr/bin/fish`).
starship ships alongside as a pinned upstream binary baked into
/usr/bin (see build.sh) — outside this package's Requires: because
no RPM owns the file. Replaces the home-manager `home.packages` list
that nix-home would have shipped.

%prep
%setup -q

%files
# Intentionally empty — meta-package, no payload.

%changelog
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
