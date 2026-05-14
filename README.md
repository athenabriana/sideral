<h1 align="center">silverfox</h1>

<p align="center">
  <em>Personal Fedora atomic desktop — stock GNOME on uBlue silverblue-main, ghostty terminal, Zen Browser, /etc/skel-seeded user dotfiles, mise toolchain, `fox` operator CLI.</em>
  <br><em>fox</em> = <strong>F</strong>edora <strong>O</strong>verengineered <strong>E</strong>xperience
</p>

<p align="center">
  <a href="https://github.com/athenabriana/silverfox/releases/latest"><img src="https://img.shields.io/github/v/release/athenabriana/silverfox?label=Latest&style=for-the-badge&logo=fedora&logoColor=white&labelColor=294172&color=3584e4" alt="Latest release"></a>
  <a href="https://github.com/athenabriana/silverfox/actions/workflows/build.yml"><img src="https://img.shields.io/github/actions/workflow/status/athenabriana/silverfox/build.yml?branch=main&style=for-the-badge&logo=githubactions&logoColor=white&label=Build&labelColor=294172" alt="Build status"></a>
  <a href="https://github.com/athenabriana/silverfox/blob/main/LICENSE"><img src="https://img.shields.io/github/license/athenabriana/silverfox?style=for-the-badge&logo=opensourceinitiative&logoColor=white&label=License&labelColor=294172&color=3584e4" alt="License"></a>
</p>

## Quick start

Two ways to try silverfox.

### Boot from USB (try before installing)

<p align="center">
  <a href="https://silverfox.athenabriana.com/silverfox_x86_64.iso"><img src="https://img.shields.io/badge/%E2%AC%87%20Download%20ISO-latest-3584e4?style=for-the-badge&logo=fedora&logoColor=white&labelColor=1a2a4a" alt="Download ISO" height="44"></a>
</p>

The button starts the download immediately — single ~5 GiB ISO, hosted on Cloudflare R2. Verify the checksum and flash:

```bash
curl -LO https://silverfox.athenabriana.com/silverfox_x86_64.iso
curl -LO https://silverfox.athenabriana.com/silverfox_x86_64.iso.sha256
sha256sum -c silverfox_x86_64.iso.sha256
sudo dd if=silverfox_x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Or use Etcher / Impression / GNOME Disks. Boot the USB and the preloaded Anaconda installer walks you through writing silverfox to disk.

### Rebase an existing Fedora atomic install

Pick the variant that matches your GPU. The ISO installer auto-detects via `lspci`; for manual rebase you choose explicitly:

```bash
# Open-source GPU stack (AMD / Intel / nouveau)
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/athenabriana/silverfox:latest

# NVIDIA proprietary drivers (Maxwell / GTX 900-series and newer)
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/athenabriana/silverfox-nvidia:latest

