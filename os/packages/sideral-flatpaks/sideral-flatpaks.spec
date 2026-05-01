# sideral-flatpaks — flatpak remotes + curated set + self-heal service
#
# Self-contained: ships the remotes config, the manifest, the systemd
# service that re-applies both on every boot, and the enablement symlink.
# Primary install runs at image build (os/build.sh); this package is the
# runtime self-heal. rpm-ostree override remove sideral-flatpaks cleanly
# removes both the manifest and the self-heal service (already-installed
# flatpaks at /var/lib/flatpak are NOT removed — that's the user's
# `flatpak uninstall` job; configured remotes likewise stay registered
# unless removed via `flatpak remote-delete`).

Name:           sideral-flatpaks
Version:        %{?_sideral_version}%{!?_sideral_version:0.0.0}
Release:        1%{?dist}
Summary:        sideral curated flatpak remotes + apps (preinstalled, self-heal)
License:        MIT
URL:            https://github.com/athenabriana/sideral
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       flatpak
Requires:       systemd

%description
Ships:
  /etc/sideral-flatpak-remotes                       — 3 curated remotes
                                                        (flathub, fedora, helium)
  /etc/flatpak-manifest                              — 8 entries
  /etc/systemd/system/sideral-flatpak-install.service — every-boot self-heal,
                                                        per-line idempotent
  multi-user.target.wants/ enablement symlink

Curated remotes: flathub (Flathub), fedora (Fedora Flatpak registry,
oci+https://registry.fedoraproject.org), helium (community-packaged
Helium browser from MarioGK/helium-flatpak — GPGVerify=false, single-
maintainer trust).

Curated apps (8): Helium browser (helium remote, net.imput.helium) +
Flatseal, Warehouse, Extension Manager, Podman Desktop, DistroShelf,
Resources, Smile (all from flathub).

The primary install runs at image build (os/build.sh) — flatpaks land
in /var/lib/flatpak before the image ships, factory-seeded to deployed
systems on first boot. The self-heal service handles forward-compat:
when a future image rebase adds new manifest entries or remotes,
deployed systems whose /var/lib/flatpak was seeded at an older image
pick them up on next boot. `ublue-os-update-services` (inherited from
silverblue-main) keeps everything updated via the standard `flatpak
update` cadence.

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/

%files
/etc/sideral-flatpak-remotes
/etc/flatpak-manifest
/etc/systemd/system/sideral-flatpak-install.service
/etc/systemd/system/multi-user.target.wants/sideral-flatpak-install.service

%changelog
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-3
- Browser is now Helium via the community `helium` Flatpak remote
  (MarioGK/helium-flatpak, ostree archive-z2 served from GitHub Pages).
  Replaces the imput/helium COPR which broke the build twice on the same
  /opt cpio conflict (RPM packages /opt/ itself).
- New file: /etc/sideral-flatpak-remotes — curated remote set (flathub,
  fedora oci+registry, helium). Read by os/build.sh at image build and
  by sideral-flatpak-install.service for forward-compat re-add.
- Curated flatpaks are now preinstalled at image build (os/build.sh
  registers remotes + installs the full manifest into /var/lib/flatpak).
  ISO ships with everything present — no first-boot download wait,
  works offline. `flatpak update` (run nightly by inherited
  ublue-os-update-services) refreshes both Flathub and helium remotes.
- sideral-flatpak-install.service repurposed as forward-compat self-heal:
  every boot it re-applies remotes + manifest. New entries added in
  future image rebases install on existing user systems whose
  /var/lib/flatpak was seeded at an older image. Drops the bundle line
  type (manifest format reverts to `<remote> <ref>` only) and the
  `/var/lib/sideral/flatpak-install-done` sentinel that previously
  gated once-only runs.
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-2
- Drop app.zen_browser.zen from the manifest (8 → 7 refs). Browser is
  now helium-bin from the imput/helium COPR (RPM, baked into the
  image), not a flatpak. Reverses the 2026-04-23 helium → Zen swap.
* Thu Apr 23 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: 8-ref manifest (Zen Browser + 7 GUI apps) + flatpak-install service
