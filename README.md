# athena-os

Personal Bluefin-DX derivative with Hyprland, custom AGS bar, and a curated CLI stack.

## What's in this image

| Layer | What |
|---|---|
| **Base** | `ghcr.io/ublue-os/bluefin-dx:stable` |
| **Hyprland stack** | hyprland, hyprpaper, hyprlock, hypridle, hyprpolkitagent, swww, swaync, waybar, rofi, wlogout, fuzzel |
| **AGS/Astal** | `astal`, `astal-libs`, plus **astal-gtk4 built from source** (not packaged) |
| **CLI stack** | fish, starship, fzf, zoxide, eza, bat, ripgrep, fd, delta, btop, neovim, gh, just, mise |
| **Fonts** | Adobe Source Serif 4, Noto Color Emoji, Papirus icons |
| **Flatpaks** | Zen, Discord, Spotify, Obsidian, Signal, Telegram, Evolution, Flatseal (auto-installed on first boot) |

Edit `packages.txt` and `files/etc/flatpak-manifest` to change what's baked in. `build_files/build-astal-gtk4.sh` handles the source build.

## Editing what gets installed

- **RPMs** → `packages.txt` (one package per line)
- **Flatpaks** → `files/etc/flatpak-manifest` (one ref per line)
- **Anything custom** → drop a new script into `build_files/` and reference it in `Containerfile`

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
