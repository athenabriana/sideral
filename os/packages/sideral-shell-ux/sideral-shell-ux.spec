# sideral-shell-ux — interactive-shell hooks (CLI init wiring + onboarding tip)

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
Ships three /etc/profile.d/ snippets:

  sideral-cli-init.sh    — central shell-init wiring for starship, atuin,
                           zoxide, mise, and fzf. Each integration is
                           `command -v`-guarded so removing any single tool
                           via `rpm-ostree override remove` doesn't break
                           the rest. Replaces home-manager's declarative
                           `programs.X.enable` wiring.

  sideral-onboarding.sh  — one-shot chezmoi init hint shown on the first
                           interactive shell per user. Subsequent shells
                           stay silent (marker at ~/.cache/sideral/).

  sideral-kind-podman.sh — KIND_EXPERIMENTAL_PROVIDER=podman + MINIKUBE_
                           DRIVER=podman so the K8s tooling that defaults
                           to dockerd talks to sideral's rootless podman
                           instead. Pairs with the kubernetes feature dir
                           and Podman Desktop's Kubernetes panel.

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/

%files
/etc/profile.d/sideral-cli-init.sh
/etc/profile.d/sideral-onboarding.sh
/etc/profile.d/sideral-kind-podman.sh

%changelog
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-3
- Add sideral-kind-podman.sh — exports KIND_EXPERIMENTAL_PROVIDER=podman
  and MINIKUBE_DRIVER=podman so the K8s tooling that defaults to
  dockerd uses sideral's rootless podman instead. Without this,
  `kind create cluster` fails on a fresh sideral install ("docker ps"
  not found / wrong DOCKER_HOST resolution paths). Pairs with the
  new kubernetes feature dir and powers Podman Desktop's K8s panel.
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-2
- Replace sideral-hm-status.sh (home-manager bootstrap waiter, retired
  alongside nix-home) with sideral-cli-init.sh (CHM-11/12) and
  sideral-onboarding.sh (CHM-21/22).
* Thu Apr 23 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: poll-and-source bootstrap UX (sideral-hm-status.sh)
