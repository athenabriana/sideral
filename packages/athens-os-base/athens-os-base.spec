# athens-os-base — meta-package
#
# Phase A skeleton: pulls the curated docker-ce stack + bazaar from the
# Copr's external-repo aggregation. Owns no files (yet) — by design. In
# Phase B the rest of the athens-os-* sub-packages get added to Requires
# and the meta-package owns /etc/os-release.
#
# Version is set by build-srpm.sh via --define "_athens_version YYYYMMDD.<run>".
# Falls back to 0.0.0 for local rpmbuild without that define (smoke test).

Name:           athens-os-base
Version:        %{?_athens_version}%{!?_athens_version:0.0.0}
Release:        1%{?dist}
Summary:        athens-os meta-package — pulls all sub-packages + transitive deps
License:        MIT
URL:            https://github.com/athenabriana/athens-os
BuildArch:      noarch

# Transitive third-party deps via Copr external-repo aggregation:
#   bazaar         — from ublue-os/packages
#   docker-ce      — from docker-ce-stable
#   containerd.io  — from docker-ce-stable
Requires:       bazaar
Requires:       docker-ce
Requires:       containerd.io

# Phase B will add Requires for the 7 athens-os-* sub-packages:
#   athens-os-services, athens-os-flatpaks, athens-os-dconf,
#   athens-os-selinux, athens-os-shell-ux, athens-os-user, athens-os-signing

%description
Meta-package for athens-os, a personal Fedora atomic desktop layered on
ublue-os/silverblue-main. Phase A skeleton pulls the curated docker-ce
stack and bazaar app store; the rest of the athens-os-* sub-packages
will be added in Phase B as the package layer is fleshed out.

This package owns no files by design — it's purely a dependency anchor.

%files

%changelog
* Wed Apr 23 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Phase A skeleton: meta-package, Requires bazaar + docker-ce stack
