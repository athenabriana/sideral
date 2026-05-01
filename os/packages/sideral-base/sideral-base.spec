# sideral-base — meta-package + core system identity files
#
# Owns: /etc/os-release, /etc/distrobox/distrobox.conf,
#       /etc/yum.repos.d/{docker-ce,mise,vscode}.repo
# Requires: all sideral-* sub-packages + transitive third-party deps

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
Requires:       sideral-services  = %{version}-%{release}
Requires:       sideral-flatpaks  = %{version}-%{release}
Requires:       sideral-dconf     = %{version}-%{release}
Requires:       sideral-shell-ux  = %{version}-%{release}
Requires:       sideral-signing   = %{version}-%{release}
Requires:       sideral-cli-tools = %{version}-%{release}

# Third-party deps:
#   docker-ce      — from docker-ce-stable
#   containerd.io  — from docker-ce-stable
# (Bazaar removed 2026-05-01 → gnome-software via features/gnome/packages.txt.)
# (mise + code from sideral-cli-tools; their repos are shipped here so
# `rpm-ostree upgrade` continues to pull updates between image rebuilds.)
Requires:       docker-ce
Requires:       containerd.io

%description
Meta-package for sideral, a personal Fedora atomic desktop layered on
ublue-os/silverblue-main. Installs the full sideral customization
layer plus the curated docker-ce stack and the chezmoi-driven CLI
toolset (sideral-cli-tools).

Owns: /etc/os-release (sideral identity), /etc/distrobox/distrobox.conf
(distrobox defaults), and /etc/yum.repos.d/{docker-ce,mise,vscode}.repo
(kept enabled so `rpm-ostree upgrade` pulls Docker, mise, and VS Code
updates between image rebuilds). starship is not in any of these repos
— it's baked into /usr/bin from the latest upstream binary at image
build (see os/build.sh). Helium browser ships as a Flatpak via the
community `helium` remote (MarioGK/helium-flatpak, GH Pages ostree
archive-z2; GPGVerify=false, single-maintainer trust). Preinstalled
at image build alongside the rest of the curated flatpak set; updates
flow via standard `flatpak update`. Remotes + manifest live in
sideral-flatpaks.

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/

%files
/etc/os-release
/etc/distrobox/distrobox.conf
/etc/yum.repos.d/docker-ce.repo
/etc/yum.repos.d/mise.repo
/etc/yum.repos.d/vscode.repo

%changelog
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-6
- Drop /etc/yum.repos.d/_copr_imput-helium.repo. The imput/helium COPR
  was tried twice as the source for the default browser and broke both
  times on the same /opt cpio conflict (RPM packages /opt/ itself,
  conflicting with the existing directory under buildah/dnf5). Browser
  is now Helium via the community `helium` Flatpak remote (MarioGK/
  helium-flatpak, GH Pages ostree archive-z2). Preinstalled at image
  build by os/build.sh alongside the rest of the curated flatpak set;
  updates via standard `flatpak update`. Remote config + manifest live
  in sideral-flatpaks.
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-5
- Drop /etc/yum.repos.d/_copr_atim-starship.repo. Sourcing starship from
  a third-party COPR added a packager hop with no real upside on an
  atomic image: starship updates only matter at image-rebuild cadence,
  and the upstream project ships signed musl binaries directly. starship
  is now fetched from /releases/latest/download (always-latest, no
  version pinning) + sha256-verified against the upstream-published sum
  and baked into /usr/bin by os/build.sh. New starship releases land
  automatically on the next image rebuild.
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-4
- Ship /etc/yum.repos.d/_copr_atim-starship.repo. starship isn't in Fedora
  main; the atim/starship COPR is the maintained source. Fixes CI build
  break introduced in -3 (`No match for argument: starship`).
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-3
- Drop Requires: sideral-user (package removed alongside home.nix retirement;
  /etc/skel ships nothing user-facing now).
- Drop Requires: sideral-selinux (package was a /nix-only file_contexts.local;
  with nix gone the rules match nothing and the %post restorecon is a no-op).
- Add Requires: sideral-cli-tools (chezmoi-home CHM-07).
- Ship /etc/yum.repos.d/{mise,vscode}.repo (chezmoi-home CHM-08, CHM-09) so
  rpm-ostree upgrade pulls mise and VS Code updates between image rebuilds.
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-2
- Drop Requires: bazaar — bazaar replaced by gnome-software + gnome-software-rpm-ostree
  in features/gnome/packages.txt. App-store layer now consumes Fedora main only.
* Thu Apr 23 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: meta-package + os-release + distrobox.conf + docker-ce.repo
- Requires: all 7 sideral-* sub-packages + bazaar + docker-ce + containerd.io
