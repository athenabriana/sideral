# silverfox-services — container-related systemd units + config.
#
# Ships (post 2026-05-02 module refactor):
#   • /usr/lib/systemd/user/sockets.target.wants/podman.socket → ../podman.socket
#     Auto-enables the rootless podman API socket for every user on first
#     login. Required so podman-docker's /etc/profile.d/podman-docker.sh
#     (which sets DOCKER_HOST=unix:///run/user/$UID/podman/podman.sock)
#     points at a live socket — and so `docker compose` / `podman-compose`
#     against compose.yaml just works without `systemctl --user enable
#     podman.socket` as a per-user setup step.

Name:           silverfox-services
Version:        %{?_silverfox_version}%{!?_silverfox_version:0.0.0}
Release:        1%{?dist}
Summary:        silverfox container-runtime services + config (podman.socket)
License:        MIT
URL:            https://github.com/athenabriana/silverfox
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       systemd
Requires:       podman

%description
Container-runtime systemd unit enablement and config for silverfox.
Auto-enables the rootless podman.socket user unit so the docker
compatibility shims (podman-docker → /usr/bin/docker, podman-compose
→ docker compose) have a live API socket on first user login without
requiring `systemctl --user enable podman.socket` as manual setup.

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a usr %{buildroot}/

%files
/usr/lib/systemd/user/sockets.target.wants/podman.socket

%changelog
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-3
- Ship the podman.socket user-unit auto-enable symlink at
  /usr/lib/systemd/user/sockets.target.wants/podman.socket. Pairs with
  the docker → podman swap: docker compose / podman-compose against
  the docker-shim socket now works on first user login without manual
  `systemctl --user enable`.
- Drop "empty placeholder" status — the package now has actual content.
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-2
- Remove silverfox-nix-install.service, silverfox-nix-relabel.{path,service},
  silverfox-home-manager-setup.service and their target.wants enablement
  symlinks. Package becomes an empty placeholder (chezmoi-home CHM-03).
* Thu Apr 23 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: silverfox-nix-install + nix-relabel + home-manager-setup units.
