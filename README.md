<h1 align="center">sideral</h1>

<p align="center">
  <em>Personal Fedora atomic desktop — stock GNOME on uBlue silverblue-main, ghostty terminal, Zen Browser, GNU-stow-driven dotfiles, mise toolchain.</em>
</p>

<p align="center">
  <a href="https://github.com/athenabriana/sideral/releases/latest"><img src="https://img.shields.io/github/v/release/athenabriana/sideral?label=Latest&style=for-the-badge&logo=fedora&logoColor=white&labelColor=294172&color=3584e4" alt="Latest release"></a>
  <a href="https://github.com/athenabriana/sideral/actions/workflows/build.yml"><img src="https://img.shields.io/github/actions/workflow/status/athenabriana/sideral/build.yml?branch=main&style=for-the-badge&logo=githubactions&logoColor=white&label=Build&labelColor=294172" alt="Build status"></a>
  <a href="https://github.com/athenabriana/sideral/blob/main/LICENSE"><img src="https://img.shields.io/github/license/athenabriana/sideral?style=for-the-badge&logo=opensourceinitiative&logoColor=white&label=License&labelColor=294172&color=3584e4" alt="License"></a>
</p>

## Quick start

Two ways to try sideral.

### Boot from USB (try before installing)

<p align="center">
  <a href="https://sideral.athenabriana.com/sideral_x86_64.iso"><img src="https://img.shields.io/badge/%E2%AC%87%20Download%20ISO-latest-3584e4?style=for-the-badge&logo=fedora&logoColor=white&labelColor=1a2a4a" alt="Download ISO" height="44"></a>
</p>

The button starts the download immediately — single ~5 GiB ISO, hosted on Cloudflare R2. Verify the checksum and flash:

```bash
curl -LO https://sideral.athenabriana.com/sideral_x86_64.iso
curl -LO https://sideral.athenabriana.com/sideral_x86_64.iso.sha256
sha256sum -c sideral_x86_64.iso.sha256
sudo dd if=sideral_x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Or use Etcher / Impression / GNOME Disks. Boot the USB and the preloaded Anaconda installer walks you through writing sideral to disk.

### Rebase an existing Fedora atomic install

Pick the variant that matches your GPU. The ISO installer auto-detects via `lspci`; for manual rebase you choose explicitly:

```bash
# Open-source GPU stack (AMD / Intel / nouveau)
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/athenabriana/sideral:latest

# NVIDIA proprietary drivers (Maxwell / GTX 900-series and newer)
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/athenabriana/sideral-nvidia:latest

