# sideral-chezmoi-defaults — image default dotfiles via chezmoi.
#
# Ships: /usr/share/sideral/chezmoi/ source tree (10 managed files in
# chezmoi source format), /etc/profile.d/sideral-chezmoi-defaults.sh
# (first-login auto-apply; fires once, guarded by marker file).
#
# Replaces: /etc/skel/ niri/noctalia/matugen seeding (sideral-niri-defaults)
# and sideral-shell-seed service (sideral-shell-ux). chezmoi can update
# existing users on image upgrade via `ujust apply-defaults`.

Name:           sideral-chezmoi-defaults
Version:        %{?_sideral_version}%{!?_sideral_version:0.0.0}
Release:        1%{?dist}
Summary:        sideral image default dotfiles via chezmoi
License:        MIT
URL:            https://github.com/athenabriana/sideral
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       chezmoi

%description
Ships sideral's default dotfile seed as a chezmoi source tree:
  - /usr/share/sideral/chezmoi/ — 10 managed files (niri config,
    Noctalia settings, matugen config + templates, bashrc, zshrc,
    nushell env.nu + config.nu, mise toolchain config)
  - /etc/profile.d/sideral-chezmoi-defaults.sh — sources on every login
    shell; applies all defaults silently on first login (--force --quiet),
    then writes a marker so subsequent logins are instant no-ops.

After `rpm-ostree upgrade`, run `ujust apply-defaults` to pull in new
defaults. Clean files update silently; customized files get a diff prompt.

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/
cp -a usr %{buildroot}/

%files
/etc/profile.d/sideral-chezmoi-defaults.sh
%dir /usr/share/sideral
%dir /usr/share/sideral/chezmoi
/usr/share/sideral/chezmoi/dot_bashrc
/usr/share/sideral/chezmoi/dot_zshrc
%dir /usr/share/sideral/chezmoi/dot_config
%dir /usr/share/sideral/chezmoi/dot_config/niri
/usr/share/sideral/chezmoi/dot_config/niri/config.kdl
/usr/share/sideral/chezmoi/dot_config/niri/noctalia.kdl
%dir /usr/share/sideral/chezmoi/dot_config/noctalia
/usr/share/sideral/chezmoi/dot_config/noctalia/settings.json
%dir /usr/share/sideral/chezmoi/dot_config/matugen
%dir /usr/share/sideral/chezmoi/dot_config/matugen/templates
/usr/share/sideral/chezmoi/dot_config/matugen/config.toml
/usr/share/sideral/chezmoi/dot_config/matugen/templates/ghostty
/usr/share/sideral/chezmoi/dot_config/matugen/templates/helix.toml
%dir /usr/share/sideral/chezmoi/dot_config/nushell
/usr/share/sideral/chezmoi/dot_config/nushell/env.nu
/usr/share/sideral/chezmoi/dot_config/nushell/config.nu
%dir /usr/share/sideral/chezmoi/dot_config/mise
/usr/share/sideral/chezmoi/dot_config/mise/config.toml

%changelog
* Sun May 04 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: ship /usr/share/sideral/chezmoi/ source tree (10 files) and
  /etc/profile.d/sideral-chezmoi-defaults.sh first-login auto-apply.
  Replaces skel + sideral-shell-seed seeding mechanisms.
