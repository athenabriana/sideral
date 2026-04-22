# athens-os — Decisions

Discussion outcomes for ambiguities flagged in `spec.md`. Each row is the canonical answer for implementation.

## 1. Auto-update mechanism

**Decision:** Mirror bluefin's behaviour. **Verified: silverblue-main already ships `ublue-os-update-services-0.91`** as part of the base — no layering or extra COPR needed.
**Why:** User explicitly asked for "same bluefin behaviour". The package is already installed and its systemd timer is enabled by default in silverblue-main.
**Implementation:** Nothing to do. Just don't disable the existing service.

## 2. Desktop session

**Decision:** **Drop Hyprland entirely.** Desktop = GNOME Shell + tiling-shell (tiled-window management) + peer extensions (appindicator, dash-to-panel, bazaar-integration, rounded-window-corners).
**Why:** User chose tiling-shell for simplicity over pop-shell / forge. GNOME is already the primary session in silverblue-main; tiling-shell layers a Windows-11-like snap-assist flow on top. Hyprland is redundant.
**Implementation:**
- Remove from `packages.txt`: hyprland, hyprpaper, hyprlock, hypridle, hyprpolkitagent, hyprcursor, hyprshot, xdg-desktop-portal-hyprland, rofi-wayland, wlogout, SwayNotificationCenter, astal*, aylurs-gtk-shell2, brightnessctl, playerctl, cliphist, grim, slurp, swappy
- Delete `home/.config/{hypr, ags, rofi, wlogout}` from the monorepo
- Delete `build_files/features/hyprland/` entirely

## 3. Repo rename

**Decision:** Rename repo folder `~/Code/athena-os` → `~/Code/athens-os`. Image name is `athens-os`.

## 4. Default wallpapers

**Decision:** **Do not ship** defaults in `/etc/skel`. User supplies their own per machine.

## 5. Flatpak strategy

