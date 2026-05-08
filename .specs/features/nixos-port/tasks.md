# nixos-port Tasks

> Status: **2026-05-04** — Phases A–E complete in the working tree (uncommitted). Spec at `spec.md` (52 reqs). Design at `design.md`. Branch: `nixos`.

Validation gate: `nix flake check` and `nix build .#nixosConfigurations.sideral.config.system.build.toplevel` run in CI (no local nix on the dev machine). Tasks land in topological order so partial states never break the previous one.

## Status

| Phase | Tasks | State | Note |
|---|---|---|---|
| A | T01–T04 | ✅ done | Fedora-only artifacts deleted; sideral.just relocated + 3 recipe rewrites; sideral-motd.sh added; user-motd refreshed for `njust`. |
| B | T05–T08 | ✅ done | flake.nix + 4 host configs (common, sideral, sideral-nvidia, sideral-iso). |
| C | T09–T20 | ✅ done | All 9 module default.nix + 2 in-tree pkgs (noctalia-shell, noctalia-qs) written. |
| D | T21–T24 | ✅ done | calamares branding/settings/modules + pre-install.sh shipped. |
| E | T25–T27 | ✅ done | Justfile rewrite, .github/workflows/build.yml rewrite, README.md updated. |

## /spec-run finalisation gates (require nix-eval feedback to close)

These can only be exercised once CI runs `nix flake check` on the pinned channel — they're flagged for follow-up rather than blockers for opening the PR:

1. **noctalia-shell + noctalia-qs SHA256** — both `os/pkgs/<name>/default.nix` ship `lib.fakeHash`. First CI eval surfaces the real hashes; commit them.
2. **Nushell plugin coverage** — `pkgs.nushellPlugins.{file,rpm,explore}` may not exist at nixos-25.11. If they do, add to `os/modules/cli-tools/default.nix`. If not, accept the gap (formats/gstat/query already covered).
3. **calamares NixOS integration** — current host wires `services.displayManager.sddm.settings.Autologin.Session = "calamares-sideral.desktop"` + a custom `services.xserver.windowManager.session`. Verify `calamares-nixos` is the right derivation name and the autostart actually runs at first ISO boot. Out-of-tree alternatives: `nixos-calamares` flake.
4. **`programs.niri.enable`** — verify the option exists in nixos-25.11. If absent, drop and rely on the bare `pkgs.niri` package + `xdg/wayland-sessions/niri.desktop` entry from the existing `src/`.
5. **`services.kanata`** — verify the option exists at nixos-25.11. If `enable` evaluates fine but `keyboards.<n>.devices = []` is rejected, switch to a hand-rolled `systemd.services.kanata` + udev rule.
6. **`magic-nix-cache-action`** — confirm DeterminateSystems' GHA action is current; bump the pin if a newer release is out.
7. **`hardware.nvidia` option surface** — current nvidia module sets `hardware.nvidia.{modesetting.enable,open,powerManagement.enable,nvidiaSettings,package}`. If `hardware.nvidia` schema changed (e.g. `package` moved under a sub-attribute), realign at the first eval failure.
8. **`isoImage.appendToMenuLabel`** vs the current iso-image module attribute name — drop the suffix line in `os/hosts/sideral-iso.nix` if rejected.
9. **home-manager auto-mapping over `users.users`** — `os/hosts/common.nix` maps every `isNormalUser` to `home-manager.users.<name>`. If the user-creation module ordering causes circular deps on a fresh install, fall back to a per-host `home-manager.users.<known-username>` block.

## Phase A — Fedora-only artifact retirement

### T01 — Delete RPM specs + build orchestrators
**What**: remove every Fedora-only build artifact.
**Where**:
- `os/Containerfile`
- `os/lib/{build,build-rpms,install-packages}.sh`
- `os/modules/*/rpm/`  (8 spec dirs)
- `os/modules/*/packages.txt`  (cli-tools, services, kubernetes, niri-defaults, flatpaks)
- `os/modules/cli-tools/{hide-chromium,nushell-plugins-install}.sh`
- `os/modules/flatpaks/install.sh`
- `os/modules/base/src/etc/os-release`  (C-15)
- `os/modules/*/src/etc/yum.repos.d/`  (C-16; 4 dirs)
- `os/modules/flatpaks/src/etc/{sideral-flatpak-purge,flatpak-manifest,sideral-flatpak-remotes,systemd/}`  (C-17)
- `os/modules/flatpaks/live-iso.txt`
- `os/modules/dotfiles/src/etc/profile.d/sideral-chezmoi-defaults.sh`  (no first-login bootstrap)
- `os/modules/niri-defaults/src/usr/lib/{tmpfiles.d,systemd/}`  (NixOS handles unit pinning + presets via module options)
- `iso/`  (entire directory; replaced by `os/iso/`)
**Done when**: `git status` shows the deletions; no `*.spec`, `Containerfile`, or `yum.repos.d` remains under `os/`.
**Gate**: text-only — none.

