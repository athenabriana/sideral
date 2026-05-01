# sideral-shell-ux — first-shell bootstrap UX hook

Name:           sideral-shell-ux
Version:        %{?_sideral_version}%{!?_sideral_version:0.0.0}
Release:        1%{?dist}
Summary:        sideral interactive shell hooks (home-manager bootstrap UX)
License:        MIT
URL:            https://github.com/athenabriana/sideral
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       bash

%description
Ships /etc/profile.d/sideral-hm-status.sh — polled by every interactive
TTY shell on first login. Detects whether sideral-home-manager-setup.service
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
/etc/profile.d/sideral-hm-status.sh

%changelog
* Thu Apr 23 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: poll-and-source bootstrap UX (sideral-hm-status.sh)
