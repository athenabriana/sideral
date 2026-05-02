#!/usr/bin/env bash
# mise (mise.jdx.dev) and code (packages.microsoft.com) live in
# persistent third-party repos shipped by sideral-base. The orchestrator
# stages those .repo files into /etc/yum.repos.d/ before running per-
# module scripts, so by the time this fires, both repos are reachable.

set -euo pipefail

log() { printf '\n\033[1;34m▶\033[0m %s\n' "$*"; }

log "Installing mise + code from persistent repos"
dnf5 install -y --setopt=install_weak_deps=False mise code