systemctl reboot
```

After reboot the image is fully wired — stock GNOME session via GDM, ghostty terminal, Zen Browser, starship prompt, mise, atuin, zoxide, fzf, gh, and zed all on `$PATH`. The curated flatpak set is preinstalled at image build. Image-default user dotfiles ship via `/etc/skel`; `useradd` copies them into new user homes once, after which they're user-domain real files (see [Set up dotfiles](#set-up-dotfiles)). Run `fox` (or `man silverfox`) for the operator-CLI cheatsheet.

---

Built directly on `ghcr.io/ublue-os/silverblue-main:44`. Inherits the stock GNOME desktop unchanged; adds ghostty terminal (Terra), a `silverfox-cli-tools` meta-RPM with day-to-day CLI tools + zed, Zen Browser (Flathub), rootless podman with docker compatibility shims, and a curated flatpak set. Image-default user dotfiles ship as a stow source tree under `/etc/skel/.config/silverfox/stow/` with pre-farmed symlinks at `/etc/skel/{.bashrc,.zshrc,…}` — `useradd` seeds them once, silverfox never touches them again.

## What's in the image

| Layer | Contents |
| --- | --- |
| **Base** | `ghcr.io/ublue-os/silverblue-main:44` (open-source GPU); `silverblue-nvidia:44` for the `silverfox-nvidia` variant. ISO installer reads `lspci` and pulls the matching variant at install time. |
| **Desktop** | Stock GNOME inherited from silverblue-main (Mutter + GDM + GNOME Shell). No custom compositor, shell, or greeter. |
| **Terminal** | [ghostty](https://ghostty.org) via Terra repo. Per-user config symlinked into `$HOME` by stow on first login. |
| **Browser** | [Zen Browser](https://zen-browser.app) (`app.zen_browser.zen` from Flathub). Preinstalled at image build. |
| **Editor** | `zed` (Zed) via Terra repo. Set as both `$EDITOR` and `$VISUAL` (`zed --wait`) so git commit, sudoedit, mise edit, etc. all open a Zed buffer and block until close. |
| **Containers** | Rootless podman + podman-docker shim + podman-compose. `docker` CLI resolves to podman. No daemon. |
| **Operator CLI** | `fox` — `~20`-line bash dispatcher at `/usr/bin/fox` routing into `/usr/share/silverfox/silverfox.justfile` via `just`. Verbs: `chsh`, `cheatsheet`, `home factory-reset`, `update`, `upgrade`, `rollback`, `status`, `cleanup`, `changelog`. Cheatsheet at `man 7 silverfox` (alias: `fox cheatsheet`). Ships via the `silverfox-fox` RPM. |
| **CLI toolset** | `silverfox-cli-tools` meta-RPM: `stow`, `mise`, `zed`, `starship`, `carapace-bin`, `atuin`, `fzf`, `bat`, `eza`, `ripgrep`, `zoxide`, `gh`, `git-lfs`, `gcc`, `make`, `cmake`, `zsh` (+ syntax-highlighting + autosuggestions), `ghostty`. `just` lands alongside via the cli-tools layer (it's a Requires of `silverfox-fox`). |
| **Shell-init wiring** | `~/.bashrc` + `~/.zshrc` (real files seeded from `/etc/skel/.config/silverfox/stow/{bash,zsh}/` by `useradd`) wire starship + atuin + zoxide + mise + fzf + carapace, plus Ctrl+P/Alt+S/Ctrl+G keybindings, eza/bat aliases, AI-agent guard. `command -v`-guarded throughout. |
| **Fonts** | Cascadia Code, JetBrains Mono, Adwaita, OpenDyslexic (Fedora main) + Source Serif 4, Source Sans 3 (Adobe GitHub). |
| **User dotfiles** | Image defaults (bash, zsh, mise, ghostty, zed) seeded once into `$HOME` by `useradd` from `/etc/skel/.config/silverfox/stow/`. Five pre-farmed symlinks at `/etc/skel/{.bashrc,.zshrc,.config/{mise/config.toml,ghostty/config,zed/settings.json}}` resolve into the stow tree at seed time. Dotfiles become user-domain from then on — silverfox never modifies them. To revert to image defaults: `fox home factory-reset`. The zed package enables vim mode with `default_mode: helix_normal` for selection-first modal editing. |
| **Flatpaks (preinstalled)** | Zen Browser, Bazaar, Flatseal, Extension Manager, Podman Desktop, DistroShelf, Resources, Smile, Web App Hub, Pika Backup, Junction (all from Flathub). Single curated remote: `flathub`. |

## Repo layout

```
silverfox/
├── Justfile                         # build / rebase / lint
├── os/                              # everything that lands in the OCI image
│   ├── Containerfile                # image recipe (FROM silverblue-main:44)
│   ├── lib/
│   │   ├── build.sh                 # orchestrator: per-module *.sh + initramfs regen
│   │   └── build-rpms.sh            # inline rpmbuild: walks os/modules/*/rpm/*.spec
│   ├── modules/                     # each capability owns one directory
│   │   ├── base/         /etc/os-release + yum.repos.d/mise.repo + policy.json  rpm/silverfox-base.spec
│   │   ├── cli-tools/    packages.txt (CLI tools + ghostty + zed + just) + Terra/carapace repos  rpm/silverfox-cli-tools.spec
│   │   ├── fox/          bash dispatcher + Justfiles + libexec + manpage source + tests  rpm/silverfox-fox.spec
│   │   ├── home/         /etc/skel stow tree + pre-farmed symlinks  rpm/silverfox-home.spec
│   │   ├── shell-ux/     /etc/user-motd + /etc/mise/config.toml + login-shell migrate  rpm/silverfox-shell-ux.spec
│   │   ├── services/     podman/distrobox configs  rpm/silverfox-services.spec
│   │   ├── kubernetes/   kubectl repo + KIND env + kind/helm install  rpm/silverfox-kubernetes.spec
│   │   └── flatpaks/     remotes + curated manifest + purge list  rpm/silverfox-flatpaks.spec
│   └── build/                       # build-time-only (no RPM)
│       ├── fonts/        packages.txt + font-install.sh
│       └── nvidia/       apply.sh (kargs + modprobe) — gated on rpm -q kmod-nvidia
├── iso/                             # live-installer assets consumed by titanoboa
└── .github/workflows/build.yml      # CI: build, tag, push to ghcr.io, cosign keyless
```

## Forking this repo

Want to run your own variant?

1. Fork or copy the repo, push to your own GitHub:
   ```bash
   gh repo create silverfox --public --source . --remote origin --push
   ```
2. Wait ~30 min for the `build-silverfox` workflow. It builds two bootc OCI image variants in parallel (`silverfox` open-source and `silverfox-nvidia` proprietary-drivers), runs semantic-release (which cuts a GitHub Release with changelog), builds a single installer ISO with titanoboa that auto-detects GPU at install time and pulls the matching variant from ghcr.io, and uploads the ISO to your Cloudflare R2 bucket under a constant `silverfox_x86_64.iso` key.
3. From then on, every push to `main` cuts a new versioned release; every night the workflow rebases on the latest Silverblue base and republishes if anything changed.

What lands in CI:

| Artifact | Where | Tags |
| --- | --- | --- |
| Bootc images (rebase targets) | `ghcr.io/<you>/silverfox` (open-source GPU), `ghcr.io/<you>/silverfox-nvidia` (proprietary NVIDIA) | `:latest`, `:YYYYMMDD`, `:sha-<short>` |
| Installer ISO (latest only, single file) | Cloudflare R2 (`s3://<bucket>/Silverfox x86_64.iso`) | constant key — overwrites |
| Changelog + version tag | GitHub Releases | `v<semver>` |

