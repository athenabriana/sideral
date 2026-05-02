# sideral-cli-tools — meta-package pulling the day-to-day CLI tooling.
#
# No files of its own; just Requires:. Installs alongside sideral-base so
# `rpm-ostree override remove sideral-cli-tools` lets users opt out per-deployment.
#
# Tools split by source:
#   • Fedora main:           chezmoi, atuin, fzf, bat, eza, ripgrep,
#                            zoxide, gh, git-lfs, gcc, make, cmake, helix
#   • mise.jdx.dev/rpm:      mise          (persistent repo, see sideral-base)
#   • packages.microsoft.com: code         (persistent repo, see sideral-base)
#   • upstream binary:       starship      (pinned tarball baked into
#                                           /usr/bin by build.sh — not RPM-tracked)
#
# The 15 RPM tools above are dnf-installed in build.sh before the inline
# rpmbuild step; rpm -Uvh of this package then verifies they're in the
# rpmdb. starship is NOT listed in Requires: because no RPM owns it.
# helix is set as $EDITOR / $VISUAL by sideral-shell-ux's cli-init.sh
# so git, sudoedit, mise, etc. spawn it by default.

Name:           sideral-cli-tools
Version:        %{?_sideral_version}%{!?_sideral_version:0.0.0}
Release:        1%{?dist}
Summary:        sideral CLI toolset (chezmoi + 13 small RPMs + mise + code; starship baked separately)
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

%description
Meta-package: depends on the 15 RPM-packaged CLI tools sideral wires
into the user shell via /etc/profile.d/sideral-cli-init.sh, plus VS Code
(`code`) for graphical editing and Helix (`hx`) as the default
terminal editor (set via $EDITOR / $VISUAL). starship ships alongside
as a pinned upstream binary baked into /usr/bin (see build.sh) —
outside this package's Requires: because no RPM owns the file.
Replaces the home-manager `home.packages` list that nix-home would
have shipped.

%prep
%setup -q

%files
# Intentionally empty — meta-package, no payload.

%changelog
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-3
- Add Requires: helix. Pairs with /etc/profile.d/sideral-cli-init.sh
  exporting EDITOR=hx + VISUAL=hx, so git, sudoedit, mise, less, and
  every other CLI tool that spawns an editor drops into Helix by
  default. VS Code (`code`) remains the GUI editor for project work.
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-2
- Drop Requires: starship — starship is no longer sourced from a
  Fedora RPM (atim/starship COPR retired). Now baked into /usr/bin
  as the latest upstream binary fetched at image build (see
  os/build.sh), so Requires: would not resolve. The shell-ux init
  still detects it via `command -v`.
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: meta sub-package replacing the home-manager `home.packages` list
  retired alongside `nix-home` (see chezmoi-home D-03).