systemctl reboot
```

After reboot the image is fully wired — stock GNOME session via GDM, ghostty terminal, Zen Browser, starship prompt, mise, atuin, zoxide, fzf, gh, VS Code all on `$PATH`. The curated flatpak set is preinstalled at image build. Default shell configs are symlinked into `$HOME` by GNU stow on first login. Layer your own dotfiles on top with stow against your personal repo (see [Set up dotfiles](#set-up-dotfiles)).

---

Built directly on `ghcr.io/ublue-os/silverblue-main:44`. Inherits the stock GNOME desktop unchanged; adds ghostty terminal (Terra), a `sideral-cli-tools` meta-RPM with day-to-day CLI tools + VS Code, Zen Browser (Flathub), rootless podman with docker compatibility shims, and a curated flatpak set. Image-default dotfiles are seeded by [GNU stow](https://www.gnu.org/software/stow/) on first login.

## What's in the image

| Layer | Contents |
| --- | --- |
| **Base** | `ghcr.io/ublue-os/silverblue-main:44` (open-source GPU); `silverblue-nvidia:44` for the `sideral-nvidia` variant. ISO installer reads `lspci` and pulls the matching variant at install time. |
| **Desktop** | Stock GNOME inherited from silverblue-main (Mutter + GDM + GNOME Shell). No custom compositor, shell, or greeter. |
| **Terminal** | [ghostty](https://ghostty.org) via Terra repo. Per-user config symlinked into `$HOME` by stow on first login. |
| **Browser** | [Zen Browser](https://zen-browser.app) (`app.zen_browser.zen` from Flathub). Preinstalled at image build. |
| **Editor** | `code` (VS Code) via Microsoft RPM repo. `hx` (Helix) from `sideral-cli-tools`. |
| **Containers** | Rootless podman + podman-docker shim + podman-compose. `docker` CLI resolves to podman. No daemon. |
| **CLI toolset** | `sideral-cli-tools` meta-RPM: `stow`, `mise`, `code`, `starship`, `carapace-bin`, `atuin`, `fzf`, `bat`, `eza`, `ripgrep`, `zoxide`, `gh`, `git-lfs`, `gcc`, `make`, `cmake`, `helix`, `zsh` (+ syntax-highlighting + autosuggestions), `rclone`, `fuse3`, `ghostty`. |
| **Shell-init wiring** | `~/.bashrc` + `~/.zshrc` (stow-symlinked from `/usr/share/sideral/stow/`) wire starship + atuin + zoxide + mise + fzf + carapace, plus Ctrl+P/Alt+S/Ctrl+G keybindings, eza/bat aliases, AI-agent guard. `command -v`-guarded throughout. |
| **Fonts** | Cascadia Code, JetBrains Mono, Adwaita, OpenDyslexic (Fedora main) + Source Serif 4, Source Sans 3 (Adobe GitHub). |
| **User dotfiles** | Image defaults (ghostty, bash/zsh, mise) symlinked into `$HOME` by GNU stow on first login. To customize a single file, replace its symlink with a real copy and edit. |
| **Flatpaks (preinstalled)** | Zen Browser, Bazaar, Flatseal, Extension Manager, Podman Desktop, DistroShelf, Resources, Smile, Web App Hub, Pika Backup, Junction (all from Flathub). Single curated remote: `flathub`. |

## Repo layout

```
sideral/
├── Justfile                         # build / rebase / lint
├── os/                              # everything that lands in the OCI image
│   ├── Containerfile                # image recipe (FROM silverblue-main:44)
│   ├── lib/
│   │   ├── build.sh                 # orchestrator: per-module *.sh + initramfs regen
│   │   └── build-rpms.sh            # inline rpmbuild: walks os/modules/*/rpm/*.spec
│   ├── modules/                     # each capability owns one directory
│   │   ├── base/         /etc/os-release + yum.repos.d/{mise,vscode}.repo + policy.json  rpm/sideral-base.spec
│   │   ├── cli-tools/    packages.txt (CLI tools + ghostty) + Terra/carapace repos  rpm/sideral-cli-tools.spec
│   │   ├── dotfiles/     stow source tree (bash, zsh, ghostty, mise)  rpm/sideral-stow-defaults.spec
│   │   ├── shell-ux/     ujust 60-custom.just + user-motd + rclone-gdrive.service  rpm/sideral-shell-ux.spec
│   │   ├── services/     podman/distrobox configs  rpm/sideral-services.spec
│   │   ├── kubernetes/   kubectl repo + KIND env + kind/helm install  rpm/sideral-kubernetes.spec
│   │   └── flatpaks/     remotes + curated manifest + purge list  rpm/sideral-flatpaks.spec
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
   gh repo create sideral --public --source . --remote origin --push
   ```
2. Wait ~30 min for the `build-sideral` workflow. It builds two bootc OCI image variants in parallel (`sideral` open-source and `sideral-nvidia` proprietary-drivers), runs semantic-release (which cuts a GitHub Release with changelog), builds a single installer ISO with titanoboa that auto-detects GPU at install time and pulls the matching variant from ghcr.io, and uploads the ISO to your Cloudflare R2 bucket under a constant `sideral_x86_64.iso` key.
3. From then on, every push to `main` cuts a new versioned release; every night the workflow rebases on the latest Silverblue base and republishes if anything changed.

What lands in CI:

| Artifact | Where | Tags |
| --- | --- | --- |
| Bootc images (rebase targets) | `ghcr.io/<you>/sideral` (open-source GPU), `ghcr.io/<you>/sideral-nvidia` (proprietary NVIDIA) | `:latest`, `:YYYYMMDD`, `:sha-<short>` |
| Installer ISO (latest only, single file) | Cloudflare R2 (`s3://<bucket>/Sideral x86_64.iso`) | constant key — overwrites |
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

sideral ships a default dotfile set at `/usr/share/sideral/stow/<pkg>/` — one stow package per concern (`bash`, `zsh`, `ghostty`, `mise`), each holding a destination-shaped layout (e.g. `ghostty/.config/ghostty/config`). On first login, `/etc/profile.d/sideral-stow-defaults.sh` runs `stow --restow --no-folding` over every package, so `~/.bashrc`, `~/.zshrc`, `~/.config/ghostty/config`, and `~/.config/mise/config.toml` become symlinks into the read-only ostree source.

