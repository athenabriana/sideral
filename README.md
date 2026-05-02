<h1 align="center">sideral</h1>

<p align="center">
  <em>Personal Fedora atomic desktop — GNOME + tiling-shell, Zen Browser, chezmoi-driven dotfiles, mise toolchain.</em>
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

After reboot the image is fully wired — Zen Browser, starship prompt, mise, atuin, zoxide, fzf, gh, VS Code are all on `$PATH`. The curated flatpak set (Zen + 7 GNOME quality-of-life apps) is preinstalled at image build, so it's there immediately — no first-boot download wait. Bring your own dotfiles with `chezmoi init --apply <your-repo>` (see [Set up dotfiles](#set-up-dotfiles)).

---

Built directly on `ghcr.io/ublue-os/silverblue-main:43`. Ships GNOME + tiling-shell with a curated flatpak set (preinstalled at image build), a `sideral-cli-tools` meta-RPM that pulls 14 day-to-day CLI tools + VS Code, Zen Browser as the default browser (Flatpak from Flathub), and docker-ce for day-to-day dev. User dotfiles are managed by [chezmoi](https://chezmoi.io) — sideral provides the binary; you provide the dotfiles repo.

## What's in the image

| Layer | Contents |
| --- | --- |
| **Base** | `ghcr.io/ublue-os/silverblue-main:43` (open-source GPU); `silverblue-main-nvidia:43` for the `sideral-nvidia` variant. ISO installer reads `lspci` and pulls the matching variant at install time. |
| **Desktop** | GNOME Shell (default from base) + 4 extensions: appindicator, dash-to-panel, tilingshell, rounded-window-corners |
| **App store** | GNOME Software with `gnome-software-rpm-ostree` plugin (rpm-ostree updates) and the built-in flatpak plugin. Defaults bias toward flatpak via `org.gnome.software.packaging-format-preference`. |
| **Browser** | [Zen Browser](https://zen-browser.app) (`app.zen_browser.zen` from Flathub). Preinstalled at image build; new releases pulled by the standard `flatpak update` cadence. |
| **Editor** | `code` (VS Code) via Microsoft RPM repo at `packages.microsoft.com/yumrepos/vscode` — Remote-SSH and Remote-Containers extensions install from the marketplace on first launch |
| **Containers** | `docker-ce` stack (podman inherited from base) |
| **CLI toolset** | `sideral-cli-tools` meta-RPM pulls: `chezmoi`, `mise`, `atuin`, `fzf`, `bat`, `eza`, `ripgrep`, `zoxide`, `gh`, `git-lfs`, `gcc`, `make`, `cmake`. `starship` is baked into `/usr/bin` from the latest upstream release at image build (no Fedora RPM). All present at `$PATH` after rebase. |
| **Shell-init wiring** | `/etc/profile.d/sideral-cli-init.sh` (shipped by `sideral-shell-ux`) sources starship, atuin, zoxide, mise, and fzf integrations into every interactive bash shell. Each line is `command -v`-guarded. |
| **Fonts** | Cascadia Code, JetBrains Mono, Adwaita, OpenDyslexic (Fedora main) + Source Serif 4, Source Sans 3 (Adobe GitHub) |
| **User dotfiles** | Bring your own with `chezmoi init --apply <your-repo>` — see below. sideral ships no default dotfiles tree. |
| **Flatpaks (preinstalled at image build)** | Zen Browser, Flatseal, Warehouse, Extension Manager, Podman Desktop, DistroShelf, Resources, Smile (all from Flathub). Single curated remote: `flathub`. |

## Repo layout

```
sideral/
├── Justfile                         # build / rebase
├── os/                              # everything that lands in the OCI image
│   ├── Containerfile                # image recipe (FROM silverblue-main:43)
│   ├── build.sh                     # orchestrator: register persistent repos + per-feature install loop
│   ├── features/
│   │   ├── cli/              packages.txt → 12 Fedora-main CLI tools (chezmoi, atuin, fzf, bat, eza, ripgrep, zoxide, gh, git-lfs, gcc, make, cmake); starship is fetched as a binary in build.sh
│   │   ├── gnome/            packages.txt → gnome-software + extensions + adw-gtk3-theme + fastfetch
│   │   ├── gnome-extensions/ post-install.sh → tilingshell + rounded-window-corners from extensions.gnome.org
│   │   ├── container/        packages.txt → docker-ce + containerd.io + buildx + compose
│   │   └── fonts/            packages.txt + post-install.sh → Fedora font RPMs + Source Serif 4 / Sans 3
│   └── packages/                    # sideral-* RPM sources (built inline by build-rpms.sh)
│       ├── sideral-base       → /etc/os-release, distrobox.conf, yum.repos.d/{docker-ce,mise,vscode}.repo
│       ├── sideral-cli-tools  → meta-RPM: Requires: 13 RPM-packaged CLI tools + code (starship binary baked separately)
│       ├── sideral-dconf      → /etc/dconf/db/local.d/* + profile/user
│       ├── sideral-flatpaks   → flatpak remotes + manifest + every-boot self-heal service
│       ├── sideral-services   → placeholder for future systemd units
│       ├── sideral-shell-ux   → /etc/profile.d/sideral-cli-init.sh + sideral-onboarding.sh
│       └── sideral-signing    → /etc/containers/policy.json
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

sideral ships [chezmoi](https://chezmoi.io) but no default dotfiles tree — you bring your own. After your first login, point chezmoi at your dotfiles repo:

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
