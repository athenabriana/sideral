# sideral-shell-ux — interactive-shell hooks (CLI init wiring + onboarding tip)

Name:           sideral-shell-ux
Version:        %{?_sideral_version}%{!?_sideral_version:0.0.0}
Release:        1%{?dist}
Summary:        sideral shell-init wiring + chezmoi onboarding hint
License:        MIT
URL:            https://github.com/athenabriana/sideral
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       bash

%description
Ships two /etc/profile.d/ snippets:

  sideral-cli-init.sh   — central shell-init wiring for starship, atuin,
                          zoxide, mise, and fzf. Each integration is
                          `command -v`-guarded so removing any single tool
                          via `rpm-ostree override remove` doesn't break
                          the rest. Replaces home-manager's declarative
                          `programs.X.enable` wiring.

  sideral-onboarding.sh — one-shot chezmoi init hint shown on the first
                          interactive shell per user. Subsequent shells
                          stay silent (marker at ~/.cache/sideral/).

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/

%files
/etc/profile.d/sideral-cli-init.sh
/etc/profile.d/sideral-onboarding.sh

%changelog
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-2
- Replace sideral-hm-status.sh (home-manager bootstrap waiter, retired
  alongside nix-home) with sideral-cli-init.sh (CHM-11/12) and
  sideral-onboarding.sh (CHM-21/22).
* Thu Apr 23 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: poll-and-source bootstrap UX (sideral-hm-status.sh)
