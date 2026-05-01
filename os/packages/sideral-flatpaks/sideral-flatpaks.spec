# sideral-flatpaks — flatpak preinstall trio
#
# Self-contained: ships the manifest, the systemd service that reads it,
# and the enablement symlink. rpm-ostree override remove sideral-flatpaks
# cleanly removes the auto-install path (already-installed flatpaks at
# /var/lib/flatpak are NOT removed — that's the user's `flatpak uninstall`
# job).

Name:           sideral-flatpaks
Version:        %{?_sideral_version}%{!?_sideral_version:0.0.0}
Release:        1%{?dist}
Summary:        sideral curated flatpak set (auto-install on first boot)
License:        MIT
URL:            https://github.com/athenabriana/sideral
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       flatpak
Requires:       systemd

%description
Ships:
  /etc/flatpak-manifest                              — 8 curated refs
  /etc/systemd/system/sideral-flatpak-install.service — first-boot oneshot
  multi-user.target.wants/ enablement symlink

Refs: app.zen_browser.zen + Flatseal, Warehouse, Extension Manager,
Podman Desktop, DistroShelf, Resources, Smile.

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/

%files
/etc/flatpak-manifest
/etc/systemd/system/sideral-flatpak-install.service
/etc/systemd/system/multi-user.target.wants/sideral-flatpak-install.service

%changelog
* Thu Apr 23 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: 8-ref manifest (Zen Browser + 7 GUI apps) + flatpak-install service
