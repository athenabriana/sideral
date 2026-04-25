# athens-os

Personal Fedora atomic desktop built directly on `ghcr.io/ublue-os/silverblue-main:43`.
Ships GNOME + tiling-shell with a curated flatpak set, Nix + home-manager for
the user layer (12-tool mise toolchain declared in `home.nix`), Helium as the
default browser, and VS Code + docker-ce for day-to-day dev.

## What's in the image

| Layer | Contents |
| --- | --- |
| **Base** | `ghcr.io/ublue-os/silverblue-main:43` |
| **Desktop** | GNOME Shell (default from base) + 5 extensions: appindicator, dash-to-panel, bazaar-integration, tilingshell, rounded-window-corners |
| **Browser** | Zen Browser via flatpak (`app.zen_browser.zen`, auto-installed on first boot by `athens-flatpak-install.service`) |
| **Editor** | `vscode` via `programs.vscode` in home.nix (includes `ms-vscode-remote.remote-ssh` + `remote-containers`; user can remove with a one-line edit) |
| **Containers** | `docker-ce` stack (podman inherited from base) |
| **Dev tooling** | All in home.nix: `gh`, `starship`, `gcc`/`make`/`cmake`, `git` (with `lfs.enable` + `credential.helper = libsecret`). |
| **Fonts** | Cascadia Code, JetBrains Mono, Adwaita, OpenDyslexic (Fedora main) + Source Serif 4, Source Sans 3 (Adobe GitHub) |
| **Nix** | Upstream CppNix installed via `nix-installer` (ostree planner) on first boot; `/nix` persisted via bind mount from `/var/lib/nix` |
| **User environment** | home-manager (channels, `release-24.11`) bootstraps on first login from `~/.config/home-manager/home.nix`; owns bash, starship, atuin, git, mise, and CLI QoL (zoxide/fzf/bat/eza/ripgrep/nix-index/gh) |
| **User runtime toolchain** | `mise` via `home.packages`; 12 runtimes (node/bun/pnpm, python/uv, java/kotlin/gradle, go/rust/zig, android-sdk) declared inline in `home.nix` |
| **Flatpaks (auto-install on first boot)** | Zen Browser, Flatseal, Warehouse, Extension Manager, Podman Desktop, DistroShelf, Resources, Smile |

## Repo layout

