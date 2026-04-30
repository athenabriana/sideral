# athens-os-dconf — GNOME defaults

Name:           athens-os-dconf
Version:        %{?_athens_version}%{!?_athens_version:0.0.0}
Release:        1%{?dist}
Summary:        athens-os GNOME / Mutter dconf defaults
License:        MIT
URL:            https://github.com/athenabriana/athens-os
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       dconf

%description
Ships athens-os's captured dconf defaults under /etc/dconf/db/local.d/
plus the dconf profile that points GNOME at them.

Defaults cover: dash-to-panel layout, tiling-shell behavior, rounded-window-corners,
sloppy focus, custom keybinds (Ctrl+Alt+T, Ctrl+Shift+Esc, Super+., Super+Down).

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/

%post
dconf update >/dev/null 2>&1 || :

%postun
dconf update >/dev/null 2>&1 || :

%files
/etc/dconf/db/local.d/00-athens-focus
/etc/dconf/db/local.d/00-athens-gnome-shell
/etc/dconf/db/local.d/10-athens-keybinds
/etc/dconf/profile/user

%changelog
* Thu Apr 23 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: focus + gnome-shell + keybinds + profile pointing at local.d
