# sideral-services — system + user systemd units (non-flatpak)
#
# Owns: nix-install, nix-relabel (system), home-manager-setup (user)
# + their target.wants/ enablement symlinks. Flatpak install service
# is owned by sideral-flatpaks.

Name:           sideral-services
Version:        %{?_sideral_version}%{!?_sideral_version:0.0.0}
Release:        1%{?dist}
Summary:        sideral systemd units (nix install/relabel + home-manager bootstrap)
License:        MIT
URL:            https://github.com/athenabriana/sideral
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       systemd
# /usr/libexec/nix-installer is staged as a raw curl in build.sh — no package
# owns the file, so an RPM file-path Requires can never resolve. The systemd
# unit guards on ConditionPathExists at runtime instead.

%description
Ships sideral's systemd units:
  /etc/systemd/system/sideral-nix-install.service     (system, first-boot)
  /etc/systemd/system/sideral-nix-relabel.{service,path}  (system, on-demand)
  /usr/lib/systemd/user/sideral-home-manager-setup.service (user, first-login)

Plus enablement symlinks under target.wants/ so the units fire automatically.

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc usr %{buildroot}/

%files
/etc/systemd/system/sideral-nix-install.service
/etc/systemd/system/sideral-nix-relabel.service
/etc/systemd/system/sideral-nix-relabel.path
/etc/systemd/system/multi-user.target.wants/sideral-nix-install.service
/etc/systemd/system/multi-user.target.wants/sideral-nix-relabel.path
/usr/lib/systemd/user/sideral-home-manager-setup.service
/usr/lib/systemd/user/default.target.wants/sideral-home-manager-setup.service

%changelog
* Thu Apr 23 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: sideral-nix-install + nix-relabel + home-manager-setup units
