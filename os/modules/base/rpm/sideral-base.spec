# sideral-base — meta-package + system identity files.
#
# Owns:    /etc/os-release
#          /etc/yum.repos.d/{mise,vscode}.repo
# Requires: every sideral-* sub-package + transitive third-party deps
#
# What is NOT here anymore (post 2026-05-02 module refactor):
#   • /etc/distrobox/distrobox.conf  → moved to sideral-services (services module)
#   • /etc/yum.repos.d/kubernetes.repo + /etc/profile.d/sideral-kind-podman.sh
#                                    → moved to sideral-kubernetes (kubernetes module)
# Both moves are intentional — each capability now owns its own files
# under os/modules/<capability>/. Spec name kept for upgrade safety.

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
Requires:       sideral-services          = %{version}-%{release}
Requires:       sideral-flatpaks          = %{version}-%{release}
Requires:       sideral-niri-defaults     = %{version}-%{release}
Requires:       sideral-shell-ux          = %{version}-%{release}
Requires:       sideral-chezmoi-defaults  = %{version}-%{release}
Requires:       sideral-signing           = %{version}-%{release}
Requires:       sideral-cli-tools         = %{version}-%{release}
Requires:       sideral-kubernetes        = %{version}-%{release}

# Third-party deps (Fedora main):
#   podman-docker  — docker → podman wrapper
#   podman-compose — Python-based docker-compose drop-in
# (mise + code from sideral-cli-tools; their .repo files ship from this
# package's %files so rpm-ostree upgrade keeps pulling updates.)
Requires:       podman-docker
Requires:       podman-compose

%description
Meta-package for sideral, a personal Fedora atomic desktop layered on
ublue-os/silverblue-main. Installs the full sideral customization
layer (sub-packages listed in Requires) plus rootless podman with
docker compatibility shims.

Owns: /etc/os-release (sideral identity) and /etc/yum.repos.d/
{mise,vscode}.repo (kept enabled so rpm-ostree upgrade pulls mise and
VS Code updates between image rebuilds). starship is not in any of
these repos — it's baked into /usr/bin from the latest upstream binary
at image build (see os/lib/build.sh + os/modules/cli-tools/
starship-install.sh). Zen Browser ships as a Flathub flatpak
(app.zen_browser.zen), preinstalled at image build alongside the
rest of the curated flatpak set; updates flow via standard
`flatpak update`. Remotes + manifest live in sideral-flatpaks.

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/

%files
/etc/os-release
/etc/yum.repos.d/mise.repo
/etc/yum.repos.d/vscode.repo

%changelog
* Sun May 04 2026 GitHub Actions <noreply@github.com> - 0.0.0-11
- Add Requires: sideral-chezmoi-defaults. New package ships
  /usr/share/sideral/chezmoi/ (10 dotfiles) and the first-login
  profile.d auto-apply script; omitting it from the meta-package
  would silently skip dotfile seeding on every fresh install.
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-10
- Replace Requires: sideral-dconf with Requires: sideral-niri-defaults.
  sideral-dconf (GNOME dconf snippets) is retired alongside the desktop/
  module. sideral-niri-defaults owns Terra repo, niri config, matugen
  templates, SDDM theme selection, and Noctalia settings seed. The
  Containerfile's dconf update + ostree container commit block is also
  dropped (no dconf consumers remain in the image).
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-9
- Module refactor: source tree moved from os/packages/sideral-base/src/
  to os/modules/base/src/. Spec name kept (sideral-base) for upgrade
  safety. Two file ownerships transferred to better-fitting sibling
  packages:
    • /etc/distrobox/distrobox.conf            → sideral-services
    • /etc/yum.repos.d/kubernetes.repo         → sideral-kubernetes (new)
  Adds Requires: sideral-kubernetes so the meta graph still pulls in
  the K8s capability without naming the moved files directly. No file
  conflicts on image build — the new sideral-services and sideral-
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
- Drop Requires: sideral-user / sideral-selinux (chezmoi-home CHM-03).
  Add Requires: sideral-cli-tools (CHM-07).
  Ship /etc/yum.repos.d/{mise,vscode}.repo (CHM-08, CHM-09).
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-2
- Drop Requires: bazaar — replaced by gnome-software via the desktop
  module's packages.txt.
* Thu Apr 23 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: meta-package + os-release + distrobox.conf + docker-ce.repo.
