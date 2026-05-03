<h1 align="center">sideral</h1>

<p align="center">
  <em>Personal Fedora atomic desktop — niri scrollable-tiling compositor, Noctalia shell, Zen Browser, chezmoi-driven dotfiles, mise toolchain.</em>
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
  <a href="https://sideral.athenabriana.com/sideral.iso"><img src="https://img.shields.io/badge/%E2%AC%87%20Download%20ISO-latest-3584e4?style=for-the-badge&logo=fedora&logoColor=white&labelColor=1a2a4a" alt="Download ISO" height="44"></a>
</p>

The button starts the download immediately — single ~5 GiB ISO, hosted on Cloudflare R2. Verify the checksum and flash:

```bash
curl -LO https://sideral.athenabriana.com/sideral.iso
curl -LO https://sideral.athenabriana.com/sideral.iso.sha256
sha256sum -c sideral.iso.sha256
sudo dd if=sideral.iso of=/dev/sdX bs=4M status=progress oflag=sync
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

After reboot the image is fully wired — niri session in SDDM, Noctalia bar/launcher/lock, Zen Browser, starship prompt, mise, atuin, zoxide, fzf, gh, VS Code all on `$PATH`. The curated flatpak set is preinstalled at image build. Default shell and compositor configs are applied on first login. Optionally bring your own dotfiles with `chezmoi init --apply <your-repo>` (see [Set up dotfiles](#set-up-dotfiles)).

---

Built directly on `ghcr.io/ublue-os/silverblue-main:43`. Ships the [niri](https://github.com/YaLTeR/niri) scrollable-tiling compositor with [Noctalia](https://github.com/noctalia-dev/noctalia-shell) as the desktop shell, a `sideral-cli-tools` meta-RPM with 14 day-to-day CLI tools + VS Code, Zen Browser (Flathub), rootless podman with docker compatibility shims, and matugen-driven wallpaper theming. User dotfiles are managed by [chezmoi](https://chezmoi.io).

## What's in the image

| Layer | Contents |
| --- | --- |
| **Base** | `ghcr.io/ublue-os/silverblue-main:43` (open-source GPU); `silverblue-nvidia:43` for the `sideral-nvidia` variant. ISO installer reads `lspci` and pulls the matching variant at install time. |
| **Compositor** | [niri](https://github.com/YaLTeR/niri) (Fedora main `niri-26.04`) — Rust-based scrollable-tiling Wayland compositor. PaperWM-style column navigation. No GNOME/Mutter. |
| **Shell** | [Noctalia](https://github.com/noctalia-dev/noctalia-shell) via Terra (`noctalia-shell 4.7.6`, runtime `noctalia-qs`). Bar, notification overlay, app launcher, lock screen, idle handler, control center, and wallpaper — all in one Quickshell-based package. |
| **Greeter** | SDDM with [SilentSDDM](https://github.com/uiriansan/SilentSDDM) `v1.4.2` theme. |
| **Terminal** | [ghostty](https://ghostty.org) via Terra — niri config binds `Mod+T`. |
| **Theming** | matugen (Fedora main `rust-matugen`). `ujust theme <wallpaper>` regenerates Material 3 palette → ghostty + helix. Noctalia drives its own bar/launcher/notification recolor via its built-in wallpaper picker. |
| **Browser** | [Zen Browser](https://zen-browser.app) (`app.zen_browser.zen` from Flathub). Preinstalled at image build. |
| **Editor** | `code` (VS Code) via Microsoft RPM repo. `hx` (Helix) from `sideral-cli-tools`. |
| **Containers** | Rootless podman + podman-docker shim + podman-compose. `docker` CLI resolves to podman. No daemon. |
| **CLI toolset** | `sideral-cli-tools` meta-RPM: `chezmoi`, `mise`, `atuin`, `fzf`, `bat`, `eza`, `ripgrep`, `zoxide`, `gh`, `git-lfs`, `gcc`, `make`, `cmake`, `helix`, `fish`, `zsh`, `rclone`. `starship` baked from upstream binary at image build. |
| **Shell-init wiring** | `/etc/profile.d/sideral-cli-init.sh`, `/etc/fish/conf.d/`, `/etc/zsh/` — starship, atuin, zoxide, mise, fzf in bash + fish + zsh. `command -v`-guarded. |
| **Fonts** | Cascadia Code, JetBrains Mono, Adwaita, OpenDyslexic (Fedora main) + Source Serif 4, Source Sans 3 (Adobe GitHub). |
| **User dotfiles** | Image defaults (niri, Noctalia, matugen, shell configs) applied on first login via chezmoi. Bring your own personal dotfiles with `chezmoi init --apply <your-repo>` — see below. |
| **Flatpaks (preinstalled)** | Zen Browser, Flatseal, Warehouse, Podman Desktop, DistroShelf, Resources, Smile, Bazaar, Pika Backup, Junction, Web App Hub (all from Flathub). Single curated remote: `flathub`. |

## Default niri keybinds

| Key | Action |
|---|---|
| `Mod+T` | ghostty terminal |
| `Mod+D` | Noctalia launcher |
| `Mod+L` | lock screen |
| `Mod+Q` | close window |
| `Mod+Left / Right` | focus column left / right |
| `Mod+Up / Down` | focus window up / down |
| `Mod+Shift+Left / Right` | move column left / right |
| `Mod+1–9` | switch workspace |
| `Mod+Shift+1–9` | move window to workspace |
| `Print` | screenshot region → clipboard |
| `Shift+Print` | full-screen screenshot → clipboard |

Run `ujust niri` for the full cheatsheet. Override keybinds in `~/.config/niri/config.kdl` (chezmoi template recommended).

## Theming

```bash
ujust theme ~/Pictures/wallpaper.jpg
```

Regenerates a Material 3 palette from the wallpaper and writes:
- `~/.config/ghostty/config-matugen` — add `config-file = ~/.config/ghostty/config-matugen` to your ghostty config
- `~/.config/helix/themes/sideral.toml` — set `theme = "sideral"` in `~/.config/helix/config.toml`

For the bar / launcher / notifications: use Noctalia's built-in wallpaper picker — it drives its own matugen pipeline.

## What changed from the GNOME-era sideral image

GNOME, tiling-shell, and all GNOME extensions were removed. The full GNOME stack (`gnome-shell`, `gnome-session`, `mutter`, `gnome-control-center`, `gnome-settings-daemon`, `gdm`) is pruned from the image. SDDM replaces GDM.

Everything else carries over: `sideral-cli-tools`, three-shell parity, `ujust` recipes (`chsh`, `chezmoi`, `apply-defaults`, `gdrive-setup`, `gdrive-remove`, `tools`, `update`), `/etc/user-motd`, `rclone-gdrive.service`, rootless podman, kubernetes module. The new recipes are `ujust niri` and `ujust theme`.

**To roll back** if niri doesn't fit: reboot and pick the previous deployment at the bootloader, or:
```bash
rpm-ostree rollback
systemctl reboot
```
That returns you to the last GNOME-era deployment stored on disk. For a permanent fork-and-revert, use `git checkout <pre-niri-sha>` in a fork of this repo.

## Repo layout

```
sideral/
├── Justfile                         # build / rebase / lint
├── os/                              # everything that lands in the OCI image
│   ├── Containerfile                # image recipe (FROM silverblue-main:43)
│   ├── lib/
│   │   ├── build.sh                 # orchestrator: prune GNOME, register repos, per-module install loop
│   │   └── build-rpms.sh            # inline rpmbuild: walks os/modules/*/rpm/*.spec
│   └── modules/                     # each capability owns one directory
│       ├── desktop-niri/    packages.txt (niri, Noctalia, ghostty…) + sddm-silent-install.sh + src/
│       │                    rpm/sideral-niri-defaults.spec
│       ├── shell-tools/     starship-install.sh + packages.txt (CLI binaries)
│       ├── shell-init/      src/ (profile.d, fish/conf.d, zsh, user-motd, 60-custom.just)
│       │                    rpm/sideral-shell-ux.spec
│       ├── meta/            src/ (/etc/os-release, yum.repos.d)  rpm/sideral-base.spec
│       ├── containers/      packages.txt (podman-docker, podman-compose)
│       ├── kubernetes/      packages.txt + profile.d snippet  rpm/sideral-kubernetes.spec
│       ├── flatpaks/        remotes.sh + packages.txt  rpm/sideral-flatpaks.spec
│       ├── fonts/           packages.txt + font-install.sh
│       ├── nvidia/          apply.sh (kargs + modprobe + app-profiles + env + niri drop-in)
│       └── signing/         src/ (/etc/containers/policy.json)  rpm/sideral-signing.spec
├── iso/                             # live-installer assets consumed by titanoboa
└── .github/workflows/build.yml      # CI: build, tag, push to ghcr.io, cosign keyless
```

## Forking this repo

Want to run your own variant?

1. Fork or copy the repo, push to your own GitHub:
   ```bash
   gh repo create sideral --public --source . --remote origin --push
   ```
2. Wait ~30 min for the `build-sideral` workflow. It builds two bootc OCI image variants in parallel (`sideral` open-source and `sideral-nvidia` proprietary-drivers), runs semantic-release (which cuts a GitHub Release with changelog), builds a single installer ISO with titanoboa that auto-detects GPU at install time and pulls the matching variant from ghcr.io, and uploads the ISO to your Cloudflare R2 bucket under a constant `Sideral x86_64.iso` key.
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

sideral ships a default dotfile set at `/usr/share/sideral/chezmoi/` — niri config, Noctalia settings, matugen config + templates, shell configs for bash/zsh/nushell, and a mise toolchain. These are applied automatically on your first login. After `rpm-ostree upgrade`, pull in any new defaults:

```bash
ujust apply-defaults
```

chezmoi compares the image source against your `$HOME`. Files you haven't customized update silently; files you've changed get a diff prompt so you decide what to keep.

### Bring your own dotfiles

You can also manage your own dotfiles from a personal git repo — completely independent of the image defaults:


```bash
chezmoi init --apply https://github.com/<you>/dotfiles
```

That clones the repo to `~/.local/share/chezmoi/` and renders every templated file into your `$HOME`. Edit-loop afterward:

```bash
chezmoi edit ~/.bashrc        # opens the source file in $EDITOR
chezmoi diff                  # show pending changes
chezmoi apply                 # write them to $HOME
```

Why chezmoi? Static Go binary, no daemon, plays well with rpm-ostree (no `/nix` store, no daemon, no SELinux dance), templating + per-host conditionals via `.chezmoi.osRelease.variantId`, and 17 first-class secret backends (age, gpg, libsecret, 1Password, Bitwarden, sops, …) — all surfaced as Go template funcs. See `.specs/features/chezmoi-home/` for sideral's full reasoning.

## CLI toolset — sideral-cli-tools

The `sideral-cli-tools` meta-RPM declares `Requires:` on 13 CLI tools + VS Code, with `starship` shipped alongside as a baked-in binary:

| Tool | Source |
| --- | --- |
| `chezmoi` | Fedora main |
| `mise` | mise.jdx.dev/rpm (persistent repo, `rpm-ostree upgrade` pulls updates) |
| `atuin`, `fzf`, `bat`, `eza`, `ripgrep`, `zoxide`, `gh`, `git-lfs`, `gcc`, `make`, `cmake` | Fedora main |
| `code` (VS Code) | packages.microsoft.com (persistent repo) |
| `starship` | Latest upstream binary fetched from `github.com/starship/starship/releases/latest` and sha256-verified at image build. No Fedora RPM exists for starship; the third-party `atim/starship` COPR was evaluated and skipped — on an atomic image, "always-latest at rebuild" is simpler than tracking a packager hop. Not RPM-tracked, so it's not in `Requires:`. |

All present after `rpm-ostree rebase`. To opt out (slimmer derivative): `sudo rpm-ostree override remove sideral-cli-tools`. Individual tools can also be removed: `sudo rpm-ostree override remove zoxide`. (starship can't be `override remove`'d since it has no RPM owner; remove it from `os/build.sh` and rebuild instead.) The shell-init script in `sideral-shell-ux` `command -v`-guards each integration so removing any single tool is safe.

mise toolchains (node, bun, python, go, etc.) are *user-level* — declare them in your chezmoi'd `~/.config/mise/config.toml`. sideral doesn't ship a default; pick what you use.

## Iterating on dotfiles

Layer choice:

- **System-wide** (dconf keybinds, repo files, systemd units, os-release, GNOME extensions) → `os/packages/sideral-*/src/etc/` or `os/features/<feature>/`. Rebuild image + rebase.
- **User-level** (shell, prompt, git, mise toolchains, per-program configs) → your chezmoi'd dotfiles repo. Run `chezmoi apply` to materialize without rebooting.

## Why not nix?

sideral *did* have a nix + home-manager user layer in flight — see `.specs/features/nix-home/spec.md`. It was implemented locally then retired before VM verification on 2026-05-01. Three documented frictions specifically affect Fedora atomic 42+: composefs vs the nix-installer ostree planner ([nix-installer#1445](https://github.com/DeterminateSystems/nix-installer/issues/1445)), SELinux mislabel of `/nix` store paths ([#1383](https://github.com/DeterminateSystems/nix-installer/issues/1383), open since 2023), and `/nix` + nix-daemon disappearing after `rpm-ostree upgrade` on F42+ (Universal Blue forum reports). silverblue-main:43 is in the impact zone for all three. The chezmoi-home pivot gets the declarative-on-first-boot UX without the nix-shaped failure modes. See `.specs/features/chezmoi-home/context.md` D-01 for the full rationale.

## Rollback

If a rebase breaks: reboot, pick the previous deployment at GRUB, or:
```bash
rpm-ostree rollback
systemctl reboot
```
