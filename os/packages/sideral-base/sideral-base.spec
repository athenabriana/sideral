# sideral-base — meta-package + core system identity files
#
# Owns: /etc/os-release, /etc/distrobox/distrobox.conf, /etc/yum.repos.d/docker-ce.repo
# Requires: all 7 sideral-* sub-packages + transitive third-party deps

Name:           sideral-base
Version:        %{?_sideral_version}%{!?_sideral_version:0.0.0}
Release:        1%{?dist}
Summary:        sideral meta-package — pulls all sub-packages + system identity
License:        MIT
URL:            https://github.com/athenabriana/sideral
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

# Sub-packages (all required by default; users can rpm-ostree override
# remove sideral-flatpaks etc. for granular opt-out).
Requires:       sideral-services = %{version}-%{release}
Requires:       sideral-flatpaks = %{version}-%{release}
Requires:       sideral-dconf    = %{version}-%{release}
Requires:       sideral-selinux  = %{version}-%{release}
Requires:       sideral-shell-ux = %{version}-%{release}
Requires:       sideral-user     = %{version}-%{release}
Requires:       sideral-signing  = %{version}-%{release}

# Third-party deps via Copr external-repo aggregation:
#   bazaar         — from ublue-os/packages
#   docker-ce      — from docker-ce-stable
#   containerd.io  — from docker-ce-stable
Requires:       bazaar
Requires:       docker-ce
Requires:       containerd.io

%description
Meta-package for sideral, a personal Fedora atomic desktop layered on
ublue-os/silverblue-main. Installs the full sideral customization
layer plus the curated docker-ce stack and bazaar app store.

Owns: /etc/os-release (sideral identity), /etc/distrobox/distrobox.conf
(distrobox auto-mount of /nix), /etc/yum.repos.d/docker-ce.repo (kept so
rpm-ostree upgrade pulls Docker updates between image rebuilds).

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/

%files
/etc/os-release
/etc/distrobox/distrobox.conf
/etc/yum.repos.d/docker-ce.repo

%changelog
* Thu Apr 23 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: meta-package + os-release + distrobox.conf + docker-ce.repo
- Requires: all 7 sideral-* sub-packages + bazaar + docker-ce + containerd.io