**Decision:** Mirror bluefin — Flathub remote enabled (inherited from silverblue-main) + systemd one-shot service auto-installs a curated list on first boot.
**Why:** User asked for "same bluefin behaviour for flatpaks". Keeps images reproducible while honoring "no hand-install after rebase".
**Curated list (7 flatpaks — Bazaar, Obsidian, Chrome, Chromium all dropped; Helium replaces Chrome via RPM, see decision #8):**
```
flathub/com.github.tchx84.Flatseal
flathub/io.github.flattool.Warehouse
flathub/com.mattjakeman.ExtensionManager
flathub/io.podman_desktop.PodmanDesktop
flathub/com.ranfdev.DistroShelf
flathub/net.nokyan.Resources
flathub/it.mijorus.smile
```
**Explicitly excluded:** Discord, Slack (comms), Pinta (creative), Stremio (media), DevToolbox, Ignition, Clapgrep, Impression, embellish, Evolution, Obsidian, Chrome, Chromium — all dropped on user request.

## 6. GNOME Shell extensions

**Decision:** Layer 3 via RPM + install 2 at image-build time + drop many others.

**Layer via RPM (Fedora main + ublue-os/packages COPR already enabled in silverblue-main):**
- `gnome-shell-extension-appindicator` (Fedora main — system tray)
- `gnome-shell-extension-dash-to-panel` (Fedora main — taskbar)
- `bazaar` (ublue-os/packages COPR — bundles the Bazaar app + Shell extension + GNOME search provider)

**Install at image-build time** from extensions.gnome.org (bluefin-style, option B): a script in `build_files/features/gnome-extensions/post-install.sh` that queries `extensions.gnome.org/extension-info/?uuid=<uuid>&shell_version=<N>` at build to resolve the latest compatible `.v<pk>.shell-extension.zip`, downloads it into `/usr/share/gnome-shell/extensions/<uuid>/`, compiles schemas with `glib-compile-schemas --strict`, and merges into the system schema cache. Build deps (`glib2-devel`) installed then removed in the same script.

Extensions installed this way:
- `tilingshell@ferrarodomenico.com`
- `rounded-window-corners@fxgn` (fxgn fork — not the older pixeledplay one)

Rationale vs the other options considered:
- **Not first-boot runtime install** (simpler but brittle — fails if offline on first boot)
- **Not git-submodule vendoring** (bluefin-exact but more repo complexity for 2 extensions)

**Drop:**
- `blur-my-shell` — user disabled it; no longer needed
- `awesome-tiles` — redundant with tiling-shell
- `zorin-menu` — Zorin-OS specific, doesn't belong on a Fedora image
- `tailscale@joaophi.github.com` — requires tailscale daemon; separate concern, defer
- `user-theme` — not needed by user
- `caffeine`, `dash-to-dock`, `gsconnect`, `logomenu`, `search-light`, `background-logo` — bluefin enables these; we skip

**Note on Bazaar duplication:** since `bazaar` RPM includes the app GUI, we **drop `io.github.kolunmi.Bazaar` from the flatpak manifest** to avoid duplicate installations. Final flatpak list: 9 apps (see decision #5).

**Pre-configured defaults:** Ship captured dconf settings as `/etc/dconf/db/local.d/00-athens-gnome-shell` (dash-to-panel icon/position, appindicator layout, rounded-corners radius, tiling-shell tiles config, bazaar search-provider toggle). Every user gets these defaults; they can override per-user.

## 7. Tailscale (deferred)

**Decision:** Defer to a later spec. Not in athens-os P1-P3.

## 8. Package scope — surgical, not a full bluefin fork

**Decision:** Earlier intent to "add everything bluefin/bluefin-dx adds" was trimmed back after walking through individual packages. The final athens-os layer is **surgical**: a short list of RPMs the user explicitly named + our athens-os-specific extras. Bluefin's full FEDORA_PACKAGES list is **not** replicated.

### RPMs to layer on top of silverblue-main

**GNOME extensions (from Fedora main):**
- `gnome-shell-extension-appindicator`
- `gnome-shell-extension-dash-to-panel`

**Bazaar app store (from `ublue-os/packages` COPR, already enabled in base):**
- `bazaar` — bundles the Bazaar app GUI + `bazaar-integration@kolunmi.github.io` Shell extension + GNOME search provider

**Dev tooling (user-approved surgical list):**
- `gcc`, `make`, `cmake` — native build deps for npm/python/rust native bindings
- `git-credential-libsecret` — git HTTPS creds via GNOME Keyring
- `git-subtree` — vendored-dep git workflow
- `git-lfs` — large-file support (silently breaks any LFS-tracked repo if missing)

**Editor (VS Code — mirrors bluefin-dx pattern):**
- `code` from Microsoft's `packages.microsoft.com/yumrepos/vscode` repo (shipped as `system_files/etc/yum.repos.d/vscode.repo`, **kept enabled** so `rpm-ostree upgrade` pulls MS's weekly VS Code releases directly — differs from bluefin's approach of disabling after install).
- `system_files/usr/lib/systemd/user/athens-vscode-setup.service` + enable symlink — on first user login, installs 3 extensions (`ms-vscode-remote.remote-ssh`, `ms-vscode-remote.remote-containers`, `ms-azuretools.vscode-containers`) via `code --install-extension`. Idempotent via `~/.cache/athens/vscode-setup-done` marker.

**Terminal:** Ptyxis (shipped by silverblue-main base) is the terminal. **Kitty dropped** — no layering, no dotfile.

**CLI (mise doesn't package it):**
- `gh` — GitHub CLI

**Browser (RPM, not flatpak — replaces Chrome):**
- `helium-bin` from `imput/helium` COPR — Helium browser v0.11+ (privacy-focused Chromium fork by Imput)
- **COPR stays enabled in the shipped image** (unlike our extension/build COPRs which are disabled after install). This lets `rpm-ostree upgrade` pull new Helium releases directly from the COPR between image rebuilds.

**GNOME quality-of-life (adopted from bluefin's strong-recs):**
- `gnome-tweaks` — GUI for GNOME advanced settings
- `adw-gtk3-theme` — Adwaita-style theme port for GTK3 apps (visual consistency with GTK4)
- `fastfetch` — fast `neofetch` replacement

**Shell prompt (mirrors bluefin pattern):**
- `starship` (Fedora main) — powered-up prompt
- Activation lives in `/etc/skel/.bashrc` (not `/etc/profile.d/`) so both host shells **and distrobox shells** pick it up automatically (HOME is mounted in every distrobox).

**Mise — Pattern A (user-level install, auto-triggered on first login):**
- Image does **not** ship a mise binary in `/usr/`.
- `/usr/lib/systemd/user/athens-mise-install.service` runs **once per user** on first graphical session:
  1. Downloads `mise.run`, installs to `~/.local/bin/mise` (if not already present)
  2. Eagerly installs `act`, `atuin`, `direnv` (the three CLI tools whose shell hooks run in every bash)
  3. Writes `~/.cache/athens/mise-setup-done` marker
- `ConditionPathExists=!%h/.cache/athens/mise-setup-done` keeps it idempotent; re-runs on next login if it previously failed.
- Enabled by default via `/usr/lib/systemd/user/default.target.wants/` symlink.
- HOME is shared with all distroboxes → one mise + atuin history DB + direnv bindings serve host + every container.
- Config at `/etc/skel/.config/mise/config.toml` declares **15 tools**:
  - **Language runtimes (11)** — android-sdk, bun, go, gradle, java-lts, kotlin, node-lts, python, rust, uv, zig: lazy-installed on first `node`, `python`, etc.
  - **CLI tools (4)** — act, atuin, direnv, pnpm: three eagerly installed via the systemd unit because they have shell hooks; pnpm lazy-installed.
- Activation in `/etc/skel/.bashrc`: starship init, mise activate, atuin init (Ctrl+R search + sync-ready history), direnv hook (per-project env).

**Fonts (adopted from bluefin's curation):**
- `cascadia-code-fonts` — Microsoft coding font
- `jetbrains-mono-fonts-all` — JetBrains Mono
- `adwaita-fonts-all` — Adwaita font variants
- `opendyslexic-fonts` — accessibility font (available if ever needed)
- (Plus Source Serif 4 + Source Sans 3 built from Adobe GitHub at image time — see existing decision)
- Default GNOME icon theme is sufficient; no `papirus-icon-theme`.

**Container runtime (bluefin-dx pattern — requires docker-ce repo):**
- `containerd.io` + `docker-ce` from **docker-ce-stable repo** (added via `dnf config-manager addrepo`). Fedora's `containerd` gets swapped out automatically.
- Rationale: user opted in despite already having podman; docker-ce compatibility gives seamless `docker` + `docker compose` CLI without alias tricks.

**Android tooling:**
- `android-tools` (Fedora main) — adb + fastboot

**Kernel debug / profiling (user override — full bluefin-dx debug stack):**
- `bcc`, `bpftop`, `bpftrace`, `sysprof`, `trace-cmd`, `tiptop`, `nicstat`, `iotop`, `udica`

**Note:** `containerd` (Fedora) is intentionally **not** listed — it conflicts with `containerd.io` (Docker). dnf handles the swap.

### Explicitly NOT layered

- `podman-compose`, `podman-docker`, `podman-tui` — user declined
- `flatpak-builder`, `p7zip`, `p7zip-plugins`, `yq`, `sqlite`, `glow`, `fastfetch` — not needed this pass
- Bluefin-dx virt stack (`libvirt`, `qemu-*`, `virt-manager`, `incus`, `lxc`, `cockpit-*`) — heavy, redundant with podman/distrobox
- `bcc`, `bpftrace`, `sysprof`, `trace-cmd`, `rocm-*` — niche
- `containerd.io`, `docker-ce` — redundant with podman
- `android-tools`, `cascadia-code-fonts` — not user's profile
- `fish`, `zsh`, `starship`, `bash-color-prompt`, `ibus-mozc`, `mozc`, `opendyslexic-fonts`, `samba-*`, `krb5-workstation`, `adcli` — not part of user's workflow
- `tailscale` — deferred

### Athens-os specifics (non-RPM, scripted)

- First-boot script: install `tilingshell@ferrarodomenico.com` + `rounded-window-corners@fxgn` from extensions.gnome.org
- `fonts/post-install.sh`: Source Serif 4 + Source Sans 3 from Adobe GitHub releases
- `devtools/post-install.sh`: `mise` binary from `mise.run`

### /etc + /usr files shipped

- `/etc/dconf/db/local.d/00-athens-gnome-shell` — dash-to-panel + tiling-shell + rounded-corners defaults (captured from user's current machine)
- `/etc/dconf/db/local.d/00-athens-focus` — `focus-mode='sloppy'`, `auto-raise=false`
- `/etc/dconf/db/local.d/10-athens-keybinds` — 5 custom shortcuts + WM overrides
- `/etc/flatpak-manifest` + `/etc/systemd/system/flatpak-install.service` — 7-app auto-install on first boot
- `/etc/os-release` rewritten with `ID=athens-os`, `NAME="Athens OS"`
- `/etc/yum.repos.d/docker-ce.repo` — so `rpm-ostree upgrade` pulls containerd.io + docker-ce updates
- `/etc/yum.repos.d/vscode.repo` — so `rpm-ostree upgrade` pulls MS's VS Code releases
- `/usr/lib/systemd/user/athens-mise-install.service` + enable symlink — auto-installs mise at first user login
- `/usr/lib/systemd/user/athens-vscode-setup.service` + enable symlink — auto-installs 3 VS Code extensions at first user login

### /etc/skel shipped (user defaults)

- `home/.bashrc` — starship activation + mise PATH + `mise activate bash`
- `home/.config/mise/config.toml` — 11-tool toolchain

### Size reality check

This is a **lean** layer — approximately 10-15 additional RPMs + 2 first-boot extension installs + 2 source-built font packs. Image should be within ~200MB of silverblue-main base. Much smaller than bluefin-dx.

### Shells

Bash (from base) remains the default. No fish/zsh/starship layered. `/etc/profile.d/mise.sh` handles mise activation only.

## 9. Window focus behaviour

**Decision:** Focus follows mouse (sloppy), no auto-raise.
**Why:** With tiling-shell, windows don't overlap, so auto-raise is irrelevant; sloppy focus gives the hover-to-focus feel without the jitter of `mouse` mode.
**Implementation:** Ship `system_files/etc/dconf/db/local.d/00-athens-focus` with:
```ini
[org/gnome/desktop/wm/preferences]
focus-mode='sloppy'
auto-raise=false
```
