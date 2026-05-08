# nixos-port Specification

> Status: **DRAFT — 2026-05-04.** First-pass spec for a 1:1 port of sideral from Fedora atomic (silverblue-main + rpm-ostree) to NixOS (flakes + home-manager). Same folder layout (`os/modules/<capability>/`), same configuration files (KDL, QML, JSON, TOML, .nu, .kbd, .kdl matugen templates, niri config, Noctalia settings, ghostty, helix, mise, kanata, sddm theme), same daily-driver behavior. This is a **branch port** living on the `nixos` branch — it does not modify the Fedora flavor on `main`. ISO making is preserved as the deliverable; OCI image rebase retires on this branch (NixOS uses `nixos-rebuild --flake` instead). Three open preference points surfaced in `context.md` for user lock; all mechanical decisions locked autonomously.

## Problem Statement

sideral's daily-driver experience — niri compositor, Noctalia shell, three-island aesthetic on top, ghostty terminal, SDDM + SilentSDDM greeter, matugen wallpaper-to-theme pipeline, three-shell parity (bash + zsh + nu), mise toolchain, rootless podman, kubernetes module, curated flatpak set, kanata key-remap, ujust extension recipes, NVIDIA variant — is locked in via Fedora-specific machinery: rpm-ostree-layered RPMs, an OCI image rebuilt by GHA + pushed to ghcr.io, an `rpm-ostree rebase` UX, dnf5 + Containerfile + rpmbuild orchestrators, and a chezmoi seed that materializes user dotfiles on first login.

This feature ports the entire stack to NixOS with three reasons:
1. **Atomicity & rollback are first-class on NixOS** — every config change is a generation, every boot menu is a deployment, no `rpm-ostree`-vs-`/etc/yum.repos.d` impedance, no composefs gymnastics.
2. **Declarative user layer is native** — home-manager's module system replaces the chezmoi seed cleanly. Dotfile contents move into HM modules, but every config file (niri's `config.kdl`, Noctalia's `settings.json`, ghostty's `config`, the matugen templates, the kanata `.kbd`, the nu `env.nu`/`config.nu`, the SilentSDDM theme) ships byte-for-byte unchanged.
3. **Single source of truth for system + user** — one `nixos-rebuild switch --flake .#sideral` brings up the whole machine: kernel, drivers, services, packages, dotfiles, fonts, flatpaks. No sequencing of "RPM layer first, then chezmoi on first login."

The port is **not** an attempt to add features — every requirement is "the NixOS-port replacement of an existing Fedora-flavor behavior." Anything genuinely new (e.g. bootloader swap, three-island Quickshell, ujust → nix-CLI rewrite) is explicitly out of scope and waits for its own feature spec.

The previous `nix-home` retirement (.specs/features/nix-home/, dropped 2026-05-01) does **not** apply here. Its three blockers — composefs vs nix-installer ostree planner, SELinux mislabel of /nix store paths, `/nix` disappearing after `rpm-ostree upgrade` — were specifically about running nix on top of Fedora atomic 42+. This port runs nix as the OS, not on top of it; those failure modes are inapplicable.

## Goals

