# Silverfox — Nix + nh — Context

**Gathered:** 2026-05-10 (updated 2026-05-13)
**Spec:** `.specs/features/nix/spec.md`
**Status:** Ready for design

---

## Feature Boundary

Ship nix + nh on the silverfox image so user-level packages (CLI tools, runtimes, flatpaks) are declared in a single `flake.nix` and applied via `fox home sync`. Nix is installed by a first-boot oneshot (Determinate installer, ostree planner). `nh` replaces home-manager entirely — `nh home switch` applies user config, `nh clean` handles garbage collection. The stow tree owns dotfiles; the nix flake is a stow package like bash/zsh/ghostty/zed. No `fox.toml` abstraction layer — user writes `flake.nix` directly. Fox wraps the workflow: `init`, `sync`, `diff`, `edit`.

---

## Implementation Decisions

### D-01 — Image-baked binary, first-boot activation

- **Decision:** The Determinate `nix-installer` binary is pre-downloaded at image build time and staged at `/usr/libexec/nix-installer`. A systemd oneshot (`silverfox-nix-bootstrap.service`) runs the installer on first boot. User does NOT run any install command post-rebase.
- **Why:** The installer is designed to run on a deployed atomic system, not inside a `podman build` sandbox (it creates systemd units, the `/nix` mount, and nixbld users against the real root). Pre-downloading at build time avoids "first boot needs curl" while keeping execution in the right environment.
- **Trade accepted:** Nix not available on first login — oneshot must complete first (~30s-2min). Not an RPM, not removable via `rpm-ostree override remove`.

### D-02 — Multi-user (nix-daemon) mode

- **Decision:** nix-daemon as systemd system service; nixbld1..32 users created at image build time. Single-user mode rejected.
- **Why:** Multi-user is the standard daemon shape. nh's `nh home switch` expects a running daemon for user-level operations.
- **Trade accepted:** ~32 nixbld system users, daemon process at boot. Negligible on a desktop.

### D-03 — No prepare-root.conf — systemd .mount unit handles composefs

- **Decision:** Silverfox does NOT ship a custom `/etc/ostree/prepare-root.conf`. The Determinate installer's `ostree` planner creates a systemd `.mount` unit bind-mounting `/var/lib/nix` to `/nix`. Works with any composefs state.
- **Why:** Shipping `prepare-root.conf` from the image creates an OSTree conflict boundary. The `.mount` unit approach avoids the problem entirely — `/var/lib/nix` is in `/var`, always writable.
- **Trade accepted:** Depends on systemd boot ordering (`After=ostree-remount.service`, `BindsTo=var.mount`). Verified by upstream testing.

### D-04 — `/nix` persistence at `/var/lib/nix`

- **Decision:** `nix-installer install ostree --persistence /var/lib/nix`. Nix store in `/var/lib/nix`; `/nix` mounted as bind-mount via systemd `.mount` unit.
- **Why:** `/var` survives ostree generations by design. Addresses the historic post-upgrade survival blocker.
- **Trade accepted:** None — this is the upstream-blessed atomic path.

### D-05 — No declarative state in the image (no pinned channels, no preinstalls)

- **Decision:** Image ships nix + daemon, period. No nixpkgs pin, no profile preinstalls.
- **Why:** Users own their `flake.lock`. Image stays neutral.
- **Trade accepted:** First `fox home init` downloads nixpkgs + nh packages (~2-5 min). Only happens once.

### D-06 — Nix as source of truth: CLI tools and flatpaks

- **Decision:** `silverfox-cli-tools` is reduced to bootstrap tools (stow, zsh + fish-parity, starship, carapace-bin, ghostty, zed). Day-to-day tools (atuin, fzf, bat, eza, ripgrep, zoxide, gh, git-lfs, gcc, make, cmake) migrate to `home.packages` in flake.nix. Flatpaks managed exclusively via `services.flatpak.packages` (nix-flatpak) — no `/etc/flatpak-manifest`, no first-boot flatpak service.
- **Why:** Single source of truth. `nh home switch` applies CLI packages + flatpaks declaratively and atomically. Tool removal = remove from flake + `nh home switch`. No divergence between what RPM installs and what the user wants.
- **Trade accepted:** Bootstrap window — between first boot and `fox home init` completing, CLI tools are not available (~5–10 min, once). Bootstrap tools (zsh, stow, fox, zed) are available immediately via RPM.

### D-07 — Direct flake.nix, no fox.toml generator

