# sideral-services — container-related systemd units + config.
#
# Ships (post 2026-05-02 module refactor):
#   • /usr/lib/systemd/user/sockets.target.wants/podman.socket → ../podman.socket
#     Auto-enables the rootless podman API socket for every user on first
#     login. Required so podman-docker's /etc/profile.d/podman-docker.sh
#     (which sets DOCKER_HOST=unix:///run/user/$UID/podman/podman.sock)
#     points at a live socket — and so `docker compose` / `podman-compose`
#     against compose.yaml just work without `systemctl --user enable
#     podman.socket` as a per-user setup step.
#   • /etc/distrobox/distrobox.conf
#     Distrobox defaults. Moved here from sideral-base in the module
#     refactor — distrobox is a container tool, fits the containers
#     module rather than the meta-package's identity bucket.
#
# The "services" name is somewhat outdated now that the package also
# ships static config; kept as-is for upgrade safety. Future renames
# would need careful Obsoletes:/Provides: handling.

Name:           sideral-services
Version:        %{?_sideral_version}%{!?_sideral_version:0.0.0}
Release:        1%{?dist}
Summary:        sideral container-runtime services + config (podman.socket + distrobox.conf)
License:        MIT
URL:            https://github.com/athenabriana/sideral
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       systemd
Requires:       podman

%description
Container-runtime systemd unit enablement and config for sideral.
Auto-enables the rootless podman.socket user unit so the docker
compatibility shims (podman-docker → /usr/bin/docker, podman-compose
→ docker compose) have a live API socket on first user login without
requiring `systemctl --user enable podman.socket` as manual setup.
Also owns /etc/distrobox/distrobox.conf — distrobox defaults.

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/
cp -a usr %{buildroot}/

%files
/etc/distrobox/distrobox.conf
/usr/lib/systemd/user/sockets.target.wants/podman.socket

%changelog
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-4
- Module refactor: source tree now lives at os/modules/containers/src/.
  Adds /etc/distrobox/distrobox.conf to %files (moved from sideral-base
  alongside the containers-related concerns it belongs with). No file
  conflict on image build — the inline rpm -Uvh --replacefiles step in
  the Containerfile claims ownership cleanly when both new specs land
  in the same transaction.
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-3
- Ship the podman.socket user-unit auto-enable symlink at
  /usr/lib/systemd/user/sockets.target.wants/podman.socket. Pairs with
  the docker → podman swap: docker compose / podman-compose against
  the docker-shim socket now works on first user login without manual
  `systemctl --user enable`.
- Drop "empty placeholder" status — the package now has actual content.
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-2
- Remove sideral-nix-install.service, sideral-nix-relabel.{path,service},
  sideral-home-manager-setup.service and their target.wants enablement
  symlinks. Package becomes an empty placeholder (chezmoi-home CHM-03).
* Thu Apr 23 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: sideral-nix-install + nix-relabel + home-manager-setup units.
