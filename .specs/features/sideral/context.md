# sideral — Decisions

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

**Decision:** Rename repo folder `~/Code/sideral` → `~/Code/sideral`. Image name is `sideral`.

## 4. Default wallpapers

**Decision:** **Do not ship** defaults in `/etc/skel`. User supplies their own per machine.

## 5. Flatpak strategy

**Decision:** Mirror bluefin — Flathub remote enabled (inherited from silverblue-main) + systemd one-shot service auto-installs a curated list on first boot.
**Why:** User asked for "same bluefin behaviour for flatpaks". Keeps images reproducible while honoring "no hand-install after rebase".
**Curated list — current (post 2026-04-23 cleanup, 8 flatpaks):**
```
flathub/app.zen_browser.zen          ← added 2026-04-23, replaces helium-bin RPM
flathub/com.github.tchx84.Flatseal
flathub/io.github.flattool.Warehouse
flathub/com.mattjakeman.ExtensionManager
flathub/io.podman_desktop.PodmanDesktop
flathub/com.ranfdev.DistroShelf
flathub/net.nokyan.Resources
flathub/it.mijorus.smile
```
**Originally specified (7 flatpaks):** the list above without `app.zen_browser.zen`. Browser was Helium via RPM (decision #8). Replaced by Zen flatpak when the imput/helium COPR's `helium-bin` package hit a `/opt/helium` cpio unpack conflict on Silverblue's tmpfiles-managed `/opt`.
**Explicitly excluded:** Discord, Slack (comms), Pinta (creative), Stremio (media), DevToolbox, Ignition, Clapgrep, Impression, embellish, Evolution, Obsidian, Chrome, Chromium — all dropped on user request. Also tried-and-rejected: Mozilla Firefox (briefly considered as helium replacement before Zen).

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

**Note on Bazaar duplication:** since `bazaar` RPM includes the app GUI, we **drop `io.github.kolunmi.Bazaar` from the flatpak manifest** to avoid duplicate installations. Final flatpak list: **8 apps** post 2026-04-23 cleanup (see decision #5).

**Pre-configured defaults:** Ship captured dconf settings as `/etc/dconf/db/local.d/00-sideral-gnome-shell` (dash-to-panel icon/position, appindicator layout, rounded-corners radius, tiling-shell tiles config, bazaar search-provider toggle). Every user gets these defaults; they can override per-user.

## 7. Tailscale (deferred)

**Decision:** Defer to a later spec. Not in sideral P1-P3.

## 8. Package scope — surgical, not a full bluefin fork

**Decision:** Earlier intent to "add everything bluefin/bluefin-dx adds" was trimmed back after walking through individual packages. The final sideral layer is **surgical**: a short list of RPMs the user explicitly named + our sideral-specific extras. Bluefin's full FEDORA_PACKAGES list is **not** replicated.

> ⚠ **D-08 SUPERSEDED 2026-04-23.** The original RPM list below was trimmed in two waves. See live state in [STATE.md](../../project/STATE.md) "2026-04-23 cleanup" entry and [nix-home/context.md](../nix-home/context.md) D-04..D-15 for the new architecture. The historical content is preserved unchanged below for posterity.
>
> **Tracking summary** — what changed since this decision was written:
> - **Wave 1 (nix-home, NXH-01..40, ~2026-04 mid):** mise moved from RPM to nix; `sideral-mise-install.service` removed; `act`, `atuin`, `direnv` dropped from mise toolchain or moved to home-manager; `/etc/skel/.bashrc` replaced by home-manager-generated `~/.bashrc`.
> - **Wave 2 (RPM cleanup, 2026-04-23):** every plain-CLI moved to home.nix or removed:
>   - **→ home.nix**: `gh`, `starship`, `gcc`/`make`/`cmake`, `git-lfs`/`subtree`/`credential-libsecret`, `code` (VS Code).
>   - **→ flatpak**: `helium-bin` replaced by `app.zen_browser.zen` (Silverblue `/opt` cpio conflict).
>   - **Removed entirely**: `nix-software-center` (snowfall fetch, never used), `android-tools` (use `nix shell` ad-hoc), kernel-debug stack `bcc`/`bpftop`/`bpftrace`/`sysprof`/`trace-cmd`/`tiptop`/`nicstat`/`iotop`/`udica` (bluefin-dx parity that the personal workload didn't need).
>   - **Feature dirs deleted**: `build_files/features/devtools/`, `build_files/features/browser/`.
> - **Net result:** RPM layer now contains GNOME shell extensions + bazaar + docker-ce stack + fonts only. Everything user-facing is home.nix or flatpak.

### RPMs to layer on top of silverblue-main *(historical — see banner above)*

**GNOME extensions (from Fedora main):**
- `gnome-shell-extension-appindicator`
- `gnome-shell-extension-dash-to-panel`

**Bazaar app store (from `ublue-os/packages` COPR, already enabled in base):**
- `bazaar` — bundles the Bazaar app GUI + `bazaar-integration@kolunmi.github.io` Shell extension + GNOME search provider

**Dev tooling (user-approved surgical list):** ⚠ all moved to home.nix in 2026-04-23 cleanup
- ~~`gcc`, `make`, `cmake`~~ — now via `pkgs.gcc/gnumake/cmake` in `home.packages`
- ~~`git-credential-libsecret`~~ — now via `programs.git.extraConfig.credential.helper = "libsecret"` (uses nixpkgs git's libexec)
- ~~`git-subtree`~~ — bundled with `pkgs.git`, no separate install needed
- ~~`git-lfs`~~ — now via `programs.git.lfs.enable`

**Editor (VS Code — mirrors bluefin-dx pattern):** ⚠ moved to home.nix in 2026-04-23 cleanup
- ~~`code` from Microsoft's `packages.microsoft.com/yumrepos/vscode` repo~~ — now via `programs.vscode` in home.nix
- ~~`system_files/usr/lib/systemd/user/sideral-vscode-setup.service`~~ — service deleted; extensions now declared via `programs.vscode.extensions = with pkgs.vscode-extensions; [ ms-vscode-remote.remote-ssh, ms-vscode-remote.remote-containers ]`

**Terminal:** Ptyxis (shipped by silverblue-main base) is the terminal. **Kitty dropped** — no layering, no dotfile.

**CLI (mise doesn't package it):** ⚠ moved to home.nix
- ~~`gh` — GitHub CLI~~ — now via `programs.gh.enable`

**Browser:** ⚠ replaced 2026-04-23
- ~~`helium-bin` from `imput/helium` COPR~~ — RPM hit `/opt/helium` cpio unpack conflict on Silverblue's tmpfiles-managed `/opt`. Replaced with **`app.zen_browser.zen` flatpak**.

**GNOME quality-of-life (adopted from bluefin's strong-recs):** ✓ still RPM-layered
- `gnome-tweaks`, `adw-gtk3-theme`, `fastfetch`

**Shell prompt (mirrors bluefin pattern):** ⚠ moved to home.nix
- ~~`starship` (Fedora main)~~ — now via `programs.starship.enable`
- Activation no longer in `/etc/skel/.bashrc` — home-manager owns the user's bashrc.

**Mise — Pattern A (user-level install, auto-triggered on first login):** ⚠ replaced by Pattern B (nix-home)
- Image now **does ship a mise binary** in `~/.nix-profile/bin/` via `home.packages = [ pkgs.mise ]`.
- `sideral-mise-install.service` **deleted**; `sideral-home-manager-setup.service` materializes mise + the rest of home.nix on first user login.
- mise config inlined in home.nix via `home.file.".config/mise/config.toml".text = ''…''` (was `/etc/skel/.config/mise/config.toml`).
- Toolchain reduced from 15 → **12 tools**: dropped `act` (use `nix profile install` ad-hoc), `direnv` (declined entirely), `atuin` (now `programs.atuin.enable`).
- Distrobox now shares the host's `/nix` via `/etc/distrobox/distrobox.conf` auto-mount; mise itself is host-only (was host+distrobox via `~/.local/bin`).

**Fonts (adopted from bluefin's curation):** ✓ still RPM-layered
- `cascadia-code-fonts`, `jetbrains-mono-fonts-all`, `adwaita-fonts-all`, `opendyslexic-fonts` + Source Serif 4 / Sans 3 from Adobe GitHub

**Container runtime (bluefin-dx pattern — requires docker-ce repo):** ✓ still RPM-layered
- `containerd.io` + `docker-ce` from **docker-ce-stable repo**
- Rationale unchanged: user opted in despite podman; docker-ce gives seamless `docker compose` CLI

**Android tooling:** ⚠ removed 2026-04-23
- ~~`android-tools` (Fedora main) — adb + fastboot~~ — removed; use `nix shell nixpkgs#android-tools` when connecting a phone.

**Kernel debug / profiling (user override — full bluefin-dx debug stack):** ⚠ removed entirely 2026-04-23
- ~~`bcc`, `bpftop`, `bpftrace`, `sysprof`, `trace-cmd`, `tiptop`, `nicstat`, `iotop`, `udica`~~ — bluefin-dx parity items, not part of the personal workload. Reachable on demand via `nix shell` if ever needed.

**Note:** `containerd` (Fedora) is intentionally **not** listed — it conflicts with `containerd.io` (Docker). dnf handles the swap.

### Explicitly NOT layered *(historical list, still accurate for things we never added)*

- `podman-compose`, `podman-docker`, `podman-tui` — user declined
- `flatpak-builder`, `p7zip`, `p7zip-plugins`, `yq`, `sqlite`, `glow` — not needed this pass
- Bluefin-dx virt stack (`libvirt`, `qemu-*`, `virt-manager`, `incus`, `lxc`, `cockpit-*`) — heavy, redundant with podman/distrobox
- `rocm-*` — niche
- `fish`, `zsh`, `bash-color-prompt`, `ibus-mozc`, `mozc`, `samba-*`, `krb5-workstation`, `adcli` — not part of user's workflow
- `tailscale` — deferred

### Sideral specifics — current (post-cleanup)

- Build-time GNOME extension fetch: `tilingshell@ferrarodomenico.com` + `rounded-window-corners@fxgn` from extensions.gnome.org (`gnome-extensions/post-install.sh`)
- `fonts/post-install.sh`: Source Serif 4 + Source Sans 3 from Adobe GitHub releases
- ~~`devtools/post-install.sh`: mise binary from mise.run~~ — devtools dir deleted; mise comes via home.nix
- `nix-installer` binary baked at `/usr/libexec/nix-installer` (build.sh fetch)

### /etc + /usr files shipped — current (post-cleanup)

- `/etc/dconf/db/local.d/{00-sideral-focus, 00-sideral-gnome-shell, 10-sideral-keybinds}` — captured GNOME defaults
- `/etc/distrobox/distrobox.conf` — auto-mount `/nix`, `/var/lib/nix`, `/etc/nix` into every distrobox container ⊕ added 2026-04-23
- `/etc/flatpak-manifest` + `/etc/systemd/system/sideral-flatpak-install.service` — 8-app auto-install
- `/etc/os-release` rewritten with `ID=sideral`, `NAME="Sideral OS"`
- `/etc/profile.d/sideral-hm-status.sh` — first-shell bootstrap UX (poll home-manager-setup-done marker, source env when ready)
- `/etc/selinux/targeted/contexts/files/file_contexts.local` — `/nix` SELinux fcontext rules (mapping to `usr_t`/`bin_t`/`lib_t`)
- `/etc/systemd/system/sideral-nix-install.service` — first-boot nix installer (multi-target.wants symlink)
- `/etc/systemd/system/sideral-nix-relabel.{service,path}` — auto-restorecon on `/nix/store` mutations (multi-target.wants symlink for the .path)
- `/etc/yum.repos.d/docker-ce.repo` — kept for `rpm-ostree upgrade` to pull docker-ce + containerd.io updates
- ~~`/etc/yum.repos.d/vscode.repo`~~ — **deleted** 2026-04-23 (VS Code now via home.nix)
- `/usr/lib/systemd/user/sideral-home-manager-setup.service` + `default.target.wants/` symlink — first-login home-manager bootstrap
- ~~`/usr/lib/systemd/user/sideral-vscode-setup.service`~~ — **deleted** 2026-04-23
- ~~`/usr/lib/systemd/user/sideral-mise-install.service`~~ — **deleted** in nix-home migration
- `/usr/libexec/nix-installer` — pinned binary, run by `sideral-nix-install.service`

### /etc/skel shipped (user defaults) — current

- ~~`home/.bashrc`~~ — **deleted** in nix-home migration; bashrc generated by home-manager
- ~~`home/.config/mise/config.toml`~~ — **deleted** in nix-home migration; mise config inlined in home.nix
- `home/.config/home-manager/home.nix` — single source of truth for the user environment

### Size reality check (post-cleanup)

Even **leaner** than the original surgical estimate. RPM additions to silverblue-main:43 are now: 5 GNOME extension/QoL RPMs + bazaar + 4 docker-ce-stack + ~6 font RPMs + nix-installer binary stage = ~16 RPMs and ~150 MB delta over the base. Most user-facing software lives in nix profiles (~/.nix-profile) which add weight on first `home-manager switch` rather than to the image.

### Shells

Bash (from base) remains the default. No fish/zsh layered. Bashrc is now home-manager-generated; activations of starship, mise, atuin, and the nix-daemon profile happen there (see home.nix `programs.bash.initExtra`).

## 9. Window focus behaviour

**Decision:** Focus follows mouse (sloppy), no auto-raise.
**Why:** With tiling-shell, windows don't overlap, so auto-raise is irrelevant; sloppy focus gives the hover-to-focus feel without the jitter of `mouse` mode.
**Implementation:** Ship `system_files/etc/dconf/db/local.d/00-sideral-focus` with:
```ini
[org/gnome/desktop/wm/preferences]
focus-mode='sloppy'
auto-raise=false
```
