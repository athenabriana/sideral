# nixos-port Context

Decisions captured during `/spec-create` on 2026-05-04. Locked decisions guide implementation autonomously; open questions await user lock before `/spec-design`.

---

## Locked decisions

### C-02: home-manager mode → NixOS module (auto-locked)

home-manager runs as a NixOS module (`home-manager.users.<user> = ...`), **not** standalone (per-user `home-manager switch`).

**Why**: The retired `nix-home` feature ran HM standalone because nix-on-Fedora-atomic could only ever be a per-user user-of-nix layer. On NixOS, system + user are owned by the same evaluator; module mode means a single `nixos-rebuild switch` brings both up. Eliminates the "first-login service" bootstrap class entirely.

**How to apply**: `flake.nix` imports `home-manager.nixosModules.home-manager` and each `nixosConfigurations.<host>` sets `home-manager.users.<user> = import os/modules/dotfiles;`. No standalone HM artifacts.

---

### C-06: Same-folder-structure interpretation → preserve `os/modules/<capability>/src/` byte-identical (auto-locked)

The user-facing instruction "try to keep same folder structure" + "1:1 port" + "keep all configurations" resolves to:

- Keep `os/modules/<capability>/` as the top-level capability directory.
- Keep `os/modules/<capability>/src/` subtrees byte-identical (config files unchanged).
- **Drop** `os/modules/<capability>/rpm/<spec>` subtrees on the `nixos` branch (no RPMs in nix; the metadata moves into the capability's `default.nix`).
- **Drop** `os/Containerfile`, `os/lib/{build,build-rpms,install-packages}.sh` (no OCI build; nix evaluator replaces them).
- **Collapse** `os/build/{fonts,nvidia}/` into `os/modules/{fonts,nvidia}/` (no longer a "build-time-only vs system" distinction; nix unifies).
- **Add** `os/modules/<capability>/default.nix` (new — the NixOS module).
- **Add** `flake.nix` at repo root.
- **Add** `os/hosts/{sideral,sideral-nvidia,sideral-iso}.nix` (per-variant entry-points; thin wrappers that import the modules).

**Why**: User said "try to keep same folder structure" not "preserve every artifact." `rpm/<spec>` files are Fedora-specific build artifacts that have no nix equivalent; preserving them as dead files would confuse readers. The `src/` subtrees are the actual configurations the user wants to keep.

**How to apply**: When porting a module, leave the `src/` tree alone, write `default.nix` next to it, delete `rpm/` if present.

---

### C-07: Branch model → `nixos` is parallel to `main` (auto-locked)

The `nixos` branch is a permanent fork of the layout. `main` keeps shipping the Fedora flavor; `nixos` ships the NixOS flavor. **No** in-place migration path. **No** GHA workflow on `main` is touched.

If a future "make NixOS the canonical flavor" decision is taken, that's its own feature spec — it would handle the canonical-flavor flip, R2 ISO key migration, GHA-workflow merge, and Fedora-flavor deprecation schedule.

**Why**: User said "in this pr lets make a nixos version" — implies a scoped branch port, not a destructive replacement.

**How to apply**: Every change in this PR lands only on the `nixos` branch. The PR target is `main` only as a final landing point if/when the user decides to merge.

---

### C-08: NVIDIA gating → boolean module attribute, two distinct nixosConfigurations (auto-locked)

Mirror the Fedora flavor's two-image-variants model: `nixosConfigurations.sideral` (open-source GPU stack) and `nixosConfigurations.sideral-nvidia` (proprietary). The `nvidia` module's content is gated on `config.hardware.nvidia.enable` so importing it from `sideral.nix` is a no-op.

**Why**: Fedora ships two OCI images so the kernel's nvidia-kmod is baked in only on the variant that needs it. NixOS doesn't bake kernel modules into the closure the same way (nvidia driver attaches at evaluation time when enabled), but the two-variant layout is still the right answer because it lets the ISO installer cleanly pick one or the other based on `lspci` without runtime detection complexity.

**How to apply**: `os/hosts/sideral.nix` does NOT import `os/modules/nvidia/default.nix`. `os/hosts/sideral-nvidia.nix` does. Both import the `niri-defaults` / `cli-tools` / `services` / `kubernetes` / `flatpaks` / `shell-ux` / `dotfiles` / `base` / `fonts` modules unconditionally.

---

### C-09: Distribution model → pure flake-pull only (user-locked 2026-05-04)

After install, users upgrade via `sudo nixos-rebuild switch --upgrade --flake github:<owner>/sideral#sideral`. No prebuilt binary cache, no Cachix, no nixos-bootc OCI parity. Each user hits nixpkgs's public `cache.nixos.org` for stock derivations (free, automatic) and builds sideral-specific closures locally.

**Why**: Simplest viable v1. Cachix adds signing-key + cache-budget + extra-CI maintenance that should be earned by demonstrated need; nixos-bootc is experimental as of early 2026 and most NixOS users never use that path.

**How to apply**: `.github/workflows/build.yml` does **not** push to a binary cache on this branch. First-rebuild cost (~5–15 min on typical connection) is acceptable. If first-rebuild times become a real complaint, Cachix slots in as a follow-on without spec changes.

---

### C-10: Installer → installer-only ISO with calamares + light sideral branding (user-locked 2026-05-04)

The ISO ships **calamares as the only interactive surface** in the live env. **No live niri session, no `liveuser` autologin, no SDDM in the live image.** Boot path: kernel → minimal X/Wayland → calamares window with sideral branding (logo on welcome/finish, sideral color scheme via custom CSS, BTRFS+zstd:1 partition defaults pre-filled, LUKS-encryption checkbox).

**Why**: Calamares is a standalone Qt app — it can't render inside niri or have Noctalia render its bar above it. A live niri+Noctalia preview followed by a visually-mismatched Qt-installer creates a jarring first impression. Better to have no preview than a misleading one. The first time the user sees niri+Noctalia is post-install, when it's the *real* desktop.

**How to apply**: `os/hosts/sideral-iso.nix`:
- Imports the NixOS installer-CD module (`<nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-base.nix>` or equivalent for `nixos-25.11`).
- Enables calamares via `services.installer.calamares.enable = true;` (or whichever attribute the pinned channel exposes).
- Disables SDDM, niri-default-session, liveuser autologin — anything that would create a live desktop. The only running services are calamares + its dependencies.
- Ships `os/iso/calamares/branding/sideral/{branding.desc,sideral-logo.svg,welcome.png}` for the visual brand.
- Ships `os/iso/calamares/modules/{partition.conf,users.conf,...}` for the wizard configuration.
- Ships `os/iso/calamares/pre-install.sh` (the `lspci` GPU-detect hook that writes `imports = [ ./sideral.nix ];` or `./sideral-nvidia.nix` into the target's `/etc/nixos/configuration.nix`).

Existing Fedora `iso/anaconda-hook.sh` and `iso/flatpaks.txt` retire on this branch. Existing `os/modules/flatpaks/live-iso.txt` retires (no live env to ship flatpaks into).

ISO target size: <2 GiB (closer to NixOS minimal-installation-cd than to Fedora's 5 GiB).

---

### C-11: nixpkgs channel → `nixos-25.11` stable (user-locked 2026-05-04)

Pin `nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";` and `home-manager.url = "github:nix-community/home-manager/release-25.11";`. `flake.lock` pins exact commits; `nix flake update` is the user-driven path to bump.

**Why**: Stable channel = predictable security backports + tested combinations. NixOS 25.11 aligns with Fedora 44's release window. Unstable would track newer niri/Noctalia faster but risks breakage.

**How to apply**: `flake.nix` inputs as above; CI runs `nix flake check` to enforce eval at the pinned channel.

---

### C-12: nushell as login-shell-default → `zsh` stays the canonical default (auto-locked)

Per the Fedora flavor's lock (STATE.md "Three parallel shells: bash + fish + zsh"), zsh is sideral's default interactive shell. `njust chsh nu` switches to nushell. Nushell ships in cli-tools but is **not** the default shell on a fresh install.

**Why**: `nushell` feature spec on the Fedora flavor is "ready for /spec-run" not "shipped." Until that lands on `main`, the nixos port mirrors current behavior.

**How to apply**: `users.users.<liveuser>.shell = pkgs.zsh;` in `os/hosts/sideral-iso.nix`. `users.defaultUserShell = pkgs.zsh;` in the per-host configs.

---

### C-13: just-based recipe pattern survives — no Rust/Go CLI rewrite (auto-locked; details superseded by C-14)

The "wrap `just` + ship a recipes file + invoke via short alias" pattern carries over from the Fedora flavor. Three recipe bodies edit (`update`, `apply-defaults`, internal `rpm-ostree` references); the other 7 recipes carry over unchanged.

What changes (per C-14): the alias renames `ujust` → `njust`, the wrapper drops its dependency on `ublue-os-just` and wraps upstream `just` directly, and the recipes file relocates from `/usr/share/ublue-os/just/60-custom.just` to `/etc/sideral/sideral.just`.

**Why**: Replacing the recipe runner with a sideral-native CLI is a refactor that doesn't help the 1:1 port. The pattern is fine; just retarget the bodies that mention rpm-ostree, drop the Universal-Blue dependency, and rename to mark NixOS-flavor identity.

---

### C-14: `ujust` → `njust` rename, wrapping upstream `just` directly (user-locked 2026-05-04)

The Universal-Blue `ujust` dependency (and the `ublue-os-just` package that provides it) retires entirely. Replacement: `njust` is a **direct wrapper around upstream `just`** — it does **not** call, depend on, or replace `ujust`/`ublue-os-just`.

Implementation:
- `os/modules/shell-ux/default.nix` adds `pkgs.just` to systemPackages and ships `njust` as a `pkgs.writeShellScriptBin` whose body is exactly `exec just --justfile /etc/sideral/sideral.just "$@"`.
- Recipes file relocates from `os/modules/shell-ux/src/usr/share/ublue-os/just/60-custom.just` to `os/modules/shell-ux/src/etc/sideral/sideral.just`.
- Recipe names + bodies carry over with three rewrites (`update`, `apply-defaults`, internal `rpm-ostree` refs).

User-motd loader (was provided by `ublue-os-just` as `/etc/profile.d/user-motd.sh`) is sideral-authored at `os/modules/shell-ux/src/etc/profile.d/sideral-motd.sh`.

**Why**: User chose `njust` over `ujust` to mark this as the NixOS-port command. Avoids confusion when both flavors coexist (Fedora's `main` branch keeps `ujust`).

**How to apply**: All NXP-35..44 references read `njust`. The file at `/usr/share/ublue-os/just/60-custom.just` does not exist on the NixOS image; `/etc/sideral/sideral.just` does.

---

### C-15: `/etc/os-release` purged of Fedora-isms (user-locked 2026-05-04)

The static `os/modules/base/src/etc/os-release` is **deleted**. NixOS writes `/etc/os-release` itself via the `nixos-version` mechanism; sideral overrides via:

```nix
system.nixos.distroId = "sideral";
system.nixos.distroName = "sideral";
system.nixos.variant_id = "open-source";  # or "nvidia" in the nvidia host
```

Result: no `ID_LIKE=fedora`, no `REDHAT_BUGZILLA_PRODUCT`, no `REDHAT_SUPPORT_PRODUCT`. `cat /etc/os-release | grep -i fedora` returns nothing on the running system.

**Why**: NixOS' built-in os-release writer is the idiomatic source. Layering a static file on top would fight nix's activation logic.

**How to apply**: Delete `os/modules/base/src/etc/os-release` on the `nixos` branch. Add the three settings to `os/modules/base/default.nix`.

---

### C-16: `yum.repos.d/` trees deleted (user-locked 2026-05-04)

All `os/modules/*/src/etc/yum.repos.d/` subtrees delete on the `nixos` branch. Affected:

- `os/modules/base/src/etc/yum.repos.d/{mise,vscode}.repo`
- `os/modules/cli-tools/src/etc/yum.repos.d/{carapace,nushell}.repo`
- `os/modules/niri-defaults/src/etc/yum.repos.d/terra.repo`
- `os/modules/kubernetes/src/etc/yum.repos.d/kubernetes.repo`

Every previously-RPM-repo-sourced package now comes from nixpkgs (or a flake input — locked at `/spec-design` per D-B).

**Why**: Without dnf or rpm-ostree, these files are inert.

**How to apply**: `git rm -r os/modules/*/src/etc/yum.repos.d/` on the `nixos` branch.

---

### C-17: Flatpak management → declarative via `nix-flatpak` (user-locked 2026-05-04)

Adopt `github:gmodena/nix-flatpak` as the flatpak module. The 11-entry curated set lives in `os/modules/flatpaks/default.nix` as `services.flatpak.packages = [ ... ];` (or whichever attribute nix-flatpak's pinned release exposes). Drop entries from the list → next `nixos-rebuild switch` uninstalls; add entries → next switch installs.

The Fedora-flavor purge mechanism (`/etc/sideral-flatpak-purge` + every-boot self-heal service) retires entirely:

- `os/modules/flatpaks/install.sh` deletes
- `os/modules/flatpaks/src/etc/{sideral-flatpak-purge,sideral-flatpak-remotes,flatpak-manifest,systemd/system/sideral-flatpak-install.service}` all delete
- The "self-heal on every boot" semantics is replaced by "activation-time reconciliation" (nix-flatpak's contract)

The `os/modules/flatpaks/live-iso.txt` (Zen-only on the live image) carries over as a separate `services.flatpak.packages` set inside `os/hosts/sideral-iso.nix`.

**Why**: Declarative is the nix idiom; the rpm-style "self-heal service" pattern duplicates work nix-flatpak already does.

**How to apply**: `flake.nix` adds `nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";` (resolve exact ref at `/spec-design`). `os/modules/flatpaks/default.nix` imports `nix-flatpak.nixosModules.nix-flatpak`. The Fedora-side artifacts listed above delete.

---

## Decisions deferred (do NOT lock here)

- **D-A: Bootloader swap** (sd-boot vs rEFInd vs Limine vs default). NixOS defaults to sd-boot for UEFI, GRUB for BIOS. Bootloader swap is a separately-scoped feature per user memory; do not bundle.
- **D-B: noctalia / Quickshell sourcing** (nixpkgs vs flake input vs in-tree package). Mechanical concern — at design time we'll check `nix-env -qa noctalia-shell` against the pinned channel and either use the nixpkgs entry, write a derivation in `os/pkgs/`, or pull a flake input. Lock at `/spec-design`.
- **D-C: nh vs nixos-rebuild for `njust update` body**. Mechanical — if `nh` is in nixpkgs at the pinned channel, prefer it; otherwise use raw `nixos-rebuild`. Lock at `/spec-design`.
- **D-D: flatpak declarative installer** (`nix-flatpak` vs services.flatpak's declarative options). Mechanical — pick at `/spec-design` based on what supports the curated 11-entry manifest cleanly.
- **D-E: kanata as `services.kanata` vs hand-rolled systemd unit**. Mechanical — check the pinned channel for the service module; default to it if available.
- **D-F: Three-island Quickshell QML**. Same status as on the Fedora flavor: deferred to follow-on `niri-islands` feature spec.

---

## Format note

Locked decisions are written for future-me as imperatives ("how to apply"). Open questions list options with the recommended default italicized; user replies in plain text ("1, 1, 1" or numbered overrides) and we re-write the matching C-NN entry to "auto-locked → user-locked: <choice>" before `/spec-design`.
