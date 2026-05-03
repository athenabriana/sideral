# sideral-niri-defaults — niri compositor + Noctalia shell defaults.
#
# Ships: Terra yum repo, niri config (system + skel), matugen config +
# templates (system + skel), SDDM theme selection, fcitx5 IME profile.d
# snippet, Noctalia settings seed, wayland-sessions entry, and wallpaper
# placeholder README.
#
# sddm-silent-install.sh (run at image build by the orchestrator) fetches
# and extracts SilentSDDM to /usr/share/sddm/themes/silent/ — those
# files are NOT in this spec's %files since they come from an upstream
# tarball, not src/.

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
Requires:       noctalia-shell
Requires:       noctalia-qs
Requires:       ghostty
Requires:       matugen
Requires:       kanshi
Requires:       fcitx5
Requires:       fcitx5-configtool
Requires:       grim
Requires:       slurp
Requires:       wl-clipboard
Requires:       cliphist

# Full GNOME stack conflict — sideral runs niri exclusively.
# The Containerfile's prune step removes these before the inline RPM
# install; Conflicts: ensures no accidental re-introduction via a
# future dependency chain.
Conflicts:      gdm
Conflicts:      gnome-shell
Conflicts:      gnome-session
Conflicts:      mutter
Conflicts:      gnome-control-center
Conflicts:      gnome-settings-daemon

%description
Ships sideral's niri compositor and Noctalia shell defaults:
  - Terra yum repo (/etc/yum.repos.d/terra.repo)
  - niri config.kdl at /etc/xdg/niri/ (system-default fallback) and
    /etc/skel/.config/niri/ (per-user seed populated on user creation)
  - matugen config + templates for ghostty + helix at both /etc/xdg/
    and /etc/skel/ layers; `ujust theme <wallpaper>` drives the pipeline
  - SDDM theme selection (/etc/sddm.conf.d/sideral-silent.conf)
  - IME env vars (/etc/profile.d/sideral-niri-ime.sh; fcitx5 wiring)
  - Noctalia settings seed (/etc/skel/.config/noctalia/settings.json)
  - Wayland session entry (/usr/share/wayland-sessions/niri.desktop)
  - Wallpaper placeholder README (/usr/share/wallpapers/sideral/README.md)

Conflicts: against the full GNOME stack (sideral ships niri exclusively).

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
/etc/sddm.conf.d/sideral-silent.conf
/etc/profile.d/sideral-niri-ime.sh
/usr/share/wayland-sessions/niri.desktop
%dir /usr/share/wallpapers/sideral
/usr/share/wallpapers/sideral/README.md
/usr/share/wallpapers/sideral/default.jpg

%changelog
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: niri compositor + Noctalia shell defaults. Ships Terra repo,
  niri config (system + skel), matugen config + templates (system +
  skel), SDDM silent-theme selection, fcitx5 IME profile.d snippet,
  Noctalia settings.json seed, wayland-sessions entry, and wallpaper
  placeholder README. Conflicts: full GNOME stack (gdm, gnome-shell,
  gnome-session, mutter, gnome-control-center, gnome-settings-daemon).
