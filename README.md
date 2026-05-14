<div align="center">

# silverfox

[![License](https://img.shields.io/badge/license-MIT-111111?style=flat-square)](./LICENSE)
[![GitHub](https://img.shields.io/badge/github-athenabriana%2Fsilverfox-111111?style=flat-square&logo=github)](https://github.com/athenabriana/silverfox)
[![Build](https://img.shields.io/github/actions/workflow/status/athenabriana/silverfox/build.yml?branch=main&style=flat-square&logo=githubactions&logoColor=white&label=build&labelColor=111111&color=111111)](https://github.com/athenabriana/silverfox/actions/workflows/build.yml)

_Fedora atomic desktop, overengineered to taste._

</div>

```bash
gh repo clone athenabriana/silverfox
cd silverfox
just build
```

## fox

The CLI is called `fox` — **f**edora **o**verengineered e**x**perience. Every verb is a `just` recipe.

```bash
fox sync       # nh home switch + stow
fox upgrade    # rpm-ostree upgrade
fox config     # open Dotfiles/ in $EDITOR
fox doctor     # diagnose nix + system health
fox cleanup    # prune containers, flatpaks, nix store
```

## what you get

- **GNOME** on uBlue silverblue-main
- **ghostty** terminal, **Zen** Browser
- `/etc/skel`-seeded dotfiles via stow at `~/Dotfiles/`
- **mise** toolchain (node, python, go, rust...)
- **nix** + **nh** for declarative user packages and flatpaks
- **fox** — a CLI that wraps it all

Boot from a USB to try it before installing, or rebase directly:

```bash
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/athenabriana/silverfox:latest
```

<sub>Built on [ublue-os/silverblue-main](https://github.com/ublue-os/silverblue-main).</sub>
