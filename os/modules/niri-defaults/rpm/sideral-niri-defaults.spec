# sideral-niri-defaults — niri compositor + Noctalia shell defaults.
#
# Ships: Terra yum repo, niri config (system XDG fallback), matugen
# config + templates (system XDG fallback), SDDM config + SilentSDDM
# theme (vendored), systemd preset to enable sddm, fcitx5 IME profile.d
# snippet, wayland-sessions entry, and wallpaper placeholder.
# Per-user seeding is handled by sideral-chezmoi-defaults.

Name:           sideral-niri-defaults
Version:        %{?_sideral_version}%{!?_sideral_version:0.0.0}
Release:        1%{?dist}
Summary:        sideral niri compositor + Noctalia shell system defaults
License:        MIT
URL:            https://github.com/athenabriana/sideral
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       niri
Requires:       sddm
Requires:       sddm-wayland-generic
Requires:       noctalia-shell
Requires:       noctalia-qs
Requires:       ghostty
Requires:       matugen
Requires:       kanshi
Requires:       wdisplays
Requires:       ddcutil
Requires:       fastfetch
Requires:       wlsunset
Requires:       fprintd
Requires:       brightnessctl
Requires:       fcitx5
Requires:       fcitx5-configtool
Requires:       kanata
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
# Other display managers — SDDM is the active one.
Conflicts:      greetd
Conflicts:      lightdm

%description
Ships sideral's niri compositor and Noctalia shell defaults:
  - Terra yum repo (/etc/yum.repos.d/terra.repo)
  - niri config.kdl at /etc/xdg/niri/ (system-default fallback); config.d/
    placeholder shipped so the explicit include works on niri <26.04
  - matugen config + templates for ghostty + helix at /etc/xdg/;
    `ujust theme <wallpaper>` drives the pipeline
  - SDDM config (/etc/sddm.conf.d/sideral.conf) selecting the SilentSDDM
    theme (vendored at /usr/share/sddm/themes/silent/, v1.4.2)
  - systemd preset enabling sddm.service
  - kanata config + service for Super tap-vs-hold (tap → Mod+Space
    launcher trigger, hold → normal Super modifier)
  - IME env vars (/etc/profile.d/sideral-niri-ime.sh; fcitx5 wiring)
  - Wayland session entry (/usr/share/wayland-sessions/niri.desktop)
  - Wallpaper placeholder (/usr/share/wallpapers/sideral/)

Per-user dotfile seeding (niri, Noctalia, matugen) is handled by
sideral-chezmoi-defaults via /etc/profile.d/sideral-chezmoi-defaults.sh.

Conflicts: against the full GNOME stack and other DMs (greetd, lightdm).

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/
cp -a usr %{buildroot}/

%files
/etc/yum.repos.d/terra.repo
/etc/xdg/niri/config.kdl
%dir /etc/xdg/niri/config.d
/etc/xdg/niri/config.d/sideral-nvidia.kdl
%dir /etc/xdg/matugen
%dir /etc/xdg/matugen/templates
/etc/xdg/matugen/config.toml
/etc/xdg/matugen/templates/ghostty
/etc/xdg/matugen/templates/helix.toml
%dir /etc/sddm.conf.d
/etc/sddm.conf.d/sideral.conf
%dir /etc/kanata
/etc/kanata/sideral.kbd
/etc/profile.d/sideral-niri-ime.sh
/usr/share/wayland-sessions/niri.desktop
%dir /usr/share/sddm/themes/silent
/usr/share/sddm/themes/silent/*
/usr/lib/systemd/system/sideral-kanata.service
/usr/lib/systemd/system-preset/50-sideral-greeter.preset
/usr/lib/systemd/system-preset/51-sideral-kanata.preset
%dir /usr/share/wallpapers/sideral
/usr/share/wallpapers/sideral/README.md
/usr/share/wallpapers/sideral/default.jpg

%changelog
* Sat May 03 2026 GitHub Actions <noreply@github.com> - 0.0.0-2
- Swap greetd + tuigreet → SDDM + SilentSDDM (vendored v1.4.2). Drop
  greetd config + greeter sysusers; ship /etc/sddm.conf.d/sideral.conf
  selecting the silent theme. Conflicts: greetd, lightdm; remove sddm
  from Conflicts.
* Sat May 03 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Replace SDDM with greetd + tuigreet. Ship greetd config and systemd
  preset. Add Conflicts: sddm.
- Fix niri include: glob syntax requires niri >=26.04 (not yet in Fedora 43);
  switch to explicit include of sideral-nvidia.kdl; ship placeholder in
  config.d/ so the include resolves on open-source variant too.
