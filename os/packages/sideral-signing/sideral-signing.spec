# sideral-signing — container/image trust policy

Name:           sideral-signing
Version:        %{?_sideral_version}%{!?_sideral_version:0.0.0}
Release:        1%{?dist}
Summary:        Container image trust policy for sideral (currently permissive placeholder)
License:        MIT
URL:            https://github.com/athenabriana/sideral
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

# Conflicts with ublue-os-signing — both want to own /etc/containers/policy.json.
# We replace its role for sideral-specific paths; see UPGRADE.md.
Conflicts:      ublue-os-signing

%description
Ships /etc/containers/policy.json. Currently a permissive placeholder
that matches Fedora's stock default (insecureAcceptAnything) — sideral
ships in "stay unverified" mode where rpm-ostree rebase uses
ostree-unverified-registry: and signature verification is not enforced.

To flip to signed-rebase verification (per spec ACR-27..29), replace
the policy with the strict sigstoreSigned schema documented in
packages/sideral-signing/UPGRADE.md and update the rebase URL.

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/

%files
/etc/containers/policy.json

%changelog
* Thu Apr 23 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: permissive placeholder policy.json (stay-unverified mode)
