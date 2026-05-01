# sideral-services — placeholder for future system+user systemd units.
#
# Currently empty: the nix-install / nix-relabel / home-manager-setup units
# were removed alongside `nix-home` retirement (chezmoi-home CHM-03, 2026-05-01).
# The flatpak install service is owned by sideral-flatpaks, not here.
# Kept as a sub-package so future units have an obvious home and so the
# sideral-base meta-package's Requires graph stays stable.

Name:           sideral-services
Version:        %{?_sideral_version}%{!?_sideral_version:0.0.0}
Release:        1%{?dist}
Summary:        sideral systemd units (currently empty placeholder)
License:        MIT
URL:            https://github.com/athenabriana/sideral
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       systemd

%description
Placeholder sub-package for sideral system + user systemd units.
Empty after the chezmoi-home migration (2026-05-01) removed the
nix-install, nix-relabel, and home-manager-setup units.

%prep
%setup -q

%files
# Intentionally empty — see %description.

%changelog
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-2
- Remove sideral-nix-install.service, sideral-nix-relabel.{path,service},
  sideral-home-manager-setup.service and their target.wants enablement
  symlinks. Package becomes an empty placeholder for future units
  (chezmoi-home CHM-03).
* Thu Apr 23 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: sideral-nix-install + nix-relabel + home-manager-setup units
