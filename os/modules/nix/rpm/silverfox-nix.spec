Name:           silverfox-nix
Version:        %{?_silverfox_version}%{!?_silverfox_version:0.0.0}
Release:        1%{?dist}
Summary:        silverfox nix bootstrap — first-boot installer + sudoers
License:        MIT
URL:            https://github.com/athenabriana/silverfox
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       systemd
Requires:       curl

%description
Ships:
  /etc/systemd/system/silverfox-nix-bootstrap.service
    First-boot oneshot that runs the Determinate nix-installer
    (ostree planner with --persistence /var/lib/nix). Guarded by
    /var/lib/silverfox/nix-setup-done marker; retries on failure.

  /etc/systemd/system/multi-user.target.wants/silverfox-nix-bootstrap.service
    Enablement symlink so the service runs on first boot.

  /etc/sudoers.d/nix-sudo-env
    Adds /nix/var/nix/profiles/default/bin to sudo's secure_path so
    nix-installed commands (e.g. nh) are found when running with sudo.

Pre-downloaded at build time: nix-installer binary at /usr/libexec/.
Pre-created at build time: nixbld group (GID 30000) and users
nixbld1-32 (UIDs 30001-30032).

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/

%files
/etc/systemd/system/silverfox-nix-bootstrap.service
/etc/systemd/system/multi-user.target.wants/silverfox-nix-bootstrap.service
/etc/sudoers.d/nix-sudo-env

%changelog
* Wed May 13 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial. First-boot nix bootstrap via Determinate installer (ostree
  planner with --persistence /var/lib/nix). Pre-created nixbld users
  and /nix directory at build time for composefs compatibility.
