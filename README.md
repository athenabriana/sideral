<h1 align="center">sideral</h1>

<p align="center">
  <em>Personal NixOS atomic desktop — niri scrollable-tiling compositor, Noctalia shell, Zen Browser, declarative via flakes + home-manager, mise toolchain.</em>
</p>

<p align="center">
  <a href="https://github.com/athenabriana/sideral/releases/latest"><img src="https://img.shields.io/github/v/release/athenabriana/sideral?label=Latest&style=for-the-badge&logo=nixos&logoColor=white&labelColor=294172&color=3584e4" alt="Latest release"></a>
  <a href="https://github.com/athenabriana/sideral/actions/workflows/build.yml"><img src="https://img.shields.io/github/actions/workflow/status/athenabriana/sideral/build.yml?branch=main&style=for-the-badge&logo=githubactions&logoColor=white&label=Build&labelColor=294172" alt="Build status"></a>
  <a href="https://github.com/athenabriana/sideral/blob/main/LICENSE"><img src="https://img.shields.io/github/license/athenabriana/sideral?style=for-the-badge&logo=opensourceinitiative&logoColor=white&label=License&labelColor=294172&color=3584e4" alt="License"></a>
</p>

## Quick start

Two ways to try sideral.

### Boot from USB (try before installing)

<p align="center">
  <a href="https://sideral.athenabriana.com/sideral_x86_64.iso"><img src="https://img.shields.io/badge/%E2%AC%87%20Download%20ISO-latest-3584e4?style=for-the-badge&logo=nixos&logoColor=white&labelColor=1a2a4a" alt="Download ISO" height="44"></a>
</p>

The button starts the download immediately — single ISO (~1.5 GiB target), hosted on Cloudflare R2. Verify the checksum and flash:

```bash
curl -LO https://sideral.athenabriana.com/sideral_x86_64.iso
curl -LO https://sideral.athenabriana.com/sideral_x86_64.iso.sha256
sha256sum -c sideral_x86_64.iso.sha256
sudo dd if=sideral_x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Or use Etcher / Impression / GNOME Disks. Boot the USB and you land **directly in the calamares installer** with sideral branding — no live niri session, no `liveuser` autologin. Calamares walks you through partition + user setup; a pre-install hook reads `lspci` and bakes the matching variant (open-source GPU vs NVIDIA) into the target's `/etc/nixos/configuration.nix`. After install, reboot, log in, and niri+Noctalia comes up with the full sideral environment.

### Rebuild an existing NixOS install against the sideral flake

Pick the variant that matches your GPU. The ISO installer auto-detects via `lspci`; for manual rebuild you choose explicitly:

```bash
# Open-source GPU stack (AMD / Intel / nouveau)
sudo nixos-rebuild switch --upgrade --flake github:athenabriana/sideral#sideral

