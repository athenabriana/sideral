# silverfox-base — meta-package + system identity + container trust policy.
#
# Owns:    /etc/os-release
#          /etc/containers/policy.json  (absorbed from silverfox-signing)
# Requires: every silverfox-* sub-package + transitive third-party deps
#
# What is NOT here anymore (post 2026-05-02 module refactor):
#   • /etc/distrobox/distrobox.conf  → moved to silverfox-services (services module)
#   • /etc/yum.repos.d/kubernetes.repo + /etc/profile.d/silverfox-kind-podman.sh
#                                    → moved to silverfox-kubernetes (kubernetes module)
# Both moves are intentional — each capability now owns its own files
# under os/modules/<capability>/. Spec name kept for upgrade safety.

Name:           silverfox-base
Version:        %{?_silverfox_version}%{!?_silverfox_version:0.0.0}
Release:        1%{?dist}
Summary:        silverfox meta-package — pulls all sub-packages + system identity
License:        MIT
URL:            https://github.com/athenabriana/silverfox
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

# Sub-packages (all required by default; users can rpm-ostree override
# remove for granular opt-out).
Requires:       silverfox-services          = %{version}-%{release}
Requires:       silverfox-shell-ux          = %{version}-%{release}
Requires:       silverfox-fox               = %{version}-%{release}
Requires:       silverfox-home              = %{version}-%{release}
Requires:       silverfox-cli-tools         = %{version}-%{release}
Requires:       silverfox-kubernetes        = %{version}-%{release}
Requires:       silverfox-nix               = %{version}-%{release}

# Conflicts with ublue-os-signing — both own /etc/containers/policy.json.
# The Containerfile removes ublue-os-signing before rpm -Uvh so this never
# triggers at install time; the Conflicts: declaration prevents accidental
# re-install on a running system.
Conflicts:      ublue-os-signing

# Third-party deps (Fedora main):
#   podman-docker  — docker → podman wrapper
#   podman-compose — Python-based docker-compose drop-in
# (mise migrated out of RPM entirely — now installed per-user via the
# home-manager flake in silverfox-home's /etc/skel seed. The previous
# vscode.repo was retired alongside the helix/code → zed editor swap;
# zed flows via terra.repo, shipped by silverfox-cli-tools.)
Requires:       podman-docker
Requires:       podman-compose

%description
Meta-package for silverfox, a personal Fedora atomic desktop layered on
ublue-os/silverblue-main. Installs the full silverfox customization
layer (sub-packages listed in Requires) plus rootless podman with
docker compatibility shims.

Owns: /etc/os-release (silverfox identity). Flatpaks managed
declaratively via nix-flatpak in the user's flake.nix (flathub remote +
curated set + nh home switch).

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/

%files
/etc/os-release
/etc/containers/policy.json

%changelog
* Thu May 14 2026 GitHub Actions <noreply@github.com> - 0.0.0-15
- Drop /etc/yum.repos.d/mise.repo. mise is no longer installed as a
  system RPM — it now comes from the home-manager flake
  (programs.mise.enable) in silverfox-home's /etc/skel seed. Without
  an RPM consumer, the mise.jdx.dev repo registration has no purpose
  and rpm-ostree upgrade would never pull anything from it.
* Mon May 11 2026 GitHub Actions <noreply@github.com> - 0.0.0-14
- Swap Requires: silverfox-stow-defaults → silverfox-fox + silverfox-home.
  dotfiles module retired; fox (operator CLI) and home (/etc/skel seed)
  replace it.
* Mon May 11 2026 GitHub Actions <noreply@github.com> - 0.0.0-13
- Drop /etc/yum.repos.d/vscode.repo. VS Code is removed from silverfox
  in favor of Zed (Terra repo, owned by silverfox-cli-tools). The
  Microsoft yumrepo no longer has a consumer in the image.
* Sun May 04 2026 GitHub Actions <noreply@github.com> - 0.0.0-12
- Absorb silverfox-signing: own /etc/containers/policy.json directly and
  declare Conflicts: ublue-os-signing. Eliminates the one-file signing
  module; the Containerfile's rpm -e --nodeps ublue-os-signing step
  remains (still needed before rpm -Uvh to satisfy the Conflicts).
  UPGRADE.md moved to os/modules/base/UPGRADE.md.
* Sun May 04 2026 GitHub Actions <noreply@github.com> - 0.0.0-11
- Add Requires: silverfox-chezmoi-defaults. New package ships
  /usr/share/silverfox/chezmoi/ (10 dotfiles) and the first-login
  profile.d auto-apply script; omitting it from the meta-package
  would silently skip dotfile seeding on every fresh install.
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-10
- Replace Requires: silverfox-dconf with Requires: silverfox-niri-defaults.
  silverfox-dconf (GNOME dconf snippets) is retired alongside the desktop/
  module. silverfox-niri-defaults owns Terra repo, niri config, matugen
  templates, SDDM theme selection, and Noctalia settings seed. The
  Containerfile's dconf update + ostree container commit block is also
  dropped (no dconf consumers remain in the image).
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-9
- Module refactor: source tree moved from os/packages/silverfox-base/src/
  to os/modules/base/src/. Spec name kept (silverfox-base) for upgrade
  safety. Two file ownerships transferred to better-fitting sibling
  packages:
    • /etc/distrobox/distrobox.conf            → silverfox-services
    • /etc/yum.repos.d/kubernetes.repo         → silverfox-kubernetes (new)
  Adds Requires: silverfox-kubernetes so the meta graph still pulls in
  the K8s capability without naming the moved files directly. No file
  conflicts on image build — the new silverfox-services and silverfox-
  kubernetes specs claim the moved paths cleanly via rpm -Uvh
  --replacefiles in the Containerfile inline-RPM step.
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-8
- Ship /etc/yum.repos.d/kubernetes.repo for kubectl (pkgs.k8s.io/core
  stable channel, currently v1.32). Pairs with the new kubernetes
  feature dir (kind + helm from Fedora main) and the kubectl entry
  alongside mise + code in os/build.sh's persistent-repo install pass.
  Powers Podman Desktop's Kubernetes panel.
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-7
- Drop /etc/yum.repos.d/docker-ce.repo and the docker-ce / containerd.io
  Requires. Container stack swapped from rootful Docker to rootless
  podman + docker compatibility shims (podman-docker, podman-compose).
  The persistent docker-ce-stable repo registration in os/build.sh,
  the --allowerasing flag that swapped Fedora's containerd, and the
  empty `docker` group footgun all go away with this change.
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-6
- Drop /etc/yum.repos.d/_copr_imput-helium.repo. The imput/helium COPR
  was tried twice as the source for the default browser and broke both
  times on the same /opt cpio conflict.
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-5
- Drop /etc/yum.repos.d/_copr_atim-starship.repo. starship is now
  fetched as the upstream signed musl binary at image build.
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-4
- Ship /etc/yum.repos.d/_copr_atim-starship.repo (later reverted in -5).
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-3
- Drop Requires: silverfox-user / silverfox-selinux (chezmoi-home CHM-03).
  Add Requires: silverfox-cli-tools (CHM-07).
  Ship /etc/yum.repos.d/{mise,vscode}.repo (CHM-08, CHM-09).
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-2
- Drop Requires: bazaar — replaced by gnome-software via the desktop
  module's packages.txt.
* Thu Apr 23 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: meta-package + os-release + distrobox.conf + docker-ce.repo.