R2 secrets needed in repo settings: `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`. Update `R2_ENDPOINT`, `R2_BUCKET`, and `R2_PUBLIC_BASE` in `.github/workflows/build.yml` to match your account.

## Local build

```bash
just            # list recipes
just build      # podman build locally (runs bootc container lint at the end)
just lint       # shellcheck all build scripts
just rebase     # rebase host to the local dev image
just rollback   # back to the previous deployment
```

## Set up dotfiles

silverfox ships image-default user dotfiles via `/etc/skel` — five stow packages at `/etc/skel/.config/silverfox/stow/{bash,zsh,mise,ghostty,zed}/`, plus pre-farmed relative symlinks at `/etc/skel/{.bashrc,.zshrc,.config/mise/config.toml,.config/ghostty/config,.config/zed/settings.json}` pointing into the stow tree. On `useradd`, `cp -a` semantics copy the whole tree (symlinks preserved) into the new user's home. From that moment forward the dotfiles are **user-domain real files** — silverfox never modifies them.

Existing users on an upgrade don't automatically pick up new defaults: image upgrades that change `/etc/skel` only affect future-created users. To opt in destructively:

```bash
fox home factory-reset           # prompts; --yes to skip the prompt
```

This wipes the silverfox-managed subtree of `$HOME` (depth-≤2 under `/etc/skel`) and reseeds from the current image. Non-silverfox subdirectories of `~/.config/` (e.g. `firefox/`, `Code/`) are preserved. See `man 7 silverfox` for the full scope.

### Customize a single file

Edit it in place. Real file, real edit:

```bash
$EDITOR ~/.bashrc
```

The `.bashrc` symlink shipped by `/etc/skel` was resolved into a real file at `useradd` time only on the symlink-target side — the symlink itself still points into `~/.config/silverfox/stow/bash/.bashrc`, which is also a real file. Edit either path; same file. To restore the silverfox default: `fox home factory-reset` (destructive — overwrites everything in scope, including unrelated edits).

