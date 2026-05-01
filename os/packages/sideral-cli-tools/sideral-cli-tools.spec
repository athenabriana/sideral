# sideral-cli-tools — meta-package pulling the day-to-day CLI tooling.
#
# No files of its own; just Requires:. Installs alongside sideral-base so
# `rpm-ostree override remove sideral-cli-tools` lets users opt out per-deployment.
#
# Tools split by source:
#   • Fedora main:           chezmoi, starship, atuin, fzf, bat, eza, ripgrep,
#                            zoxide, gh, git-lfs, gcc, make, cmake
#   • mise.jdx.dev/rpm:      mise          (persistent repo, see sideral-base)
#   • packages.microsoft.com: code         (persistent repo, see sideral-base)
#
# All 15 are dnf-installed in build.sh before the inline rpmbuild step;
# rpm -Uvh of this package then verifies they're present in the rpmdb.

Name:           sideral-cli-tools
Version:        %{?_sideral_version}%{!?_sideral_version:0.0.0}
Release:        1%{?dist}
Summary:        sideral CLI toolset (chezmoi + 13 small RPMs + mise + code)
License:        MIT
URL:            https://github.com/athenabriana/sideral
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       chezmoi
Requires:       mise
Requires:       starship
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

%description
Meta-package: depends on the 14 CLI tools sideral wires into the user
shell via /etc/profile.d/sideral-cli-init.sh, plus VS Code (`code`) for
graphical editing. Replaces the home-manager `home.packages` list that
nix-home would have shipped.

%prep
%setup -q

%files
# Intentionally empty — meta-package, no payload.

%changelog
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: meta sub-package replacing the home-manager `home.packages` list
  retired alongside `nix-home` (see chezmoi-home D-03).
