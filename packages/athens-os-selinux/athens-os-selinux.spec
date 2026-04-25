# athens-os-selinux — /nix SELinux file context rules

Name:           athens-os-selinux
Version:        %{?_athens_version}%{!?_athens_version:0.0.0}
Release:        1%{?dist}
Summary:        SELinux file_contexts.local for /nix (root-fix nix-installer#1383)
License:        MIT
URL:            https://github.com/athenabriana/athens-os
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       selinux-policy-targeted
Requires:       policycoreutils

%description
Ships /etc/selinux/targeted/contexts/files/file_contexts.local mapping
/nix paths to existing-allow-rule types (usr_t, bin_t, lib_t, var_t).
Fixes Fedora SELinux's lack of /nix coverage that otherwise causes
nix-installer files to land as default_t and fail to execute.

Reuses existing types — no custom policy module needed.

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/

%posttrans
# Apply the new file_contexts.local to /nix if it exists. No-op on
# fresh installs where /nix isn't created yet (athens-nix-install.service
# runs restorecon -RF /nix on first boot anyway).
if [ -d /nix ]; then
    /usr/sbin/restorecon -RF /nix >/dev/null 2>&1 || :
fi

%files
/etc/selinux/targeted/contexts/files/file_contexts.local

%changelog
* Wed Apr 23 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: file_contexts.local mapping /nix → usr_t/bin_t/lib_t/var_t
