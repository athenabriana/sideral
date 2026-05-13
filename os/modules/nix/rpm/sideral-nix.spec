# sideral-nix — nix bootstrap module: first-boot installer + sudoers config
#
# Ships:
#   • /etc/systemd/system/sideral-nix-bootstrap.service — first-boot oneshot
#     that runs the Determinate nix-installer with ostree planner
#   • multi-user.target.wants/ enablement symlink
#   • /etc/sudoers.d/nix-sudo-env — adds nix profile bin to sudo secure_path
#   • /etc/profile.d/sideral-nix-init.sh — auto-stow + first-login nh init
#
# The nix-installer binary is pre-downloaded at build time by
# nix-installer-download.sh (staged at /usr/libexec/nix-installer).
# nixbld users (30001-30032) are pre-created by nixbld-users.sh.
# Both run inside os/lib/build.sh as part of the nix module.
#
# The installer creates the nix-daemon service, the /nix mount unit,
# and the nix build users (skipped when pre-created). The service
# writes /var/lib/sideral/nix-setup-done on success.

Name:           sideral-nix
Version:        %{?_sideral_version}%{!?_sideral_version:0.0.0}
Release:        1%{?dist}
Summary:        sideral nix bootstrap — first-boot installer + sudoers
License:        MIT
URL:            https://github.com/athenabriana/sideral
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       systemd
Requires:       curl

%description
Ships:
  /etc/systemd/system/sideral-nix-bootstrap.service
    First-boot oneshot that runs the Determinate nix-installer
    (ostree planner with --persistence /var/lib/nix). Guarded by
    /var/lib/sideral/nix-setup-done marker; retries on failure.

  /etc/systemd/system/multi-user.target.wants/sideral-nix-bootstrap.service
    Enablement symlink so the service runs on first boot.

  /etc/sudoers.d/nix-sudo-env
    Adds /nix/var/nix/profiles/default/bin to sudo's secure_path so
    nix-installed commands (e.g. nh) are found when running with sudo.

  /etc/profile.d/sideral-nix-init.sh
    Runs `stow -R nix` on every login to keep the flake symlink in
    sync. On the very first login per user: installs nh via nix
    profile and runs `nh home switch --impure` to apply the starter
    flake. Guarded by a per-user sentinel file.

Pre-downloaded at build time: nix-installer binary at /usr/libexec/.
Pre-created at build time: nixbld group (GID 30000) and users
nixbld1-32 (UIDs 30001-30032).

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/

%files
/etc/systemd/system/sideral-nix-bootstrap.service
/etc/systemd/system/multi-user.target.wants/sideral-nix-bootstrap.service
/etc/sudoers.d/nix-sudo-env
/etc/profile.d/sideral-nix-init.sh

%changelog
* Wed May 13 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial. First-boot nix bootstrap via Determinate installer (ostree
  planner with --persistence /var/lib/nix). Pre-created nixbld users
  and /nix directory at build time for composefs compatibility.
