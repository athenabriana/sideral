# silverfox-kubernetes — Kubernetes tooling files (no binaries).
#
# New 2026-05-02. Owns K8s-related config files that previously lived
# split across silverfox-base (kubernetes.repo) and silverfox-shell-ux
# (silverfox-kind-podman.sh). Module refactor put both under
# os/modules/kubernetes/ — this spec is what installs them on the image.
#
# Ships:
#   • /etc/yum.repos.d/kubernetes.repo
#       Persistent repo file pointing at pkgs.k8s.io stable v1.32.
#       Kept enabled so `rpm-ostree upgrade` keeps pulling kubectl
#       patch updates between silverfox image rebuilds.
#   • /etc/profile.d/silverfox-kind-podman.sh
#       Exports KIND_EXPERIMENTAL_PROVIDER=podman + MINIKUBE_DRIVER=
#       podman so kind/minikube talk to silverfox's rootless podman
#       instead of failing on the missing dockerd default.
#
# Binaries (kubectl, kind, helm) come from package installs at image
# build time, not from this RPM — see os/modules/kubernetes/
# {packages.txt, kubectl-install.sh}.

Name:           silverfox-kubernetes
Version:        %{?_silverfox_version}%{!?_silverfox_version:0.0.0}
Release:        1%{?dist}
Summary:        silverfox Kubernetes tooling config (kubectl repo + kind/minikube env)
License:        MIT
URL:            https://github.com/athenabriana/silverfox
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

# kubectl, kind, helm are not declared as Requires here — they come
# from os/modules/kubernetes/{packages.txt, kubectl-install.sh} at
# image build, ahead of this RPM landing. Declaring them here would
# duplicate the Requires graph and add resolution cost without value.

%description
Kubernetes tooling configuration for silverfox. Ships the persistent
yum repo file for kubectl (pkgs.k8s.io stable v1.32) and the
KIND_EXPERIMENTAL_PROVIDER=podman / MINIKUBE_DRIVER=podman env-var
profile.d snippet so the K8s tooling that defaults to dockerd talks
to silverfox's rootless podman instead. Powers Podman Desktop's
Kubernetes panel and the local-cluster workflow.

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/

%files
/etc/yum.repos.d/kubernetes.repo
/etc/profile.d/silverfox-kind-podman.sh

%changelog
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial. Owns kubernetes.repo (moved from silverfox-base) and
  silverfox-kind-podman.sh (moved from silverfox-shell-ux). Created as
  part of the os/modules/ refactor that consolidates each capability's
  files under one module dir.
