# Tell Kubernetes-in-Docker tooling to talk to podman, not dockerd.
#
# kind defaults to dockerd; on sideral there is no dockerd (rootless
# podman + podman-docker shim took over 2026-05-02). Without this env
# var, `kind create cluster` fails with "ERROR: failed to list nodes:
# command 'docker ps ...' failed". The env var flips kind to its
# podman provider, which talks directly to the rootless podman socket
# (the one /etc/profile.d/podman-docker.sh already points DOCKER_HOST
# at). No setup beyond having podman.socket enabled — which sideral-
# services handles via its user-unit auto-enable symlink.
#
# minikube has the same dockerd default; MINIKUBE_DRIVER=podman
# preempts it the same way for users who add minikube manually
# (sideral doesn't ship minikube — kind covers the same need).

export KIND_EXPERIMENTAL_PROVIDER=podman
export MINIKUBE_DRIVER=podman
