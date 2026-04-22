# athena-os

Personal Bluefin-DX derivative with Hyprland, custom AGS bar, and a curated CLI stack.

## What's in this image

| Layer | What |
|---|---|
| **Base** | `ghcr.io/ublue-os/bluefin-dx:stable` |
| **Hyprland stack** | hyprland, hyprpaper, hyprlock, hypridle, hyprpolkitagent, swww, swaync, waybar, rofi, wlogout, fuzzel |
| **AGS/Astal** | `astal`, `astal-libs`, plus **astal-gtk4 built from source** (not packaged) |
| **CLI stack** | gh, mise (rest — starship, btop, just, fzf, jq — come from the bluefin-dx base) |
| **Fonts** | Adobe Source Serif 4, Noto Color Emoji, Papirus icons |
| **Flatpaks** | None baked in. Install manually or re-add a manifest later. |

Edit `packages.txt` to change what's baked in. `build_files/build.sh` handles the source build + package installs in one layer.

## Editing what gets installed

Everything is organised **per feature** under `build_files/features/<name>/`:

```
build_files/
├── build.sh                          # orchestrator (COPR → features → cleanup)
└── features/
    ├── hyprland/
    │   ├── packages.txt              # compositor + bar/launcher/notif stack (waybar, rofi, wlogout, swaync, astal…)
    │   └── post-install.sh           # builds astal-gtk4 from source
    ├── desktop/packages.txt          # kitty / nautilus / gnome-control-center / utilities
    ├── devtools/packages.txt         # gh / mise
    └── fonts/packages.txt            # Source Serif 4 / Noto Emoji / Papirus
```

- Add/remove a package → edit the relevant `packages.txt`
- Add a whole new feature → create `features/<name>/packages.txt` + optional `post-install.sh`, then append the name to the `FEATURES=(…)` array in `build.sh`
- System-wide config files (anything you'd drop into `/etc/…`) → put them under `system_files/etc/…`; the Containerfile copies the tree verbatim into the image

## First-time setup

1. Create a GitHub repo and push:
   ```bash
   gh repo create athena-os --public --source . --remote origin --push
   ```
2. Wait ~10 min for the `build-athena-os` workflow to finish.
3. Rebase your host to the new image:
   ```bash
   rpm-ostree rebase ostree-unverified-registry:ghcr.io/<YOUR_USER>/athena-os:latest
   systemctl reboot
   ```
4. After reboot you're on your own OS.

## Iterating

- Change `packages.txt` / `flatpak-manifest` → commit → push → CI builds → rebase to latest (reboot).
- For **dotfiles** (everything in `~/.config`), manage separately — they iterate faster than the image should rebuild. Recommended: `chezmoi` or a plain git repo at `~/Code/dotfiles`.

## Local build + test (no push)

The `Justfile` wraps everything. Install `just` (already listed in `packages.txt`), then:

```bash
just            # list recipes
just build      # podman build locally
just lint       # shellcheck build scripts
just rebase     # rebase host to the locally-built image (followed by reboot)
just rollback   # back to previous deployment
just rebase-latest <gh-user>   # pull + rebase to CI-built image
```

Raw commands:
```bash
podman build -t localhost/athena-os:dev .
sudo rpm-ostree rebase ostree-unverified-image:containers-storage:localhost/athena-os:dev
systemctl reboot
```

## Rollback

If something breaks: reboot, select the previous deployment at GRUB, or:

```bash
rpm-ostree rollback
systemctl reboot
```

## mise toolchain

`/etc/mise/config.toml` ships with baseline tool versions (Java, Python, Rust, uv, gradle, android-sdk). After rebasing to the new image, run:

```bash
just mise-setup
# or directly: mise install
```

…to actually download & compile those tools into `~/.local/share/mise/`. Any tools listed in a project's `.mise.toml` or in your own `~/.config/mise/config.toml` will override the system defaults.
