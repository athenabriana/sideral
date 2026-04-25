# athens-os-services — system + user systemd units (non-flatpak)
#
# Owns: nix-install, nix-relabel (system), home-manager-setup (user)
# + their target.wants/ enablement symlinks. Flatpak install service
# is owned by athens-os-flatpaks.

Name:           athens-os-services
Version:        %{?_athens_version}%{!?_athens_version:0.0.0}
Release:        1%{?dist}
Summary:        athens-os systemd units (nix install/relabel + home-manager bootstrap)
License:        MIT
URL:            https://github.com/athenabriana/athens-os
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       systemd
Requires:       /usr/libexec/nix-installer

%description
Ships athens-os's systemd units:
  /etc/systemd/system/athens-nix-install.service     (system, first-boot)
  /etc/systemd/system/athens-nix-relabel.{service,path}  (system, on-demand)
  /usr/lib/systemd/user/athens-home-manager-setup.service (user, first-login)

Plus enablement symlinks under target.wants/ so the units fire automatically.

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc usr %{buildroot}/

%files
/etc/systemd/system/athens-nix-install.service
/etc/systemd/system/athens-nix-relabel.service
/etc/systemd/system/athens-nix-relabel.path
/etc/systemd/system/multi-user.target.wants/athens-nix-install.service
/etc/systemd/system/multi-user.target.wants/athens-nix-relabel.path
/usr/lib/systemd/user/athens-home-manager-setup.service
/usr/lib/systemd/user/default.target.wants/athens-home-manager-setup.service

%changelog
* Wed Apr 23 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: athens-nix-install + nix-relabel + home-manager-setup units