- **Decision:** User writes `~/.config/silverfox/flake.nix` directly. No `fox.toml` → flake generator layer.
- **Why:** `nh home switch` expects a home-manager-compatible flake. Any generator would be incomplete. For a single-user image, the extra layer adds maintenance burden with zero gain.
- **Trade accepted:** User must learn basic nix syntax to add packages. The starter flake.nix provides commented examples for common cases.

### D-08 — Flake is a stow package

- **Decision:** The `flake.nix` lives at `~/.config/silverfox/stow/nix/.config/silverfox/flake.nix`. Stow creates `~/.config/silverfox/flake.nix` as a symlink. `nh home switch` runs against the symlink target — editing the flake edits the real file inside the stow tree.
- **Why:** Stow is the existing dotfile layer. Making the nix flake a stow package means zero new patterns: `fox home sync` runs `stow -R nix` before `nh home switch`, `fox home factory-reset` skips the nix stow package (doesn't wipe user's flake).
- **Trade accepted:** Two-step sync (stow + nh home switch). The stow step is near-instant (~100ms); the nh switch is the slow part.

### D-09 — `nh` via nix profile, not image-baked

- **Decision:** `nh` is installed via `nix profile install nixpkgs#nh` on first `fox home init`, not pre-baked in the image.
- **Why:** nh evolves fast (v4.3.2 in April 2026). Installed via user's nix profile, it follows the user's channel pinning, not the image release cycle. Pre-baking would require updating the image to get new nh versions.
- **Trade accepted:** First `fox home init` downloads nh (~200MB with nixpkgs closure). All subsequent runs are instant (cached in `/nix/store`).

### D-10 — `fox nix-doctor` covers nh

- **Decision:** The diagnostics recipe checks nix daemon status, `/nix` mount, SELinux context, plus nh version and flake symlink validity.
- **Why:** nh failures present differently than nix daemon failures. A single health report saves debugging time.

### D-11 — NH_FLAKE set in shell init

- **Decision:** `NH_FLAKE="$HOME/.config/nix"` is exported in `~/.bashrc` and `~/.zshrc` (stow packages), guarded by `command -v nh`. This way `nh home switch -c <user>` resolves the flake without extra arguments.
- **Why:** The cleanest way to configure the flake path. The NixOS module does the same via `programs.nh.flake`; on Fedora, the rc file is the equivalent. The `command -v` guard follows the existing pattern (starship, atuin, etc.).
- **Where:** `stow/bash/.bashrc` and `stow/zsh/.zshrc` in the `home/` module.
- **Trade accepted:** Only set after `nh` is installed (post `fox home init`). Before that, `NH_FLAKE` doesn't exist — but it's not needed since `nh` is not available.

---

## Module layout

```
os/modules/
├── nix/                    NEW — system-level nix installation
│   ├── src/
│   │   ├── usr/libexec/
│   │   │   └── nix-installer          [pre-downloaded at build]
│   │   ├── usr/lib/systemd/system/
│   │   │   └── silverfox-nix-bootstrap.service
│   │   └── etc/sudoers.d/
│   │       └── nix-sudo-env
│   ├── rpm/
│   │   └── silverfox-nix.spec
│   └── nixbld-users.sh                [creates users 30000-30031 at build]
│
├── home/                   EXISTING — stow packages (bash, zsh, ghostty, zed, mise)
│                            [nix stow package added to src tree at
│                             .config/silverfox/stow/nix/.config/nix/flake.nix]
│
└── fox/                    EXISTING — justfile dispatcher
    └── src/recipes/
        └── silverfox.justfile            [add home-init, home-sync (nh home switch),
                                         home-diff, home-edit, nix-doctor,
                                         update cleanup for nh clean]
```

Key difference from the previous design: no `home-manager/` module. The nix flake lives inside the existing `home/` module's stow tree.

---

## Configuration flow

```
User edits ~/.config/nix/flake.nix
        │
        ▼
fox home sync
        │
        ├── stow -R nix          (re-asserts symlinks)
        └── nh home switch -c $(whoami)
                                │   (NH_FLAKE=$HOME/.config/nix resolves the flake)
                                └── nix build + activate homeConfigurations.<user>
                                    (nh handles build/activation natively)
```

---

## Specific References

- nh (nix-community/nh): https://github.com/nix-community/nh — unified CLI wrapper, replaces home-manager.
- Determinate Systems nix-installer: https://github.com/DeterminateSystems/nix-installer — upstream.
- User gist: https://gist.github.com/queeup/1666bc0a5558464817494037d612f094 — reference for `ostree` subcommand + `--persistence`.
