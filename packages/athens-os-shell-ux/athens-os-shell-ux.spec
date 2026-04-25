# athens-os-shell-ux — first-shell bootstrap UX hook

Name:           athens-os-shell-ux
Version:        %{?_athens_version}%{!?_athens_version:0.0.0}
Release:        1%{?dist}
Summary:        athens-os interactive shell hooks (home-manager bootstrap UX)
License:        MIT
URL:            https://github.com/athenabriana/athens-os
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       bash

%description
Ships /etc/profile.d/athens-hm-status.sh — polled by every interactive
TTY shell on first login. Detects whether athens-home-manager-setup.service
is still running, prints a progress banner, polls the marker file every
2 s up to 5 min, then sources hm-session-vars.sh + ~/.bashrc into the
current shell so the full home-manager-managed env appears without the
user reopening their terminal.

Non-interactive shells (ssh exec, cron) and shells where the marker is
already present bail instantly.

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/

%files
/etc/profile.d/athens-hm-status.sh

%changelog
* Wed Apr 23 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: poll-and-source bootstrap UX (athens-hm-status.sh)
