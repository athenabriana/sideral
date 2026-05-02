#!/usr/bin/env bash
# Install kubectl from the pkgs.k8s.io persistent repo.
#
# The repo file lives at modules/kubernetes/src/etc/yum.repos.d/
# kubernetes.repo and is staged into /etc/yum.repos.d/ by the
# orchestrator before this script runs. Bumping the K8s minor (URL
# version segment) requires editing that .repo file in lockstep.

set -euo pipefail

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

log "Installing kubectl from pkgs.k8s.io"
dnf5 install -y --setopt=install_weak_deps=False kubectl