# NVIDIA proprietary drivers (Maxwell / GTX 900-series and newer)
sudo nixos-rebuild switch --upgrade --flake github:athenabriana/sideral#sideral-nvidia
```

After the switch the system is fully wired — niri session in SDDM, Noctalia bar/launcher/lock, Zen Browser flatpak, starship prompt, mise, atuin, zoxide, fzf, gh, VS Code all on `$PATH`. The curated flatpak set is materialised declaratively by `nix-flatpak` at activation. Default shell and compositor configs are seeded by home-manager — no first-login bootstrap. Optionally bring your own dotfiles with `chezmoi init --apply <your-repo>` (see [Set up dotfiles](#set-up-dotfiles)).

---

Built directly on `nixpkgs/nixos-25.11`. Ships the [niri](https://github.com/YaLTeR/niri) scrollable-tiling compositor with [Noctalia](https://github.com/noctalia-dev/noctalia-shell) as the desktop shell, a curated set of CLI tools sourced from nixpkgs (chezmoi, mise, atuin, fzf, bat, eza, ripgrep, zoxide, gh, git-lfs, helix, nushell, vscode, …), Zen Browser (Flathub via `nix-flatpak`), rootless podman with docker compatibility, and matugen-driven wallpaper theming. User dotfiles are seeded by [home-manager](https://github.com/nix-community/home-manager).

## What's in the image

| Layer | Contents |
| --- | --- |
| **Base** | `nixpkgs/nixos-25.11` stable channel (open-source GPU stack from kernel: amdgpu/i915/xe/nouveau). The `sideral-nvidia` host adds the proprietary NVIDIA driver. ISO installer reads `lspci` and bakes the matching host config into the target. |
| **Compositor** | [niri](https://github.com/YaLTeR/niri) — Rust-based scrollable-tiling Wayland compositor. PaperWM-style column navigation. No GNOME/Mutter. |
| **Shell** | [Noctalia](https://github.com/noctalia-dev/noctalia-shell) — Quickshell-based bar, notification overlay, app launcher, lock screen, idle handler, control center, and wallpaper picker. Pinned to upstream `4.7.6` / `noctalia-qs 0.0.12` (in-tree derivations under `pkgs/`). |
| **Greeter** | SDDM with the [SilentSDDM](https://github.com/uiriansan/SilentSDDM) theme. |
| **Terminal** | [ghostty](https://ghostty.org) — niri config binds `Mod+T`. |
| **Theming** | matugen (`pkgs.matugen`). `njust theme <wallpaper>` regenerates Material 3 palette → ghostty + helix. Noctalia drives its own bar/launcher/notification recolor via its built-in wallpaper picker. |
| **Browser** | [Zen Browser](https://zen-browser.app) (`app.zen_browser.zen` from Flathub). Materialised declaratively by `nix-flatpak`. |
| **Editor** | `code` (VS Code) from nixpkgs (`allowUnfree = true`). `hx` (Helix) from nixpkgs. |
| **Containers** | Rootless podman + `dockerCompat` + podman-compose. `docker` CLI resolves to podman. No daemon. |
| **CLI toolset** | `chezmoi`, `mise`, `atuin`, `fzf`, `bat`, `eza`, `ripgrep`, `zoxide`, `gh`, `git-lfs`, `gcc`, `make`, `cmake`, `helix`, `nushell`, `zsh`, `rclone`, `starship`, `vscode` — all from nixpkgs `nixos-25.11`. |
| **Shell-init wiring** | `programs.{starship,atuin,zoxide,fzf,bat,eza,nushell}.enable` via home-manager seed each user's shell with starship + atuin + zoxide + mise + fzf integrations. `~/.bashrc` / `~/.zshrc` carry the AI-agent-alias-suppression guard byte-identical to the Fedora flavor. |
| **Fonts** | Cascadia Code, JetBrains Mono, Adwaita, OpenDyslexic, Source Serif, Source Sans, Noto + Noto-Emoji + Noto-CJK — all from nixpkgs. |
| **User dotfiles** | Seeded by home-manager (`home.file` + `xdg.configFile`) at activation — no first-login bootstrap. Bring your own personal dotfiles with `chezmoi init --apply <your-repo>` — see below. |
| **Flatpaks (preinstalled)** | Zen Browser, Bazaar, Flatseal, Extension Manager, Podman Desktop, DistroShelf, Resources, Smile, Web App Hub, Pika Backup, Junction (all from Flathub). Single curated remote: `flathub`. Managed declaratively by [`nix-flatpak`](https://github.com/gmodena/nix-flatpak) — drop a ref from the manifest and the next `nixos-rebuild switch` uninstalls it. |

## Default niri keybinds

| Key | Action |
|---|---|
| `Mod+T` | ghostty terminal |
| `Mod+Space` | Noctalia launcher |
| `Mod+F` | file manager (nautilus) |
| `Mod+M` | maximize column |
| `Mod+Q` | close window |
| `Mod+Tab` | toggle overview |
| `Mod+Left / Right` | focus column left / right |
| `Mod+Up / Down` | focus window up / down |
| `Mod+Shift+Left / Right` | move column left / right |
| `Mod+− / =` | cycle column width preset back / forward |
| `Mod+1–9` | switch workspace |
| `Mod+Shift+1–9` | move window to workspace |
| `Print` | screenshot region → clipboard |
| `Shift+Print` | full-screen screenshot → clipboard |

Run `njust niri` for the full cheatsheet. Override keybinds in `~/.config/niri/config.kdl` — home-manager seeds the file on first activation; edit it directly afterward.

## Theming

```bash
njust theme ~/Pictures/wallpaper.jpg
```

Regenerates a Material 3 palette from the wallpaper and writes:
- `~/.config/ghostty/config-matugen` — add `config-file = ~/.config/ghostty/config-matugen` to your ghostty config
- `~/.config/helix/themes/sideral.toml` — set `theme = "sideral"` in `~/.config/helix/config.toml`

For the bar / launcher / notifications: use Noctalia's built-in wallpaper picker — it drives its own matugen pipeline.

## Migrating from the Fedora flavor

There is no in-place upgrade path from Fedora-flavor sideral (on `main`) to NixOS-flavor sideral. NixOS owns `/`, `/boot`, the bootloader entries, the package store layout, and the user activation system — none of which compose with rpm-ostree's deployment graph. To migrate:

1. Back up `~/` (or anything outside `~` you care about) to external storage.
2. Flash the sideral NixOS ISO (link above) and install fresh on the same disk.
3. Restore your data into `~/`. Re-run `chezmoi init --apply <your-repo>` if you bring your own dotfiles repo.

Configurations carry over byte-identical between the two flavors — niri config, Noctalia settings, ghostty config, mise toolchain, nushell config, matugen templates, kanata `.kbd` are the same files in both branches.

## Repo layout

```
sideral/
├── flake.nix                          # inputs (nixpkgs, home-manager, nix-flatpak) + outputs
├── flake.lock                         # pinned commits for every input
├── Justfile                           # `just build` / `just rebase` / `just build-iso`
├── hosts/                             # per-variant entry points (thin wrappers)
│   ├── common.nix                     # shared module-import list
│   ├── sideral.nix                    # open-source GPU host
│   ├── sideral-nvidia.nix             # NVIDIA host
│   └── sideral-iso.nix                # installer-only ISO host (calamares + branding)
├── modules/                           # each capability owns one directory
│   ├── base/          /etc/os-release identity + containers/policy.json
│   ├── cli-tools/     systemPackages: chezmoi/mise/atuin/eza/bat/rg/zoxide/gh/helix/nushell/...
│   ├── fonts/         fonts.packages
│   ├── services/      podman + dockerCompat + flatpak + distrobox
│   ├── kubernetes/    kubectl + kind + helm + KIND_EXPERIMENTAL_PROVIDER env
│   ├── niri-defaults/ niri + SDDM + matugen + ghostty + kanata + IME + SilentSDDM theme
│   ├── shell-ux/      /etc/zshrc + /etc/user-motd + njust wrapper + sideral.just + rclone-gdrive user unit
│   ├── flatpaks/      11-entry curated set via nix-flatpak
│   ├── dotfiles/      home-manager module — xdg.configFile + home.file + programs.* enables
│   └── nvidia/        gated NVIDIA stack — videoDrivers + kargs + modprobe + env + niri drop-in
├── pkgs/                              # in-tree derivations
│   ├── noctalia-shell/                # noctalia-dev/noctalia-shell @ v4.7.6
│   ├── noctalia-qs/                   # noctalia-dev/noctalia-qs @ v0.0.12
│   └── silent-sddm/                   # uiriansan/SilentSDDM @ v1.4.0
├── iso/                               # calamares branding + wizard config + pre-install hook
│   ├── calamares/branding/sideral/
│   ├── calamares/modules/{partition,users,welcome,finished,shellprocess-sideral}.conf
│   ├── calamares/settings.conf
│   └── pre-install.sh                 # lspci → write /etc/nixos/configuration.nix on target
└── .github/workflows/build.yml        # CI: nix flake check → build closures → build ISO → R2 upload → semantic-release
```

## Forking this repo

Want to run your own variant?

1. Fork or copy the repo, push to your own GitHub:
   ```bash
   gh repo create sideral --public --source . --remote origin --push
   ```
2. Wait ~15 min for the `build-sideral` workflow. It runs `nix flake check`, builds both `sideral` and `sideral-nvidia` system closures in parallel, runs semantic-release (which cuts a GitHub Release with changelog), builds the installer-only ISO via `nix build .#sideral-iso` (the ISO auto-detects GPU at install time and bakes the matching host into `/etc/nixos/configuration.nix` on the target), and uploads the ISO to your Cloudflare R2 bucket under a constant `sideral_x86_64.iso` key.
3. From then on, every push to `main` cuts a new versioned release; every night the workflow re-evaluates against the latest `nixos-25.11` channel commit and republishes if anything changed.

