# athens-os

Personal Fedora atomic desktop built directly on `ghcr.io/ublue-os/silverblue-main:43`.
Ships GNOME + tiling-shell with a curated flatpak set, a 15-tool mise toolchain,
Helium as the default browser, and VS Code + docker-ce for day-to-day dev.

## What's in the image

| Layer | Contents |
| --- | --- |
| **Base** | `ghcr.io/ublue-os/silverblue-main:43` |
| **Desktop** | GNOME Shell (default from base) + 5 extensions: appindicator, dash-to-panel, bazaar-integration, tilingshell, rounded-window-corners |
| **Browser** | `helium-bin` (RPM, via `imput/helium` COPR — auto-updates with `rpm-ostree upgrade`) |
| **Editor** | `code` (RPM, via Microsoft repo — auto-updates with `rpm-ostree upgrade`) |
| **Containers** | `docker-ce` stack (podman inherited from base) |
| **Dev tooling** | `gh`, `starship`, `gcc`/`make`/`cmake`, `git-lfs`/`git-subtree`/`git-credential-libsecret`, `android-tools`, kernel-debug stack |
| **Fonts** | Cascadia Code, JetBrains Mono, Adwaita, OpenDyslexic (Fedora main) + Source Serif 4, Source Sans 3 (Adobe GitHub) |
| **User runtime toolchain** | mise installed per-user on first login; 11 language runtimes + 4 CLI tools (act, atuin, direnv, pnpm) declared in `~/.config/mise/config.toml` |
| **Flatpaks (auto-install on first boot)** | Flatseal, Warehouse, Extension Manager, Podman Desktop, DistroShelf, Resources, Smile |

## Repo layout

```
athens-os/
├── Containerfile                    # image recipe (FROM silverblue-main:43)
├── Justfile                         # build / rebase / apply-home / capture-home
├── build_files/
│   ├── build.sh                     # orchestrator (COPRs → features loop → os-release → cleanup)
│   └── features/
│       ├── gnome/           packages.txt  → appindicator + dash-to-panel + bazaar + tweaks + adw-gtk3-theme + fastfetch
│       ├── gnome-extensions/ post-install.sh → tilingshell + rounded-window-corners from extensions.gnome.org
│       ├── devtools/         packages.txt  → gh + starship + build deps + git ergonomics + android-tools + code + kernel-debug stack
│       ├── browser/          packages.txt  → helium-bin
│       ├── container/        packages.txt  → docker-ce + containerd.io + buildx + compose
│       └── fonts/            packages.txt + post-install.sh → Fedora font RPMs + Source Serif 4 / Sans 3
├── system_files/
│   ├── etc/
│   │   ├── dconf/
│   │   │   ├── profile/user                    → points GNOME at the system dconf DB
│   │   │   └── db/local.d/{00-athens-focus, 00-athens-gnome-shell, 10-athens-keybinds}
│   │   ├── flatpak-manifest                    → 7 refs
│   │   ├── systemd/system/athens-flatpak-install.service (+ multi-user.target.wants symlink)
│   │   └── yum.repos.d/{vscode.repo, docker-ce.repo}   → enabled so rpm-ostree upgrade pulls updates
│   └── usr/lib/systemd/user/
│       ├── athens-mise-install.service         → first-login: install mise + eagerly install act/atuin/direnv
│       ├── athens-vscode-setup.service         → first-login: install 3 VS Code extensions
│       └── default.target.wants/ (symlinks)
├── home/                                      → shipped to /etc/skel/
│   ├── .bashrc                                → starship + mise + atuin + direnv activation
│   └── .config/mise/config.toml               → 15-tool toolchain
└── .github/workflows/build.yml                → CI: build, tag (latest/YYYYMMDD/sha-<short>), push to ghcr.io, cosign keyless
```

## First-time setup

1. Create the GitHub repo and push:
   ```bash
   gh repo create athens-os --public --source . --remote origin --push
   ```
2. Wait ~10 min for the `build-athens-os` workflow to push `ghcr.io/<you>/athens-os:latest`.
3. Rebase your host:
   ```bash
   sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/<you>/athens-os:latest
   systemctl reboot
   ```
4. First login runs the mise + VS Code setup services automatically; the flatpak manifest installs in the background on the first reboot.

## Local build

```bash
just            # list recipes
just build      # podman build locally (runs bootc container lint at the end)
just lint       # shellcheck all build scripts
just rebase     # rebase host to the local dev image
just rollback   # back to the previous deployment
```

## Iterating on dotfiles

The repo is also the source of truth for `/etc/skel/` user defaults.

- **Fresh account:** skel is copied into `~/` on account creation. Nothing to do.
- **Existing account:** `just apply-home` rsyncs `home/` → `$HOME` (tracked files only; untracked left alone).
- **Edit live, capture back:** `just capture-home` pulls tracked files back into the repo. `just diff-home` previews the diff.

Currently tracked under `home/`:
- `.bashrc` (activates starship, mise, atuin, direnv)
- `.config/mise/config.toml` (15-tool toolchain)

## mise toolchain

The image ships no `mise` binary in `/usr`. On first graphical login, `athens-mise-install.service` installs mise to `~/.local/bin/` and eagerly pulls the three CLI tools whose shell hooks fire in every bash: `atuin`, `direnv`, `act`.

Other declared tools (node, python, go, rust, java, kotlin, zig, …) are installed lazily on first use — typing `node -v` triggers mise to fetch the right version. If you want everything at once, plain `mise install` (inside any directory) does that.

## Rollback

If a rebase breaks: reboot, pick the previous deployment at GRUB, or:
```bash
rpm-ostree rollback
systemctl reboot
```