```
athens-os/
├── Containerfile                    # image recipe (FROM silverblue-main:43)
├── Justfile                         # build / rebase / home-edit / home-apply / home-diff
├── build_files/
│   ├── build.sh                     # orchestrator: stage nix-installer → COPRs → features loop → os-release
│   └── features/
│       ├── gnome/           packages.txt  → appindicator + dash-to-panel + bazaar + tweaks + adw-gtk3-theme + fastfetch
│       ├── gnome-extensions/ post-install.sh → tilingshell + rounded-window-corners from extensions.gnome.org
│       ├── container/        packages.txt  → docker-ce + containerd.io + buildx + compose
│       └── fonts/            packages.txt + post-install.sh → Fedora font RPMs + Source Serif 4 / Sans 3
├── system_files/
│   ├── etc/
│   │   ├── dconf/
│   │   │   ├── profile/user                    → points GNOME at the system dconf DB
│   │   │   └── db/local.d/{00-athens-focus, 00-athens-gnome-shell, 10-athens-keybinds}
│   │   ├── flatpak-manifest                    → 8 refs (Zen Browser + 7 GUI apps)
│   │   ├── systemd/system/athens-flatpak-install.service (+ multi-user.target.wants symlink)
│   │   ├── systemd/system/athens-nix-install.service   (+ multi-user.target.wants symlink)  → first-boot: install Nix with ostree planner
│   │   └── yum.repos.d/docker-ce.repo                   → enabled so rpm-ostree upgrade pulls updates
│   └── usr/lib/systemd/user/
│       ├── athens-home-manager-setup.service   → first-login: install home-manager + home-manager switch
│       └── default.target.wants/ (symlinks)
├── home/                                      → shipped to /etc/skel/
│   └── .config/home-manager/home.nix          → single source of truth for user env (bash, starship, atuin, git, mise, CLI QoL)
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
4. First boot runs `athens-nix-install.service` (pulls ~200 MB, installs Nix, relabels `/nix`); `athens-flatpak-install.service` installs the manifest in parallel.
5. First graphical login runs `athens-home-manager-setup.service` (adds the home-manager channel, installs `home-manager`, runs `home-manager switch` — this installs VS Code + its extensions, mise, and the rest of `home.nix`).

## Local build

```bash
just            # list recipes
just build      # podman build locally (runs bootc container lint at the end)
just lint       # shellcheck all build scripts
just rebase     # rebase host to the local dev image
just rollback   # back to the previous deployment
```

## User environment — home.nix

`home/.config/home-manager/home.nix` is the single source of truth for bash, prompt, shell history, git, mise, and CLI quality-of-life tools. It ships via `/etc/skel` on every fresh user and is applied on first login by `athens-home-manager-setup.service` (which calls `home-manager switch` under the hood).

Edit / apply workflow:

```bash
just home-edit      # open the repo copy in $EDITOR
just home-apply     # run: home-manager switch -f home/.config/home-manager/home.nix
just home-diff      # build the generation so you can inspect what would change
```

Roll back: `home-manager generations` then `home-manager switch <path-from-list>`. home-manager keeps every prior generation as a symlink under `/nix/var/nix/profiles/per-user/$USER/`.

**First-shell UX**: on the very first login, opening a terminal before `athens-home-manager-setup.service` finishes would normally leave you with a bare Fedora default shell. `/etc/profile.d/athens-hm-status.sh` handles this by polling the setup marker for up to 5 minutes, then sourcing `hm-session-vars.sh` + `~/.bashrc` into your current shell — no reopen needed. Times out gracefully into a usable Fedora shell if setup stalls; run `journalctl --user -u athens-home-manager-setup -f` to see why.

Fresh account: skel is copied into `~/` on user creation, first login runs the setup service, no further action.

Existing account: edit `~/.config/home-manager/home.nix` directly and run `home-manager switch`, or iterate in the repo copy and use `just home-apply`.

## mise toolchain

`mise` is installed as a nix package via `home.packages`; `which mise` should resolve to `~/.nix-profile/bin/mise` after the first home-manager switch. The 12-tool toolchain (node/bun/pnpm, python/uv, java/kotlin/gradle, go/rust/zig, android-sdk) is declared inline inside `home.nix` via `home.file.".config/mise/config.toml".text`.

Tools install lazily on first use (`not_found_auto_install = true`); `mise install` in any directory pulls everything declared.

## Nix first-boot notes

- **SELinux**: Fedora's stock policy has no rules for `/nix` (not FHS-standard), so files land `default_t` and fail to execute (upstream [nix-installer#1383](https://github.com/NixOS/nix-installer/issues/1383)). athens-os root-fixes this by shipping `/etc/selinux/targeted/contexts/files/file_contexts.local` mapping `/nix` → `usr_t`, `/nix/store/*/bin` → `bin_t`, etc. `athens-nix-relabel.path` watches `/nix/store` and triggers `athens-nix-relabel.service` (`restorecon -RF /nix`) whenever `nix profile install` adds store paths, so labels stay correct automatically. Manual recovery if ever needed: `sudo systemctl start athens-nix-relabel.service`.
- **composefs (silverblue-main F42+)**: if `findmnt /nix` shows no mount after the install service completes, the active composefs-backed root may be blocking the bind mount. Workaround: add `rd.systemd.unit=root.transient` as a kernel argument (`sudo rpm-ostree kargs --append=rd.systemd.unit=root.transient`) and reboot.
- **Channel default**: `/etc/nix/nix.conf` is whatever the installer writes — no athens-os override. Flakes are off by default (classic CppNix behavior). Enable per-user by writing `experimental-features = nix-command flakes` into `~/.config/nix/nix.conf`.
- **nix-installer version**: pinned via `NIX_INSTALLER_VERSION` at the top of `build_files/build.sh`. The baked binary lives at `/usr/libexec/nix-installer`; bump via PR to the URL scheme in `build.sh`.

## Distrobox + nix integration

Every distrobox container created on athens-os auto-mounts the host's nix store. Configured via `system_files/etc/distrobox/distrobox.conf`:

```
container_additional_volumes="/nix /var/lib/nix /etc/nix"
```

Combined with the bashrc snippet in `home.nix` that sources `/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh` if `/nix` is present, every interactive shell — host or any distrobox container — gets `nix`, `nix-shell`, `nix-build`, `NIX_PATH`, and `NIX_REMOTE=daemon` wired automatically. Inside any container:

```bash
distrobox create --image fedora:42 dev
distrobox enter dev
$ nix --version                # works
$ nix-shell -p hyperfine        # talks to host's nix-daemon over /nix socket
$ nix profile install nixpkgs#act
$ mise --version                # already on PATH from ~/.nix-profile/bin
```

Read-write by default so containers can install packages into the shared store. To make it read-only, append `:ro` to each path in `distrobox.conf`.

## Iterating on dotfiles

Layer choice:

- **System-wide** (dconf keybinds, repo files, systemd units, os-release) → `system_files/etc/` or `system_files/usr/`. Rebuild image + rebase.
- **User-level** (shell, prompt, git, mise, per-program configs) → `home/.config/home-manager/home.nix`. Re-run `just home-apply` (no reboot).

## Rollback

If a rebase breaks: reboot, pick the previous deployment at GRUB, or:
```bash
rpm-ostree rollback
systemctl reboot
```