- [ ] `flake.nix` at repo root exposes `nixosConfigurations.sideral` (open-source GPU) and `nixosConfigurations.sideral-nvidia` (proprietary NVIDIA), each `nixos-rebuild switch --flake .#<name>`-able on a fresh NixOS install.
- [ ] `flake.nix` exposes `nixosConfigurations.sideral-iso` producing a bootable **installer-only** ISO at `result/iso/sideral_x86_64.iso` via the standard `config.system.build.isoImage` path. The ISO boots straight to calamares with light sideral branding (logo + color scheme on welcome/finish, BTRFS+zstd partition defaults pre-filled). **No live niri session, no `liveuser` autologin** — calamares is a standalone Qt app that can't render inside niri+Noctalia, and showing a live niri preview before install would misrepresent the installed-system look-and-feel. Pre-install hook reads `lspci` and bakes `sideral.nix` or `sideral-nvidia.nix` into `/etc/nixos/configuration.nix` on the target before invoking `nixos-install` — same GPU-split UX as the Fedora ISO's anaconda-hook, different first-impression model.
- [ ] Repo layout preserved: `os/modules/<capability>/` is the unit of code, one capability per directory. Capability names map 1:1 from the Fedora layout: `base`, `cli-tools`, `dotfiles`, `flatpaks`, `kubernetes`, `niri-defaults`, `services`, `shell-ux`. Each module owns a `default.nix` plus its existing `src/` subtree of raw config files (untouched). The Fedora-only `rpm/<spec>` subdirs retire on this branch.
- [ ] Build orchestrators retire: `os/Containerfile`, `os/lib/build.sh`, `os/lib/build-rpms.sh`, `os/lib/install-packages.sh` are removed. Replaced by the implicit nix evaluator + `nixos-rebuild`. The `os/build/{fonts,nvidia}/` build-time-only trees collapse into the corresponding modules (`os/modules/fonts/`, `os/modules/nvidia/`).
- [ ] Every binary the Fedora image installs is present in the NixOS image: niri, sddm, sddm-wayland-generic, ghostty, noctalia-shell, noctalia-qs (or upstream Quickshell as the runtime — see context.md C-04), matugen, kanata, kanshi, wdisplays, ddcutil, brightnessctl, fastfetch, wlsunset, fprintd, fcitx5, fcitx5-configtool, grim, slurp, wl-clipboard, cliphist, chezmoi (escape hatch only — see context.md C-03), mise, code (VS Code), starship, nushell, carapace, atuin, fzf, bat, eza, ripgrep, zoxide, gh, git-lfs, gcc, make, cmake, helix, fish, zsh, zsh-syntax-highlighting, zsh-autosuggestions, rclone, fuse3, chromium, podman, podman-compose, kubectl, kind, helm. (NXP-20 is the exhaustive checklist.)
- [ ] Every config file the Fedora image ships under `os/modules/*/src/` is materialized at the same destination path on the running NixOS system, byte-identical. `/etc/xdg/niri/config.kdl`, `/etc/kanata/sideral.kbd`, `/etc/sddm.conf.d/sideral.conf`, `/usr/share/sddm/themes/silent/`, `/etc/xdg/matugen/{config.toml,templates/*}`, `/etc/distrobox/distrobox.conf`, `/etc/containers/policy.json`, `/etc/profile.d/sideral-niri-ime.sh`, `/usr/share/wayland-sessions/niri.desktop`, `/usr/share/wallpapers/sideral/default.jpg`, `/etc/user-motd`, `/usr/share/ublue-os/just/60-custom.just` — all present at the same paths.
- [ ] User-layer dotfiles port from `os/modules/dotfiles/src/usr/share/sideral/chezmoi/` to the corresponding home-manager modules, **content unchanged**. niri/config.kdl, niri/noctalia.kdl, ghostty/config, mise/config.toml, nushell/{env.nu,config.nu}, matugen/{config.toml,templates/*}, noctalia/settings.json, dot_bashrc, dot_zshrc, run_onchange_after_install-nu-prompts.sh — every file's contents lands at the right `~/.config/...` path via `home.file` / `xdg.configFile` / `programs.<X>.extraConfig`.
- [ ] home-manager runs in **NixOS-module mode** (not standalone): `nixos-rebuild switch` materializes both system and user layer. Single command for system + dotfile updates. (See context.md C-02.)
- [ ] NVIDIA variant ships niri+Noctalia identically. Equivalent of `os/build/nvidia/` becomes `os/modules/nvidia/default.nix`, gated on `config.hardware.nvidia.enable`. The four NVIDIA kargs (incl. `nvidia-drm.modeset=1`), the modprobe.d snippet, the niri-config drop-in for nvidia smithay backend, and the env.d export all carry over.
- [ ] All `njust` recipes carry over (chsh, chezmoi-init, gdrive-setup, gdrive-remove, tools, update, niri, theme, apply-defaults). The `update` recipe rewrites to call `nh os switch` (or `nixos-rebuild switch --upgrade --flake github:<owner>/sideral#<variant>`) instead of `rpm-ostree upgrade`. The `apply-defaults` recipe rewrites to a no-op message pointing users at `nixos-rebuild switch` (since defaults are now applied at activation, not on first login).
- [ ] CI: `.github/workflows/build.yml` is rewritten as a `flake.nix`-driven workflow. Jobs: `nix flake check` (replaces `bootc container lint`), `nix build .#nixosConfigurations.sideral.config.system.build.toplevel` (replaces the open-source OCI build), `nix build .#nixosConfigurations.sideral-nvidia.config.system.build.toplevel` (replaces the nvidia OCI build), `nix build .#sideral-iso` (replaces the titanoboa step), upload single overwrite-keyed `sideral_x86_64.iso` + `.sha256` to Cloudflare R2 (key, bucket, endpoint env vars unchanged). `semantic-release` stays. Cosign keyless signing of the OCI variants is dropped (no OCI image to sign).
- [ ] Build verification: `just lint` runs `nix flake check`. `just build` runs `nix build .#nixosConfigurations.sideral.config.system.build.toplevel`. `just build-iso` runs `nix build .#sideral-iso` (new). `just rebase` rewrites to `sudo nixos-rebuild switch --flake .#sideral`. `just rollback` rewrites to `sudo nixos-rebuild switch --rollback`.
- [ ] The semantic version bump pipeline (`.releaserc.json`, `package.json`, `package-lock.json`) is preserved verbatim. semantic-release tags releases the same way; release notes still link to the R2-hosted ISO.
- [ ] README.md gains a "NixOS variant — installation" section. The Fedora install path (rpm-ostree rebase) section is preserved (it's still valid for the `main` branch). The NixOS section documents `nixos-rebuild --flake github:<owner>/sideral#sideral` and the ISO download.

## Out of Scope

| Feature | Reason |
|---|---|
| Touching anything on the `main` branch | This PR is branch `nixos` only. The Fedora flavor on `main` keeps shipping unchanged until a future "make NixOS the default" decision is taken. |
| Bootloader swap (sd-boot vs rEFInd vs Limine vs GRUB) | Tracked separately in user memory; explicitly NOT bundled here. NixOS defaults (sd-boot for UEFI, GRUB for BIOS) ship as-is. |
| Three-island aesthetic Quickshell QML | Same status as on the Fedora flavor: deferred to follow-up `niri-islands` feature. Stock Noctalia ships in v1. |
| New features beyond what the Fedora image already does | Pure 1:1 port. Adding e.g. bitwarden CLI integration, tailscale daemon, or sideral-themed VS Code extension is deferred to its own feature spec. |
| Aarch64 / ARM builds | Same status as on the Fedora flavor: deferred. NixOS supports aarch64 natively but no current sideral story for it. |
| Migrating chezmoi escape-hatch users into home-manager forcibly | Users who currently `chezmoi init --apply <repo>` should keep working. chezmoi binary stays in `cli-tools`; user-side `chezmoi apply` is unaffected by the home-manager system seed. (See context.md C-03.) |
| OCI image (bootc / rebase target) on the NixOS branch | NixOS uses `nixos-rebuild --flake` for upgrades. Maintaining a parallel nixos-bootc OCI build is a separate concern; deferred unless explicitly desired (see context.md C-01). |
| Cosign keyless signing of the system closure | No OCI image to sign on this branch. Closure-level signing via nix-store --sign / Cachix `signingKey` is a follow-on if/when a binary cache lands. |
| Replacing matugen wrapping with a hand-rolled palette generator | matugen ships as-is; the templates carry over byte-identical. |
| Replacing the just-based recipe runner with a sideral-CLI written in Rust/Go | Out of scope. The recipes file is renamed `sideral.just` and the wrapper renamed `njust` (NXP-49); recipe bodies carry over with three lines edited (the rebase / upgrade / apply-defaults). The Universal-Blue `ujust` dependency retires entirely. |
| Replacing nushell config / matugen templates / ghostty config / niri config with NixOS-idiomatic equivalents | Files carry over byte-identical. The point of this port is to swap the OS plumbing, not the user-visible config. If a config file later wants to be ported to its idiomatic Nix module (e.g. `programs.git`), that's a follow-on after parity is verified. |

---

## User Stories

> P-tier indicates implementation priority within this feature. P1 must work for the feature to ship.

### P1: Flake exposes nixosConfigurations + ISO ⭐ MVP

**Story**: User clones the repo, runs `nix flake check`, and sees the three configurations evaluate cleanly. `nix build .#nixosConfigurations.sideral.config.system.build.toplevel` produces a system closure. `nix build .#sideral-iso` produces a bootable installer-only ISO that, when written to USB and booted, lands directly in a sideral-branded calamares installer (no live niri session, no `liveuser` autologin) that detects GPU via `lspci` and bakes either `sideral` or `sideral-nvidia` into the installed system.

**Acceptance**:

1. **NXP-01** — `flake.nix` at repo root has `inputs = { nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11"; home-manager.url = "github:nix-community/home-manager/release-25.11"; ... }` (channel locked per context.md C-05) and exposes `nixosConfigurations.{sideral,sideral-nvidia,sideral-iso}` as documented in NXP-02 / NXP-03 / NXP-04.
2. **NXP-02** — `nix flake check` passes. `nix flake show` lists the three nixosConfigurations and any packages we ship out-of-tree (noctalia-shell, noctalia-qs if not in nixpkgs — see context.md C-04).
3. **NXP-03** — `nix build .#nixosConfigurations.sideral.config.system.build.toplevel` succeeds in <12 min on CI.
4. **NXP-04** — `nix build .#sideral-iso` (or `.#nixosConfigurations.sideral-iso.config.system.build.isoImage`) produces an ISO at `result/iso/sideral_x86_64.iso`. ISO is bootable on UEFI hardware. (Title and label carry the `sideral` brand.)
5. **NXP-05** — ISO boots **directly to calamares** as the first interactive surface. No SDDM, no niri session, no `liveuser` autologin in the live env. Boot path: kernel → minimal X/Wayland → calamares window. Rationale: calamares is a Qt app and can't render inside niri+Noctalia, so a live niri preview followed by a Qt-themed installer would create a jarring first-impression; installer-only is cleaner.
6. **NXP-06** — Calamares ships with **light sideral branding**: sideral logo on welcome + finish screens, sideral color scheme via custom calamares CSS (`/etc/calamares/branding/sideral/branding.desc`), sideral-themed wizard frame. Calamares modules enabled: `welcome → locale → keyboard → partition → users → summary → install → finish`. Pre-install hook reads `lspci` and writes `imports = [ ./sideral.nix ];` (or `./sideral-nvidia.nix` if NVIDIA detected) plus `system.stateVersion = "25.11";` into `/etc/nixos/configuration.nix` on the target disk before invoking `nixos-install`.
7. **NXP-07** — Default partitioning pre-filled in calamares matches the Fedora anaconda-profile defaults: BTRFS + zstd:1, separate subvolumes for `/`, `/home`, `/var`. (Parity with anaconda-hook.sh's `[Storage]` block.) LUKS encryption checkbox available; defaults off.
8. **NXP-08** — ISO size: <2 GiB target (no full desktop in the live env, just calamares + minimal X/Wayland to render it; closer to NixOS minimal-installation-cd's ~1 GiB than to the Fedora 5 GiB).

**Test**: `nix flake check` returns 0; `nix build .#sideral-iso` produces an ISO ≤2 GiB; flash to USB; boot in QEMU (`-bios /usr/share/OVMF/OVMF_CODE.fd`); land directly in calamares with sideral branding; complete install on a 50 GiB virtual disk; reboot; SDDM SilentSDDM theme renders; log in as the user created during install; niri+Noctalia session starts; `nix-shell -p hello` works.

---

### P1: System modules port 1:1 ⭐ MVP

**Story**: Every capability the Fedora image owns has a corresponding NixOS module under `os/modules/<capability>/default.nix`. Importing the module from a host config (`sideral.nix` or `sideral-nvidia.nix`) brings the same packages, services, and `/etc` files online as the Fedora flavor.

**Acceptance**:

1. **NXP-09** — `os/modules/base/default.nix` ships `/etc/os-release` (with `ID=sideral`, `VARIANT_ID` set to the variant), `/etc/containers/policy.json`, and the equivalent of the persistent yum repos: nothing — the mise / vscode / kubernetes / terra / carapace / nushell repos all retire because their packages come from nixpkgs (or from a flake input — see context.md C-04). The `UPGRADE.md` carries over for historical reference.
2. **NXP-10** — `os/modules/cli-tools/default.nix` ships `environment.systemPackages = with pkgs; [ chezmoi mise atuin fzf bat eza ripgrep zoxide gh git-lfs gcc gnumake cmake helix fish zsh zsh-syntax-highlighting zsh-autosuggestions rclone fuse3 chromium nushell carapace vscode starship git-lfs ];` (sorted, deduplicated). The `hide-chromium.sh` patching of `/usr/share/applications/chromium*.desktop` is replaced by `xdg.desktopEntries` overrides or a `system.activationScripts` snippet that drops `NoDisplay=true` into the chromium desktop file at `/run/current-system/sw/share/applications/`. The `nushell-plugins-install.sh` logic translates to a system activation script (or a per-user home-manager activation).
3. **NXP-11** — `os/modules/niri-defaults/default.nix` ships niri, sddm, sddm-wayland-generic, kanshi, wdisplays, ddcutil, brightnessctl, fastfetch, wlsunset, fprintd, fcitx5, fcitx5-configtool, grim, slurp, wl-clipboard, cliphist, matugen, ghostty, kanata as system packages. Plus `programs.niri.enable = true;` (or upstream's NixOS module if available — see context.md C-04 for noctalia-shell/noctalia-qs sourcing). SDDM enabled with Wayland: `services.displayManager.sddm = { enable = true; wayland.enable = true; theme = "silent"; };`. `kanata` runs as `systemd.services.kanata` (kbd file at `/etc/kanata/sideral.kbd` from `src/etc/kanata/sideral.kbd`).
4. **NXP-12** — `os/modules/services/default.nix` ships `virtualisation.podman = { enable = true; dockerCompat = true; defaultNetwork.settings.dns_enabled = true; };`, `programs.podman-compose.enable` equivalent (or include `podman-compose` in systemPackages), `services.flatpak.enable = true;`, the `rclone-gdrive.service` user unit, and `/etc/distrobox/distrobox.conf` from `src/etc/distrobox/distrobox.conf`.
5. **NXP-13** — `os/modules/kubernetes/default.nix` ships kubectl, kind, helm in systemPackages, plus the `KIND_EXPERIMENTAL_PROVIDER=podman` and `MINIKUBE_DRIVER=podman` exports via `environment.sessionVariables` (replacing `/etc/profile.d/sideral-kind-podman.sh`).
6. **NXP-14** — `os/modules/flatpaks/default.nix` ships the curated 11-entry flatpak set declaratively via `nix-flatpak` (per C-17). The Fedora-flavor `os/modules/flatpaks/live-iso.txt` overlay (Zen Browser only on the live env) **deletes** — there is no live env on the NixOS ISO (NXP-05); calamares-only ISOs don't ship flatpaks at all.
7. **NXP-15** — `os/modules/shell-ux/default.nix` ships `/etc/zshrc` (replacing nixpkgs-default), `/etc/user-motd`, `/etc/mise/config.toml`, the bash/zsh/nu init wiring under `/etc/profile.d/`, the `60-custom.just` extension at `/usr/share/ublue-os/just/`, and the rclone-gdrive systemd user unit. `programs.bash.shellInit` / `programs.zsh.shellInit` / `programs.fish.shellInit` mirror the AI-agent-detection guards. Replaces both `sideral-shell-ux` and `sideral-services` Fedora-RPM split where the boundary blurred.
8. **NXP-16** — `os/modules/dotfiles/default.nix` is a **home-manager module** (imported into the host's `home-manager.users.<user>` block — see C-02). It ports the chezmoi seed: niri/config.kdl, niri/noctalia.kdl, mise/config.toml, ghostty/config, nushell/{env.nu,config.nu}, matugen/{config.toml,templates/*}, noctalia/settings.json, sideral-cli-init.nu, dot_bashrc, dot_zshrc — every file's content carries over byte-identical via `home.file."<path>".source = ./src/.../<file>`. The `run_onchange_after_install-nu-prompts.sh` hook becomes a `home.activation.installNuPrompts` script.
9. **NXP-17** — `os/modules/fonts/default.nix` (collapses `os/build/fonts/`) ships the Fedora-equivalent font set via `fonts.packages = with pkgs; [ cascadia-code jetbrains-mono adwaita-fonts open-dyslexic source-serif source-sans ];`.

**Test**: After `nixos-rebuild switch --flake .#sideral`: every binary listed under NXP-10/11/12/13 is on `$PATH`, every file path listed under NXP-15 exists with byte-identical contents to the Fedora module's `src/` source, `systemctl status sddm` is active, `systemctl status kanata` is active, `flatpak list` shows the 11 curated entries, `niri --version` reports a niri-26.04+ release, the niri config in `~/.config/niri/config.kdl` matches `os/modules/dotfiles/src/usr/share/sideral/chezmoi/dot_config/niri/config.kdl` byte-for-byte after first rebuild.

---

### P1: home-manager user layer ⭐ MVP

**Story**: A user account created on a fresh sideral-NixOS install logs in once and finds their `~/.config/niri/config.kdl`, `~/.config/noctalia/settings.json`, `~/.config/ghostty/config`, `~/.config/mise/config.toml`, `~/.config/nushell/{env.nu,config.nu}`, `~/.config/matugen/...`, `~/.bashrc`, `~/.zshrc` all materialized — without ever running `chezmoi init`.

**Acceptance**:

1. **NXP-18** — home-manager runs as a NixOS module (`home-manager.useUserPackages = true; home-manager.users.<user> = import os/modules/dotfiles;`). User layer materializes during system activation, not at first login.
2. **NXP-19** — Files under `os/modules/dotfiles/src/usr/share/sideral/chezmoi/dot_config/<X>` materialize at `~/.config/<X>` byte-identical. Files under `os/modules/dotfiles/src/usr/share/sideral/chezmoi/dot_local/<X>` materialize at `~/.local/<X>` byte-identical. `dot_bashrc` materializes as `~/.bashrc`; `dot_zshrc` materializes as `~/.zshrc`.
3. **NXP-20** — chezmoi remains in `systemPackages` as an escape hatch (NXP-10). A user who runs `chezmoi init --apply <their-repo>` writes to `~/.local/share/chezmoi/` and `chezmoi apply` overwrites the home-manager-seeded files (chezmoi sees them as "not under chezmoi management" so no conflict). This matches the Fedora flavor's chezmoi-on-top behavior.
4. **NXP-21** — `programs.starship.enable = true; programs.atuin.enable = true; programs.zoxide.enable = true; programs.fzf.enable = true; programs.bat.enable = true; programs.eza.enable = true; programs.git.enable = true; programs.gh.enable = true; programs.nushell.enable = true; programs.helix.enable = true;` — every CLI-QoL tool that the Fedora image wires via `/etc/profile.d/sideral-cli-init.{sh,zsh,fish}` is wired the same way via home-manager program modules. The bash/zsh/fish initExtra blocks carry over the AI-agent-alias-suppression logic (14 env-var markers) and the Ctrl+P / Alt+S / Ctrl+G fzf bindings byte-identically.
5. **NXP-22** — mise toolchain config (12 tools: node, bun, python, java, kotlin, gradle, go, rust, zig, android-sdk, pnpm, uv) lives at `~/.config/mise/config.toml`, byte-identical to the Fedora flavor's seeded copy.

**Test**: After installing on a clean disk and logging in for the first time: `cat ~/.config/niri/config.kdl` matches the source-controlled file byte-for-byte; `mise ls` lists the 12 declared tools; `starship --version` works; `atuin status` works; `z <tab>` offers frecency completions.

---

### P2: NVIDIA variant 1:1

**Story**: User installs sideral-nvidia from the same ISO (autodetected), boots, and gets niri+Noctalia rendering correctly under the proprietary NVIDIA driver — same kargs, same modprobe overrides, same niri smithay backend hint as the Fedora flavor.

**Acceptance**:

1. **NXP-23** — `os/modules/nvidia/default.nix` is gated (only imports its content when `config.hardware.nvidia.enable == true`). When active, sets `services.xserver.videoDrivers = [ "nvidia" ]; hardware.nvidia.modesetting.enable = true; hardware.nvidia.open = false;` (proprietary, parity with Fedora) plus the four kargs from `os/build/nvidia/kargs.d/00-nvidia.toml`: `nvidia-drm.modeset=1`, `nvidia-drm.fbdev=1`, `rd.driver.blacklist=nouveau`, `modprobe.blacklist=nouveau` (translate to `boot.kernelParams` + `boot.blacklistedKernelModules`).
2. **NXP-24** — The `os/build/nvidia/modprobe.d/sideral-nvidia.conf` content carries over via `boot.extraModprobeConfig`.
3. **NXP-25** — The niri-config drop-in at `os/build/nvidia/niri.config.d/sideral-nvidia.kdl` ships at `/etc/xdg/niri/config.d/sideral-nvidia.kdl` only when the nvidia module is active (use `lib.mkIf config.hardware.nvidia.enable`).
4. **NXP-26** — The env.d export at `os/build/nvidia/environment.d/90-sideral-niri-nvidia.conf` carries over via `environment.sessionVariables` gated on the nvidia module.
5. **NXP-27** — The nvidia-app-profiles file at `os/build/nvidia/nvidia-app-profiles/50-niri.json` ships at `/etc/nvidia/nvidia-application-profiles-rc.d/50-niri.json` (or the NixOS-equivalent path the proprietary driver reads).
6. **NXP-28** — `nix build .#nixosConfigurations.sideral-nvidia.config.system.build.toplevel` succeeds with the nvidia driver and the nvidia kargs baked in.

**Test**: On NVIDIA hardware, ISO autodetect → install → reboot → niri renders without tearing under Wayland; `cat /proc/cmdline` shows the four nvidia kargs; `lsmod | grep nvidia` shows nvidia modules loaded; `notify-send hello` renders correctly via Noctalia.

---

### P2: ISO build & CI parity

**Story**: Every push to `nixos` branch builds both variants + the ISO, on a single GHA workflow that mirrors the Fedora `build-sideral` workflow's layout (build matrix → release → ISO → R2 upload → semantic-release → release-notes append).

**Acceptance**:

1. **NXP-29** — `.github/workflows/build.yml` (on the `nixos` branch) has a `build` job with two matrix entries (`sideral`, `sideral-nvidia`); each entry runs `nix flake check` then `nix build .#nixosConfigurations.<name>.config.system.build.toplevel`. Failure gates the release job.
2. **NXP-30** — Subsequent `release` job (still gated on `github.ref == 'refs/heads/main'` once nixos lands as default; on the nixos branch it gates on `github.ref == 'refs/heads/nixos'`) runs semantic-release dry-run → if next version exists, builds the ISO via `nix build .#sideral-iso` → checksums → uploads single overwrite-keyed `sideral_x86_64.iso` + `.sha256` to Cloudflare R2 (env vars unchanged: R2_ENDPOINT, R2_BUCKET, R2_PUBLIC_BASE, ISO_KEY).
3. **NXP-31** — Release notes append the same Download stanza as the Fedora flavor (curl + sha256sum -c + dd command block).
4. **NXP-32** — The `cosign keyless OIDC` signing step is removed from this workflow (no OCI image to sign). If a binary cache is added later (context.md C-01 follow-on), Cachix `signingKey` handles closure-level signing.
5. **NXP-33** — Build cache: GHA + `cachix/install-nix-action` + `DeterminateSystems/magic-nix-cache-action` (or equivalent). No external Cachix account required for the v1 port.
6. **NXP-34** — The Maximise-disk-space step (ublue-os/remove-unwanted-software) carries over (still useful before a nix build that pulls 4 GiB of closures).

**Test**: Push a commit to `nixos` branch → workflow runs → both nixosConfigurations build → if release-worthy, ISO builds + uploads to R2 → release notes link to the new ISO.

---

### P2: njust + UX surfaces preserved

**Story**: Every `njust` recipe a user knows from the Fedora flavor still works on the NixOS port, with three small command-body rewrites for the rebase / upgrade / apply-defaults flows.

**Acceptance**:

1. **NXP-35** — `60-custom.just` ships at `/usr/share/ublue-os/just/60-custom.just` (same path), imported by ublue-os-just. Recipes shipped: `chsh [shell]`, `chezmoi-init <repo>`, `gdrive-setup`, `gdrive-remove`, `tools`, `update`, `niri`, `theme <wallpaper>`, `apply-defaults`.
2. **NXP-36** — `update` recipe body changes from `rpm-ostree upgrade` to `sudo nixos-rebuild switch --upgrade --flake github:athenabriana/sideral#$(. /etc/os-release; echo "$VARIANT_ID")`. (`nh os switch` is acceptable if `nh` is in systemPackages — defer to a follow-on.)
3. **NXP-37** — `apply-defaults` recipe body changes from `chezmoi update; chezmoi apply` to a single line printing "Defaults are applied at activation; run `sudo nixos-rebuild switch --flake .#sideral` to refresh." (User memory should remain — this isn't a no-op semantically, but the underlying mechanism changed.)
4. **NXP-38** — `chsh [shell]` body unchanged (still `sudo usermod -s` since `chsh` setuid is dropped).
5. **NXP-39** — `theme <wallpaper>` body unchanged (calls matugen, signals ghostty SIGUSR1, regenerates helix theme — all binary-level operations that don't care about OS plumbing).
6. **NXP-40** — `chezmoi-init <repo>` body unchanged (escape hatch path).
7. **NXP-41** — `niri` cheatsheet body unchanged (text-only motd printer).
8. **NXP-42** — `gdrive-setup` / `gdrive-remove` bodies unchanged (rclone CLI calls + systemd user unit enable/disable).
9. **NXP-43** — `tools` cheatsheet body unchanged (text-only motd printer).
10. **NXP-44** — `/etc/user-motd` content unchanged (still shows `chsh`/`chezmoi-init`/`gdrive-setup`/`tools`/`update`/`niri`/`theme` rows).

**Test**: `njust --list` after `nixos-rebuild switch` shows the same recipe names as on the Fedora image. `njust update` runs `nixos-rebuild switch --upgrade`. `njust theme ~/Pictures/wallpaper.jpg` regenerates Material 3 outputs.

---

### P2: Fedora-flavor artifact cleanup

**Story**: The NixOS branch ships zero Fedora-specific machinery — no Universal-Blue `ujust` dependency, no `ID_LIKE=fedora` in os-release, no `yum.repos.d` files, no rpm-style flatpak purge mechanism.

**Acceptance**:

1. **NXP-49** — The Fedora-flavor `ujust` (Universal Blue's wrapper around `just`) is **dropped**. `njust` ships in its place as a **direct wrapper around upstream `just`** — it does **not** depend on `ujust`, `ublue-os-just`, or any Universal Blue package. Implementation: `os/modules/shell-ux/default.nix` adds `pkgs.just` to systemPackages and ships `njust` as a `pkgs.writeShellScriptBin` whose body is exactly `exec just --justfile /etc/sideral/sideral.just "$@"`. The recipes file relocates from `os/modules/shell-ux/src/usr/share/ublue-os/just/60-custom.just` to `os/modules/shell-ux/src/etc/sideral/sideral.just`; recipe names + bodies are unchanged (chsh, chezmoi-init, gdrive-setup, gdrive-remove, tools, update, niri, theme, apply-defaults) except for the three rewrites called out in NXP-36/NXP-37. The user-motd loader (was shipped by `ublue-os-just` as `/etc/profile.d/user-motd.sh`) ships sideral-authored at `os/modules/shell-ux/src/etc/profile.d/sideral-motd.sh` (~10 lines: print /etc/user-motd unless `~/.config/no-show-user-motd` exists).

2. **NXP-50** — `/etc/os-release` is purged of Fedora-isms. `os/modules/base/src/etc/os-release` is **deleted**; instead `os/modules/base/default.nix` sets `system.nixos.distroId = "sideral"; system.nixos.distroName = "sideral";` and `system.nixos.variant_id = "open-source"` (or `"nvidia"`) so NixOS's own `nixos-version`-driven `/etc/os-release` writer emits the right values at activation. No `ID_LIKE=fedora`, no `REDHAT_BUGZILLA_PRODUCT`, no `REDHAT_SUPPORT_PRODUCT`. `cat /etc/os-release | grep -i fedora` returns nothing on the running system.

3. **NXP-51** — Every `os/modules/*/src/etc/yum.repos.d/` subtree is deleted. Affected modules: `base/` (mise.repo, vscode.repo), `cli-tools/` (carapace.repo, nushell.repo), `niri-defaults/` (terra.repo), `kubernetes/` (kubernetes.repo). All packages source from nixpkgs (or a flake input — locked at `/spec-design`).

4. **NXP-52** — Flatpak management is declarative via `nix-community/nix-flatpak`. The curated 11-entry set lives in `os/modules/flatpaks/default.nix` as `services.flatpak.packages = [ "app.zen_browser.zen" "io.github.kolunmi.Bazaar" ... ];` (or the equivalent attribute the chosen module exposes). The `sideral-flatpak-purge` mechanism retires — refs dropped from the manifest are uninstalled on the next `nixos-rebuild switch`. The Fedora-flavor `os/modules/flatpaks/install.sh`, `os/modules/flatpaks/src/etc/{sideral-flatpak-purge,sideral-flatpak-remotes,flatpak-manifest,systemd/system/sideral-flatpak-install.service}` all delete on the `nixos` branch.

**Test**: After `nixos-rebuild switch --flake .#sideral` on a fresh install: `cat /etc/os-release | grep -i fedora` returns nothing; `ls /etc/yum.repos.d/` returns no files (or the directory doesn't exist); `njust --list` shows the same recipe set as Fedora-flavor `ujust`; `which njust` resolves to a `writeShellScriptBin` artifact (not a `ujust` symlink); `flatpak list` shows the curated 11-entry set; `find / -name 'ublue-os-just*' -o -name '60-custom.just'` returns nothing.

---

### P3: Documentation & migration notes

**Story**: README explains both flavors; users on Fedora know how to migrate to NixOS (full reinstall via ISO — no in-place upgrade), users on NixOS know how to keep up to date.

**Acceptance**:

1. **NXP-45** — README.md gains a "NixOS flavor" section pointing at the installer-only ISO download and the `nixos-rebuild --flake github:<owner>/sideral#sideral` upgrade path. Notes the lack of live preview (per C-10) so users aren't surprised by the boot-straight-to-calamares behavior.
2. **NXP-46** — README.md retains the existing Fedora install + rebase docs unchanged (Fedora is still on `main`).
3. **NXP-47** — README.md notes that there is no in-place migration from Fedora-flavor sideral to NixOS-flavor sideral. Users with personal data: back up `~/`, install fresh from ISO, re-run `chezmoi init --apply <their-repo>` if they bring their own dotfiles.
4. **NXP-48** — `.specs/codebase/STACK.md` (or follow-on) documents the NixOS toolchain: nixpkgs channel, home-manager release, nix-flatpak input, any out-of-tree packages, the `nh`/`nixos-rebuild` daily workflow.

**Test**: Reading `README.md` from cold gets a new user from "I have a USB stick" to "I'm on the NixOS flavor of sideral, my dotfiles are seeded, niri is running" with no extra googling.

---

## Edge Cases

- **NVIDIA + Wayland regression on niri** → if the smithay backend mis-detects on first install, niri config drop-in (NXP-25) provides the override; document workaround in `os/modules/nvidia/README.md`.
- **User runs `chezmoi init --apply <repo>` after install** → home-manager-managed files are *not* under chezmoi management; chezmoi will offer to manage them (diff prompt). User can accept (chezmoi takes over per-file) or skip (keep HM managing). This matches the Fedora flavor's behavior almost identically.
- **First boot on a disk encrypted with LUKS** → calamares (or NixOS-stock-graphical) handles LUKS at install time, identical UX to anaconda.
- **`/nix` fills up** → `nix-collect-garbage --delete-older-than 14d` is a documented `njust` recipe candidate (deferred to follow-on).
- **Channel skew** — `nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11"` pins to the NixOS 25.11 stable channel. `flake.lock` pins exact commits. Users who want unstable bumps run `nix flake update`.
- **home-manager release mismatch** — home-manager release-25.11 must match nixpkgs nixos-25.11; this is the standard pinning rule, enforced via `flake.lock`.
- **Flatpak preinstall on first boot** — services.flatpak.enable + nix-flatpak's declarative install runs flatpak-install on first system activation. Network requirement matches the Fedora flatpak-install service.
- **kanata permission** — kanata needs `/dev/uinput` access; on NixOS, `services.kanata` (in nixpkgs) handles the udev rule + systemd unit. If `services.kanata` is unavailable in the pinned channel, ship a manual systemd unit + udev rule.
- **SDDM SilentSDDM theme path** — Fedora installs to `/usr/share/sddm/themes/silent/`; NixOS installs to `/run/current-system/sw/share/sddm/themes/silent/`. Ensure SDDM's `Current = silent` resolves correctly on NixOS (likely yes — SDDM searches `$XDG_DATA_DIRS/sddm/themes/`).

---

## Requirement Traceability

| Story | Requirement IDs | Count |
|---|---|---|
| P1: Flake exposes nixosConfigurations + ISO | NXP-01 … NXP-08 | 8 |
| P1: System modules port 1:1 | NXP-09 … NXP-17 | 9 |
| P1: home-manager user layer | NXP-18 … NXP-22 | 5 |
| P2: NVIDIA variant 1:1 | NXP-23 … NXP-28 | 6 |
| P2: ISO build & CI parity | NXP-29 … NXP-34 | 6 |
| P2: ujust + UX surfaces preserved (renamed `njust`) | NXP-35 … NXP-44 | 10 |
| P2: Fedora-flavor artifact cleanup | NXP-49 … NXP-52 | 4 |
| P3: Documentation & migration notes | NXP-45 … NXP-48 | 4 |

**Total**: 52 testable requirements.

---

## Supersedes / coexists with

This feature **does not modify** any existing requirement on the `main` branch. It lives entirely on the `nixos` branch as a parallel implementation. The Fedora-flavor `sideral`, `sideral-rpms`, `chezmoi-home`, `niri-shell`, `nushell` specs are unchanged.

If a future "make NixOS the default" decision is taken, that's its own feature spec and would document the migration path, the canonical-flavor flip, and the deprecation schedule for the Fedora flavor.

---

## Success Criteria

- [ ] `nix flake check` passes; `nix build .#nixosConfigurations.{sideral,sideral-nvidia}.config.system.build.toplevel` succeeds; `nix build .#sideral-iso` produces a bootable ISO.
- [ ] Fresh install from ISO on QEMU (open-source GPU) → niri session up, Noctalia bar rendering, `mise --version` works, `nushell` is on `$PATH`, `chezmoi --version` works, all 11 flatpaks installed.
- [ ] Fresh install from ISO on NVIDIA hardware → niri session up under the proprietary driver with `nvidia-drm.modeset=1` active.
- [ ] Every config file under `os/modules/*/src/` AND `os/modules/dotfiles/src/usr/share/sideral/chezmoi/` lands at the same destination path on the running system, byte-identical (verifiable via `diff` against the source-controlled file).
- [ ] `njust update` runs `nixos-rebuild switch --upgrade --flake github:<owner>/sideral#$VARIANT`. `njust theme <wallpaper>` runs matugen and reloads ghostty/helix.
- [ ] CI builds in <12 min per matrix entry; ISO build + R2 upload completes in <25 min total.
- [ ] README documents both flavors clearly; new user reaches a working desktop without external googling.
- [ ] `git diff main..nixos -- os/modules/*/src/` is **empty** (configs unchanged); the diff is dominated by `os/modules/*/default.nix` (new), `flake.nix` (new), `os/Containerfile` deletion, `os/lib/*.sh` deletions, and `Justfile` + `.github/workflows/build.yml` rewrites.