After `rpm-ostree upgrade` (e.g. when a new file lands in the seed), re-apply with:

```bash
ujust apply-defaults
```

That re-stows every package, picking up new files; existing symlinks stay; if you replaced a symlink with a real file, stow refuses to overwrite it.

### Customize a single file

Because the file in `$HOME` is a symlink to a read-only ostree path, you can't edit in place. To customize:

```bash
# 1. break the symlink and copy out
file=~/.bashrc
cp -L "$file" /tmp/copy && rm "$file" && mv /tmp/copy "$file"
# 2. edit your copy
$EDITOR "$file"
# 3. on next `ujust apply-defaults`, stow leaves your real file alone
```

To restore the sideral default later, delete your copy and run `ujust apply-defaults`.

### Bring your own dotfiles

For a personal dotfile repo on top of (or instead of) the sideral seed, the simplest stow-native flow is to use stow itself against your repo:

```bash
git clone https://github.com/<you>/dotfiles ~/dotfiles
cd ~/dotfiles
stow --target="$HOME" --no-folding <package>
```

If your personal repo packages something the sideral seed already symlinked, stow refuses with a conflict — `unstow` the sideral package first or delete the conflicting symlink, then re-stow your own. There is no automatic conflict resolution between the two sources.

## CLI toolset — sideral-cli-tools

The `sideral-cli-tools` meta-RPM declares `Requires:` on the CLI tools + VS Code + ghostty:

| Tool | Source |
| --- | --- |
| `stow`, `atuin`, `fzf`, `bat`, `eza`, `ripgrep`, `zoxide`, `gh`, `git-lfs`, `gcc`, `make`, `cmake`, `helix`, `zsh`, `zsh-syntax-highlighting`, `zsh-autosuggestions`, `rclone`, `fuse3` | Fedora 44 main |
| `mise` | mise.jdx.dev/rpm (persistent repo, `rpm-ostree upgrade` pulls updates) |
| `code` (VS Code) | packages.microsoft.com (persistent repo) |
| `starship`, `ghostty` | Terra (`repos.fyralabs.com/terra44`, persistent repo) |
| `carapace-bin` | yum.fury.io/rsteube (persistent repo) |

All present after `rpm-ostree rebase`. To opt out (slimmer derivative): `sudo rpm-ostree override remove sideral-cli-tools`. Individual tools can also be removed: `sudo rpm-ostree override remove zoxide`. The image-default `~/.bashrc` and `~/.zshrc` `command -v`-guard each integration so removing any single tool is safe.

mise toolchains (node, bun, python, go, etc.) are *user-level* — declare them in your stowed `~/.config/mise/config.toml`. sideral doesn't ship a default toolchain; pick what you use.

## Iterating on dotfiles

Layer choice:

- **System-wide** (repo files, systemd units, os-release, packages) → `os/modules/<capability>/src/` or `os/modules/<capability>/packages.txt`. Rebuild image + rebase.
- **User-level** (shell, prompt, git, mise toolchains, per-program configs) → break the stow symlink (see "Customize a single file" above) and edit. For a personal git-tracked layer, stow your own packages on top.

## Why not nix?

sideral *did* have a nix + home-manager user layer in flight — see `.specs/features/nix-home/spec.md`. It was implemented locally then retired before VM verification on 2026-05-01. Three documented frictions specifically affect Fedora atomic 42+: composefs vs the nix-installer ostree planner ([nix-installer#1445](https://github.com/DeterminateSystems/nix-installer/issues/1445)), SELinux mislabel of `/nix` store paths ([#1383](https://github.com/DeterminateSystems/nix-installer/issues/1383), open since 2023), and `/nix` + nix-daemon disappearing after `rpm-ostree upgrade` on F42+ (Universal Blue forum reports). The stow seed gets you image-default dotfiles without any of those failure modes — and without depending on chezmoi as an intermediary. See `.specs/features/chezmoi-home/context.md` D-01 for the historical nix-vs-chezmoi rationale.

## Rollback

If a rebase breaks: reboot, pick the previous deployment at GRUB, or:
```bash
rpm-ostree rollback
systemctl reboot
```