For finer rollback, `git init` in `~/.config/silverfox/` and use `git checkout <path>` to restore individual files from a previous commit.

### Bring your own dotfiles

Custom stow packages must live **outside** the silverfox-managed subtree — `~/.config/silverfox/`, `~/.config/mise/`, `~/.config/ghostty/`, and `~/.config/zed/` are all wiped by `fox home factory-reset`. Recommended layout:

```bash
git clone https://github.com/<you>/dotfiles ~/.config/dotfiles
stow --target="$HOME" --dir="$HOME/.config/dotfiles" <package>
```

Files outside the four silverfox trees survive `fox home factory-reset` unchanged.

## CLI toolset — silverfox-cli-tools

The `silverfox-cli-tools` meta-RPM declares `Requires:` on the CLI tools + zed + ghostty:

| Tool | Source |
| --- | --- |
| `stow`, `atuin`, `fzf`, `bat`, `eza`, `ripgrep`, `zoxide`, `gh`, `git-lfs`, `gcc`, `make`, `cmake`, `zsh`, `zsh-syntax-highlighting`, `zsh-autosuggestions`, `just` | Fedora 44 main |
| `mise` | mise.jdx.dev/rpm (persistent repo, `rpm-ostree upgrade` pulls updates) |
| `starship`, `ghostty`, `zed` | Terra (`repos.fyralabs.com/terra44`, persistent repo) |
| `carapace-bin` | yum.fury.io/rsteube (persistent repo) |

All present after `rpm-ostree rebase`. To opt out (slimmer derivative): `sudo rpm-ostree override remove silverfox-cli-tools`. Individual tools can also be removed: `sudo rpm-ostree override remove zoxide`. The image-default `~/.bashrc` and `~/.zshrc` `command -v`-guard each integration so removing any single tool is safe.

mise toolchains (node, bun, python, go, etc.) are *user-level* — pre-seeded into `~/.config/mise/config.toml` via `/etc/skel` (9 toolchains: node, bun, pnpm, python, uv, go, rust, zig, act). Edit the real file in your home directory to customize; silverfox never reaches in.

## Iterating on dotfiles

Layer choice:

- **System-wide** (repo files, systemd units, os-release, packages) → `os/modules/<capability>/src/` or `os/modules/<capability>/packages.txt`. Rebuild image + rebase.
- **User-level** (shell, prompt, git, mise toolchains, per-program configs) → edit the real file under `~/.config/silverfox/stow/` (or top-level `~/.bashrc` / `~/.zshrc`). To revert to image defaults: `fox home factory-reset` (destructive — see above). For a personal git-tracked layer, stow your own packages out of `~/.config/dotfiles/` per the "Bring your own dotfiles" section.

## Why not nix?

silverfox *did* have a nix + home-manager user layer in flight — see `.specs/features/nix-home/spec.md`. It was implemented locally then retired before VM verification on 2026-05-01. Three documented frictions specifically affect Fedora atomic 42+: composefs vs the nix-installer ostree planner ([nix-installer#1445](https://github.com/DeterminateSystems/nix-installer/issues/1445)), SELinux mislabel of `/nix` store paths ([#1383](https://github.com/DeterminateSystems/nix-installer/issues/1383), open since 2023), and `/nix` + nix-daemon disappearing after `rpm-ostree upgrade` on F42+ (Universal Blue forum reports). The `/etc/skel` seed + `fox home factory-reset` model recovers the home-manager UX (declare → revert) without any of those failure modes — and v2's `fox home sync` (queued) will bring declarative manifests for flatpaks/dconf/systemd-user back without the nix substrate. See `.specs/features/chezmoi-home/context.md` D-01 for the historical nix-vs-chezmoi rationale, and `.specs/features/fox/context.md` D-16/D-17 for the home-manager-without-nix design.

## Rollback

If a rebase breaks: reboot, pick the previous deployment at GRUB, or:
```bash
fox rollback                    # alias for: rpm-ostree rollback
systemctl reboot
```
