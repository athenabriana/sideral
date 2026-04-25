# athens-os-user — user defaults via /etc/skel

Name:           athens-os-user
Version:        %{?_athens_version}%{!?_athens_version:0.0.0}
Release:        1%{?dist}
Summary:        athens-os user-default config (home-manager bootstrap)
License:        MIT
URL:            https://github.com/athenabriana/athens-os
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

%description
Ships /etc/skel/.config/home-manager/home.nix — the home-manager config
new users start with. On useradd / gnome-initial-setup, /etc/skel
contents copy into the new user's $HOME; athens-home-manager-setup.service
then runs `home-manager switch` to materialize the environment.

Existing users update via `just home-apply` after `rpm-ostree upgrade`
(skel only affects newly-created accounts).

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/

%files
/etc/skel/.config/home-manager/home.nix

%changelog
* Wed Apr 23 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: home.nix for new-user home-manager bootstrap
