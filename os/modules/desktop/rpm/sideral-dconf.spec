# sideral-dconf — GNOME defaults

Name:           sideral-dconf
Version:        %{?_sideral_version}%{!?_sideral_version:0.0.0}
Release:        1%{?dist}
Summary:        sideral GNOME / Mutter dconf defaults
License:        MIT
URL:            https://github.com/athenabriana/sideral
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       dconf

%description
Ships sideral's captured dconf defaults under /etc/dconf/db/local.d/
plus the dconf profile that points GNOME at them.

Defaults cover: dash-to-panel layout, tiling-shell behavior, rounded-window-corners,
sloppy focus, custom keybinds (Ctrl+Alt+T, Ctrl+Shift+Esc, Super+., Super+Down),
gnome-software packaging-format preference (flatpak over rpm).

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
/etc/dconf/db/local.d/00-sideral-focus
/etc/dconf/db/local.d/00-sideral-gnome-shell
/etc/dconf/db/local.d/10-sideral-keybinds
/etc/dconf/db/local.d/20-sideral-gnome-software
/etc/dconf/profile/user

%changelog
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-2
- Add 20-sideral-gnome-software: packaging-format-preference defaults to
  flatpak over rpm in GNOME Software (paired with Bazaar→GNOME-Software swap).
* Thu Apr 23 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: focus + gnome-shell + keybinds + profile pointing at local.d