### T02 — Move build-time trees into modules
**What**: collapse `os/build/{fonts,nvidia}/` into `os/modules/{fonts,nvidia}/`.
**Where**:
- `os/build/fonts/` deletes (just a packages.txt — content goes into `os/modules/fonts/default.nix`).
- `os/build/nvidia/` content moves to `os/modules/nvidia/src/`:
  - `modprobe.d/sideral-nvidia.conf`
  - `nvidia-app-profiles/50-niri.json`
  - `environment.d/90-sideral-niri-nvidia.conf`
  - `kargs.d/00-nvidia.toml` deletes (content encoded as `boot.kernelParams` in default.nix)
  - `niri.config.d/sideral-nvidia.kdl` deletes (already lives in `os/modules/niri-defaults/src/etc/xdg/niri/config.d/`)
  - `apply.sh` deletes (logic moves to `os/modules/nvidia/default.nix`)
  - `packages.txt` deletes
- `os/build/` directory deletes.
**Done when**: `os/build/` does not exist; `os/modules/nvidia/src/` contains the three preserved files.
**Gate**: text-only — none.

### T03 — Rename `60-custom.just` → `sideral.just` (C-14)
**What**: relocate the recipes file and edit three recipe bodies.
**Where**:
- Move `os/modules/shell-ux/src/usr/share/ublue-os/just/60-custom.just` → `os/modules/shell-ux/src/etc/sideral/sideral.just`.
- Edit `update` body (NXP-36): `sudo nixos-rebuild switch --upgrade --flake github:athenabriana/sideral#$(. /etc/os-release; echo "$VARIANT_ID")`.
- Edit `apply-defaults` body (NXP-37): single echo line pointing at `nixos-rebuild switch`.
- Edit `chezmoi-init` recipe text: drop references to `/usr/share/sideral/chezmoi/` first-login auto-apply.
- Drop the old `usr/share/ublue-os/` directory tree.
**Done when**: `os/modules/shell-ux/src/etc/sideral/sideral.just` exists with three rewrites; old path is gone.
**Gate**: text-only — none.

### T04 — Add `sideral-motd.sh` profile.d printer (C-14)
**What**: replace ublue-shipped `/etc/profile.d/user-motd.sh` with a sideral-authored equivalent.
**Where**: `os/modules/shell-ux/src/etc/profile.d/sideral-motd.sh` (~10 lines: print `/etc/user-motd` unless `~/.config/no-show-user-motd` exists).
**Done when**: file exists, is +x, runs in any login shell.
**Gate**: `bash -n` syntax check.

## Phase B — Flake skeleton + hosts

### T05 — `flake.nix` at repo root
**What**: inputs (nixpkgs nixos-25.11, home-manager release-25.11, nix-flatpak), outputs (three nixosConfigurations + packages.x86_64-linux + formatter).
**Where**: `flake.nix` (NEW).
**Depends on**: T01, T02.
**Done when**: file exists per design.md "flake.nix" section; `git diff` shows it.
**Gate**: text — `nix flake check` runs in CI on push.

### T06 — `os/hosts/common.nix`
**What**: shared module-import list for sideral + sideral-nvidia.
**Where**: `os/hosts/common.nix`.
**Depends on**: T05.
**Done when**: imports the 9 modules + home-manager + nix-flatpak; sets `system.stateVersion = "25.11"; nixpkgs.config.allowUnfree = true;`.

### T07 — `os/hosts/sideral.nix` (open-source variant)
**What**: thin wrapper, imports common, sets hostname + variant_id.
**Depends on**: T06.

### T08 — `os/hosts/sideral-nvidia.nix` (NVIDIA variant)
**What**: thin wrapper, imports common + `os/modules/nvidia`, sets `hardware.nvidia.enable = true;`.
**Depends on**: T06, T19.

## Phase C — Module default.nix files

Order picked so dependencies (in-tree pkg derivations, files referenced by other modules) land before consumers.

### T09 — `os/modules/base/default.nix`
**What**: os-release identity + containers/policy.json.
**Done when**: `system.nixos.{distroId,distroName}` set; `environment.etc."containers/policy.json".source` wired.

### T10 — `os/modules/fonts/default.nix`
**What**: `fonts.packages` with the 6 Fedora-equivalent font sets (NXP-17).

