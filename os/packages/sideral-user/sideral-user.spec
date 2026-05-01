# sideral-user — user defaults via /etc/skel

Name:           sideral-user
Version:        %{?_sideral_version}%{!?_sideral_version:0.0.0}
Release:        1%{?dist}
Summary:        sideral user-default config (home-manager bootstrap)
License:        MIT
URL:            https://github.com/athenabriana/sideral
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

%description
Ships /etc/skel/.config/home-manager/home.nix — the home-manager config
new users start with. On useradd / gnome-initial-setup, /etc/skel
contents copy into the new user's $HOME; sideral-home-manager-setup.service
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
* Thu Apr 23 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: home.nix for new-user home-manager bootstrap
