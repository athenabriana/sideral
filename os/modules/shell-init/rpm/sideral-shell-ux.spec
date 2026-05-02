# sideral-shell-ux — interactive-shell hooks (CLI init wiring + onboarding tip).
#
# Lives in the shell-init module. Spec name kept (sideral-shell-ux)
# for upgrade safety; the module name "shell-init" is more accurate
# but renaming the spec adds Obsoletes:/Provides: complexity for no
# functional gain.

Name:           sideral-shell-ux
Version:        %{?_sideral_version}%{!?_sideral_version:0.0.0}
Release:        1%{?dist}
Summary:        sideral shell-init wiring + chezmoi onboarding hint
License:        MIT
URL:            https://github.com/athenabriana/sideral
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       bash

%description
Ships two /etc/profile.d/ snippets:

  sideral-cli-init.sh   — central shell-init wiring for starship, atuin,
                          zoxide, mise, and fzf. Each integration is
                          `command -v`-guarded so removing any single tool
                          via `rpm-ostree override remove` doesn't break
                          the rest. Replaces home-manager's declarative
                          `programs.X.enable` wiring.

  sideral-onboarding.sh — one-shot chezmoi init hint shown on the first
                          interactive shell per user. Subsequent shells
                          stay silent (marker at ~/.cache/sideral/).

(sideral-kind-podman.sh moved to sideral-kubernetes 2026-05-02 as part
of the module refactor — that snippet is K8s-tooling-specific, not a
generic shell-init concern.)

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/

%files
/etc/profile.d/sideral-cli-init.sh
/etc/profile.d/sideral-onboarding.sh

%changelog
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-4
- Module refactor: source tree moved to os/modules/shell-init/src/.
  /etc/profile.d/sideral-kind-podman.sh ownership transferred to
  sideral-kubernetes (kubernetes module owns its K8s-tooling-specific
  shell wiring). Spec name kept for upgrade safety. No file conflict
  on image build — sideral-kubernetes claims the path cleanly via
  rpm -Uvh --replacefiles in the inline-RPM step.
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-3
- Add sideral-kind-podman.sh (subsequently moved to sideral-kubernetes
  in -4).
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-2
- Replace sideral-hm-status.sh (home-manager bootstrap waiter, retired
  alongside nix-home) with sideral-cli-init.sh (CHM-11/12) and
  sideral-onboarding.sh (CHM-21/22).
* Thu Apr 23 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: poll-and-source bootstrap UX (sideral-hm-status.sh)