What lands in CI:

| Artifact | Where | Tags |
| --- | --- | --- |
| System closures (validated, not pushed) | GHA cache via `magic-nix-cache-action` | per-PR / per-branch |
| Installer ISO (latest only, single file) | Cloudflare R2 (`s3://<bucket>/sideral_x86_64.iso`) | constant key — overwrites |
| Changelog + version tag | GitHub Releases | `v<semver>` |

R2 secrets needed in repo settings: `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`. Update `R2_ENDPOINT`, `R2_BUCKET`, and `R2_PUBLIC_BASE` in `.github/workflows/build.yml` to match your account.

## Local build

```bash
just              # list recipes
just lint         # nix flake check + alejandra format check
just build        # nix build .#nixosConfigurations.sideral.config.system.build.toplevel
just build-nvidia # same for the nvidia variant
just build-iso    # nix build .#sideral-iso → result/iso/sideral_x86_64.iso
just rebase       # sudo nixos-rebuild switch --flake .#sideral
just rollback     # sudo nixos-rebuild switch --rollback
```

`nix` (with flakes) is required. On a fresh NixOS machine, flakes are pinned at install time via `nix.settings.experimental-features = [ "nix-command" "flakes" ]` (already set by `hosts/common.nix`). On non-NixOS hosts, follow the [nix-installer](https://github.com/DeterminateSystems/nix-installer) instructions and add `experimental-features = nix-command flakes` to `~/.config/nix/nix.conf`.

## Set up dotfiles

sideral seeds your `~/.config` directly at activation via home-manager — niri config, Noctalia settings, matugen config + templates, shell configs for bash/zsh/nushell, and a mise toolchain stub. There is no first-login bootstrap; the files appear the first time `nixos-rebuild switch` runs. After every system update they're refreshed automatically:

```bash
sudo nixos-rebuild switch --flake .#sideral
# or, for the published flake:
njust update
```

home-manager writes the seeded files via Nix-store symlinks, so they're read-only by default. To customize a single file, copy it out of the symlink target into your `~/` and edit it — home-manager backs up any pre-existing file as `<file>.hm-backup` before placing its symlink.

### Bring your own dotfiles

For users who want a personal git repo on top, chezmoi is the escape hatch — fully independent of the home-manager seed:

```bash
chezmoi init --apply https://github.com/<you>/dotfiles
# or:
njust chezmoi-init https://github.com/<you>/dotfiles
```

That clones to `~/.local/share/chezmoi/` and renders every templated file into your `$HOME`. chezmoi treats the home-manager-seeded files as "not under chezmoi management" and won't touch them on `chezmoi apply` unless you `chezmoi add` them explicitly. If you do, your repo wins. Edit-loop afterward:

```bash
chezmoi edit ~/.bashrc        # opens the source file in $EDITOR
chezmoi diff                  # show pending changes
chezmoi apply                 # write them to $HOME
```

Why home-manager + chezmoi as a hybrid? home-manager is the single-source-of-truth for the **image-default** dotfiles — they version with the system, materialise atomically, and roll back together. chezmoi is the per-user **escape hatch** — agnostic to package manager, supports templating, secret backends (age, gpg, libsecret, 1Password, Bitwarden, sops), and survives any future swap of the OS plumbing.

## CLI toolset

| Tool | Source |
| --- | --- |
| `chezmoi`, `mise`, `atuin`, `fzf`, `bat`, `eza`, `ripgrep`, `zoxide`, `gh`, `git-lfs`, `gcc`, `gnumake`, `cmake`, `helix`, `nushell`, `zsh`, `rclone`, `chromium`, `starship` | nixpkgs `nixos-25.11` (`environment.systemPackages` in `modules/cli-tools/default.nix`) |
| `vscode` | nixpkgs (requires `allowUnfree = true`, set in `hosts/common.nix`) |
| `carapace` | nixpkgs |
| Nushell plugins (`query`, `formats`, `gstat`) | nixpkgs `nushellPlugins.<name>` derivations, wired at `/etc/nushell/plugins/` |

To remove a tool: drop it from `modules/cli-tools/default.nix` and run `sudo nixos-rebuild switch --flake .#sideral`. The home-manager-seeded shell init (`programs.{starship,atuin,zoxide,fzf,bat,eza}.enable`) `command -v`-guards each integration so removing any single tool is safe.

mise toolchains (node, bun, python, go, etc.) are *user-level* — declare them in `~/.config/mise/config.toml`. sideral seeds an empty default; pick what you use.

## Iterating on dotfiles

Layer choice:

- **System-wide** (kernel kargs, systemd units, `/etc/...`, fonts, packages) → `modules/<capability>/default.nix` or `modules/<capability>/src/`. Run `nixos-rebuild switch` after each change.
- **User-level** (shell, prompt, git, mise toolchains, per-program configs) → either `modules/dotfiles/src/usr/share/sideral/chezmoi/` (image default for everyone), or your personal chezmoi repo on top.

The home-manager seed and personal chezmoi repo coexist cleanly — see [Bring your own dotfiles](#bring-your-own-dotfiles).

## Why NixOS?

The Fedora atomic flavor on `main` ships the same daily-driver experience via rpm-ostree-layered RPMs + a chezmoi seed materialized at first login. The NixOS flavor here gets three things the Fedora flavor can't:

1. **Atomicity & rollback are first-class** — every config change is a generation, every boot menu is a deployment, no rpm-ostree-vs-`/etc/yum.repos.d` impedance, no composefs gymnastics.
2. **Single source of truth for system + user** — one `nixos-rebuild switch --flake .#sideral` brings up the whole machine: kernel, drivers, services, packages, dotfiles, fonts, flatpaks. No sequencing of "RPM layer first, then chezmoi on first login."
3. **Declarative user layer is native** — home-manager's module system replaces the chezmoi seed cleanly. Dotfile contents move into HM modules; every config file (niri config.kdl, Noctalia settings.json, ghostty config, the matugen templates, the kanata `.kbd`, the nu `env.nu`/`config.nu`, the SilentSDDM theme) ships byte-for-byte unchanged.

The retired `nix-home` Fedora-overlay attempt (composefs + SELinux + `/nix`-disappears frictions) doesn't apply here — those failure modes are specifically about running nix on top of Fedora atomic 42+, not running NixOS as the OS.

## Rollback

If a rebuild breaks: reboot, pick the previous generation at the bootloader, or:
```bash
sudo nixos-rebuild switch --rollback
systemctl reboot       # only if kernel/initrd changed
```

For a permanent revert: `git checkout <pre-bad-sha>` in a fork, then `nixos-rebuild switch --flake .#sideral`.
