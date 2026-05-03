# sideral-niri-defaults — niri compositor + Noctalia shell defaults.
#
# Ships: Terra yum repo, niri config (system + skel), matugen config +
# templates (system + skel), greetd config, systemd preset to enable
# greetd, fcitx5 IME profile.d snippet, Noctalia settings seed,
# wayland-sessions entry, and wallpaper placeholder README.

Name:           sideral-niri-defaults
Version:        %{?_sideral_version}%{!?_sideral_version:0.0.0}
Release:        1%{?dist}
Summary:        sideral niri compositor + Noctalia shell system defaults
License:        MIT
URL:            https://github.com/athenabriana/sideral
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       niri
Requires:       greetd
Requires:       greetd-tuigreet
Requires:       noctalia-shell
Requires:       noctalia-qs
Requires:       ghostty
Requires:       matugen
Requires:       kanshi
Requires:       swaybg
Requires:       brightnessctl
Requires:       fcitx5
Requires:       fcitx5-configtool
Requires:       grim
Requires:       slurp
Requires:       wl-clipboard
Requires:       cliphist

# Full GNOME stack conflict — sideral runs niri exclusively.
Conflicts:      gdm
Conflicts:      gnome-shell
Conflicts:      gnome-session
Conflicts:      mutter
Conflicts:      gnome-control-center
Conflicts:      gnome-settings-daemon
# SDDM replaced by greetd.
Conflicts:      sddm

%description
Ships sideral's niri compositor and Noctalia shell defaults:
  - Terra yum repo (/etc/yum.repos.d/terra.repo)
  - niri config.kdl at /etc/xdg/niri/ (system-default fallback) and
    /etc/skel/.config/niri/ (per-user seed populated on user creation)
  - matugen config + templates for ghostty + helix at both /etc/xdg/
    and /etc/skel/ layers; `ujust theme <wallpaper>` drives the pipeline
  - greetd config (/etc/greetd/config.toml) with tuigreet default login
  - systemd preset enabling greetd.service
  - IME env vars (/etc/profile.d/sideral-niri-ime.sh; fcitx5 wiring)
  - Noctalia settings seed (/etc/skel/.config/noctalia/settings.json)
  - Wayland session entry (/usr/share/wayland-sessions/niri.desktop)
  - Wallpaper placeholder README (/usr/share/wallpapers/sideral/README.md)

Conflicts: against the full GNOME stack and sddm (sideral ships niri + greetd).

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/
cp -a usr %{buildroot}/

%files
/etc/yum.repos.d/terra.repo
/etc/xdg/niri/config.kdl
%dir /etc/skel/.config/niri
/etc/skel/.config/niri/config.kdl
%dir /etc/skel/.config/noctalia
/etc/skel/.config/noctalia/settings.json
%dir /etc/skel/.config/matugen
%dir /etc/skel/.config/matugen/templates
/etc/skel/.config/matugen/config.toml
/etc/skel/.config/matugen/templates/ghostty
/etc/skel/.config/matugen/templates/helix.toml
%dir /etc/xdg/matugen
%dir /etc/xdg/matugen/templates
/etc/xdg/matugen/config.toml
/etc/xdg/matugen/templates/ghostty
/etc/xdg/matugen/templates/helix.toml
%dir /etc/greetd
/etc/greetd/config.toml
/etc/profile.d/sideral-niri-ime.sh
/usr/share/wayland-sessions/niri.desktop
/usr/lib/systemd/system-preset/50-sideral-greeter.preset
%dir /usr/share/wallpapers/sideral
/usr/share/wallpapers/sideral/README.md
/usr/share/wallpapers/sideral/default.jpg

%changelog
* Sat May 03 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Replace SDDM with greetd + tuigreet. Ship greetd config and systemd
  preset. Add Conflicts: sddm.
