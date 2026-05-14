# silverfox-fox — operator CLI (bash dispatcher around `just`).
#
# Ships:
#   /usr/bin/fox                                  — bash dispatcher (~20 lines)
#   /usr/share/silverfox/silverfox.justfile           — top-level Justfile (verbs)
#   /usr/share/silverfox/home.just                  — `mod home` recipes
#   /usr/libexec/silverfox/chsh.sh                  — login-shell switcher (allowlist: bash, zsh)
#   /usr/share/man/man7/silverfox.7.gz              — `man 7 silverfox` cheatsheet
#
# Artifacts are pre-built into /var/tmp/fox-prebuilt/ by the Containerfile
# (manpage rendered by the `man-build` pandoc stage; bash + Justfiles +
# libexec scripts COPY'd direct from the build context). %install reads
# from there and lays everything down at the canonical paths above. The
# Containerfile cleans up /var/tmp/fox-prebuilt/ in the same RUN that
# runs build-rpms.sh, so the prebuilt tree never ships in the image.
#
# Source0 is the synthesized empty/sentinel tarball that build-rpms.sh
# produces from the (presence of an) src/ tree — %setup -q has something
# to extract, but %install ignores it.

Name:           silverfox-fox
Version:        %{?_silverfox_version}%{!?_silverfox_version:0.0.0}
Release:        1%{?dist}
Summary:        silverfox operator CLI — `fox` dispatcher + recipes + manpage
License:        MIT
URL:            https://github.com/athenabriana/silverfox
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       just
Requires:       bash >= 4
Requires:       coreutils
Requires:       findutils
Requires:       gawk
Requires:       man-db
Requires:       rpm-ostree
Requires:       flatpak
Requires:       sudo
Requires:       shadow-utils

%description
silverfox-fox ships the `fox` operator CLI: a ~20-line bash dispatcher at
/usr/bin/fox that routes argv into /usr/share/silverfox/silverfox.justfile
via `just`. Verbs in v1: chsh, cheatsheet, update, upgrade, rollback,
status, cleanup, changelog, plus `home factory-reset` (hard reseed of
silverfox-managed paths under $HOME from /etc/skel). The cheatsheet ships
as a man 7 page rendered from os/modules/fox/src/man/silverfox.md via
pandoc in the image's `man-build` Containerfile stage. Silverfox-owned
operator CLI, decoupled from any inherited tooling slot.

%prep
%setup -q

%install
install -D -m 0755 /var/tmp/fox-prebuilt/bin/fox                       %{buildroot}/usr/bin/fox
install -D -m 0644 /var/tmp/fox-prebuilt/silverfox.7.gz                  %{buildroot}/usr/share/man/man7/silverfox.7.gz
install -D -m 0644 /var/tmp/fox-prebuilt/recipes/silverfox.justfile      %{buildroot}/usr/share/silverfox/silverfox.justfile
install -D -m 0644 /var/tmp/fox-prebuilt/recipes/home.just             %{buildroot}/usr/share/silverfox/home.just
install -D -m 0755 /var/tmp/fox-prebuilt/libexec/chsh.sh               %{buildroot}/usr/libexec/silverfox/chsh.sh

%files
/usr/bin/fox
/usr/share/man/man7/silverfox.7.gz
%dir /usr/share/silverfox
/usr/share/silverfox/silverfox.justfile
/usr/share/silverfox/home.just
%dir /usr/libexec/silverfox
/usr/libexec/silverfox/chsh.sh

%changelog
* Mon May 11 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial. Silverfox-owned operator CLI replacing ujust + 60-custom.just.
  Bash dispatcher (~20 lines) at /usr/bin/fox routes into
  /usr/share/silverfox/silverfox.justfile via `just`. v1 verbs: chsh,
  cheatsheet, home factory-reset, update, upgrade, rollback, status,
  cleanup, changelog. Manpage rendered by pandoc in the new `man-build`
  Containerfile stage and bridged via /var/tmp/fox-prebuilt/. Pairs with
  silverfox-home (/etc/skel seed) and the retirement of
  silverfox-stow-defaults + the gdrive integration.
