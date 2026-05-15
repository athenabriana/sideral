Name:           silverfox-kubernetes
Version:        %{?_silverfox_version}%{!?_silverfox_version:0.0.0}
Release:        1%{?dist}
Summary:        silverfox Kubernetes tooling config (kubectl repo + kind/minikube env)
License:        MIT
URL:            https://github.com/athenabriana/silverfox
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

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