### T11 — `os/modules/cli-tools/default.nix`
**What**: systemPackages from packages.txt translation table; chromium-hide via override; nushell plugins via nixpkgs derivations.

### T12 — `os/modules/services/default.nix`
**What**: podman + dockerCompat, podman-compose, services.flatpak, distrobox conf.

### T13 — `os/modules/kubernetes/default.nix`
**What**: kubectl/kind/helm + KIND_EXPERIMENTAL_PROVIDER/MINIKUBE_DRIVER env vars.

### T14 — `os/modules/shell-ux/default.nix`
**What**: njust wrapper, /etc/zshrc, /etc/user-motd, /etc/mise/config.toml, motd printer, profile.d snippets, rclone-gdrive systemd user service.

### T15 — `os/modules/flatpaks/default.nix`
**What**: declarative flatpak set via nix-flatpak (11 entries from manifest, flathub remote).

### T16 — `os/pkgs/noctalia-shell/default.nix`
**What**: in-tree derivation; pin v4.7.6 (parity with niri-defaults README).
**Note**: SHA256 placeholder `lib.fakeHash` — surfaced as a /spec-run finalisation gate (D-B).

### T17 — `os/pkgs/noctalia-qs/default.nix`
**What**: in-tree derivation; pin v0.0.12.
**Note**: same SHA256 surfacing.

### T18 — `os/modules/niri-defaults/default.nix`
**What**: heaviest module — niri/SDDM/silent-theme/matugen/ghostty/kanata/IME, niri-config drop-in gated on hardware.nvidia.enable.
**Depends on**: T16, T17.

### T19 — `os/modules/nvidia/default.nix`
**What**: gated NVIDIA stack — videoDrivers, kargs, modprobe, env vars, app profiles. `lib.mkIf config.hardware.nvidia.enable`.

### T20 — `os/modules/dotfiles/default.nix`
**What**: home-manager module — xdg.configFile + home.file + programs.{starship,atuin,zoxide,fzf,bat,eza,git,gh,nushell,helix} + activation.installNuPrompts.

## Phase D — ISO

### T21 — `os/iso/pre-install.sh`
**What**: lspci → write `/etc/nixos/configuration.nix` referencing sideral.nix or sideral-nvidia.nix on target.

### T22 — `os/iso/calamares/branding/sideral/`
**What**: branding.desc + sideral-logo.svg + welcome.png + stylesheet.qss (light brand per C-10). Logo + welcome reuse `os/modules/niri-defaults/src/usr/share/wallpapers/sideral/default.jpg` for now (placeholder until a dedicated logo asset is produced).

### T23 — `os/iso/calamares/{settings,modules/{partition,users,welcome,finished}}.conf`
**What**: wizard sequence per design.md (welcome → locale → keyboard → partition → users → summary → install → finish) with BTRFS+zstd:1 partition defaults.

### T24 — `os/hosts/sideral-iso.nix`
**What**: installer-only ISO host — installer-CD profile + calamares + branding + pre-install hook + liveuser. No niri/SDDM/flatpaks (C-10).

## Phase E — Tooling

### T25 — `Justfile` rewrite
**What**: lint/build/build-nvidia/build-iso/rebase/rollback/diff/fmt recipes targeting nixos-rebuild.

### T26 — `.github/workflows/build.yml` rewrite
**What**: nix-flake-driven workflow (matrix for sideral + sideral-nvidia closures, release job for ISO + R2 upload + semantic-release). magic-nix-cache-action for cache.

### T27 — `README.md` — NixOS section
**What**: install path, ISO download, `nixos-rebuild --flake github:<owner>/sideral#sideral` upgrade flow, no-in-place-migration note (NXP-45 / NXP-47).

## Implementation strategy

- Phase A is a single deletion sweep — one commit.
- Phases B–E land in 1–3 commits each, grouped by tight dependency.
- Each commit message uses Conventional Commits + scope: `feat(nixos): …`, `chore(nixos): …`.
- /spec-run finalisation TODOs (carry into validation):
  1. Fill noctalia-shell + noctalia-qs upstream SHA256 (the in-tree derivations ship with `lib.fakeHash` until CI's first eval surfaces the right value).
  2. Confirm `pkgs.nushellPlugins.{file,rpm,explore}` availability at nixos-25.11 (deferred to follow-on if absent).
  3. Pick calamares NixOS module (out-of-tree flake vs hand-rolled systemd unit).
  4. Confirm `programs.niri` and `services.kanata` evaluate on nixos-25.11.
  5. Verify `magic-nix-cache-action` is current.
