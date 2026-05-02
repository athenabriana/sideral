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
  /etc/sideral-flatpak-remotes                       — 1 curated remote (flathub)
  /etc/flatpak-manifest                              — 8 entries
  /etc/systemd/system/sideral-flatpak-install.service — every-boot self-heal,
                                                        per-line idempotent
  multi-user.target.wants/ enablement symlink

Curated remote: flathub (Flathub). The Fedora flatpak registry was
previously also registered but never used by any manifest entry, and
its presence caused titanoboa's live-ISO flatpak install to fail on
refs that exist in both remotes (Flatseal in particular). One remote =
no ambiguity for `flatpak install --noninteractive -y <bare-ref>`.

Curated apps (8, all from flathub): Zen Browser (app.zen_browser.zen) +
Flatseal, Warehouse, Extension Manager, Podman Desktop, DistroShelf,
Resources, Smile.

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
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-4
- Drop the unused `fedora` flatpak remote. Every manifest entry installs
  from flathub; the fedora remote was registered but never referenced.
  Its presence broke the live-ISO build because titanoboa's
  `flatpak install --noninteractive -y <bare-ref>` cannot disambiguate
  refs that exist in multiple remotes — Flatseal exists in both flathub
  and fedora, so the install prompted for a remote and aborted in
  non-interactive mode. Single-remote setup eliminates that class of
  failure.
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-3
- Browser is now Zen Browser (app.zen_browser.zen from Flathub).
  Replaces the imput/helium COPR (broke twice on the same /opt cpio
  conflict — RPM packages /opt/ itself) and a brief detour through
  community Helium flatpak packagings (MarioGK ostree remote ships an
  empty Pages deployment; ShyVortex ships only release bundles).
  Flathub-listed app — standard `flatpak update` flow, no special
  remote, no bundle gymnastics.
- New file: /etc/sideral-flatpak-remotes — curated remote set
  (flathub, fedora oci+registry). Read by os/build.sh at image build
  and by sideral-flatpak-install.service for forward-compat re-add.
  (fedora remote subsequently removed in 0.0.0-4.)
- Curated flatpaks are now preinstalled at image build (os/build.sh
  registers remotes + installs the full manifest into /var/lib/flatpak).
  ISO ships with everything present — no first-boot download wait,
  works offline. `flatpak update` (run nightly by inherited
  ublue-os-update-services) refreshes everything.
- sideral-flatpak-install.service repurposed as forward-compat self-heal:
  every boot it re-applies remotes + manifest. New entries added in
  future image rebases install on existing user systems whose
  /var/lib/flatpak was seeded at an older image. Drops the
  `/var/lib/sideral/flatpak-install-done` sentinel that previously
  gated once-only runs.
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-2
- Drop app.zen_browser.zen from the manifest (8 → 7 refs). Browser is
  now helium-bin from the imput/helium COPR (RPM, baked into the
  image), not a flatpak. Reverses the 2026-04-23 helium → Zen swap.
* Thu Apr 23 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: 8-ref manifest (Zen Browser + 7 GUI apps) + flatpak-install service
