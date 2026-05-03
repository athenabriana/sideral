# sideral — Project State

Persistent memory: decisions, blockers, lessons, todos, deferred ideas.

## Current focus
- **No feature in flight.** `chezmoi-home` (the most recently-spec'd feature) effectively shipped on 2026-05-02 — every commit since the 2026-05-01 source-tree landing has gone through the `build-sideral` CI workflow (matrix amd64 × {open, nvidia}, ending in `bootc container lint`), and the major post-spec changes (module refactor, docker→podman, NVIDIA variant, kubernetes module, flatpak grow-out) all required `just build`-equivalent CI passes to merge. T15's "needs a host with podman + shellcheck" gate is met by CI itself.
- Next candidates: **`niri-shell`** (fully spec'd, ready for `/spec-design`) and **`nushell`** (spec'd 2026-05-02, ready for `/spec-run`). Can proceed in either order; `nushell` is smaller and independent.

## Past features (shipped)

- **`chezmoi-home`** — replaces `nix-home` (retired pre-VM-verification 2026-05-01). 23 requirements, 9 locked decisions. Drops nix entirely (composefs/SELinux/post-upgrade frictions on Fedora atomic 42+), restores 14 CLI tools as RPMs in a `sideral-cli-tools` sub-package, adds VS Code via Microsoft repo (restores ATH-14/15), centralizes shell-init wiring in `/etc/profile.d/sideral-cli-init.sh` shipped by `sideral-shell-ux`. User runs `chezmoi init --apply <repo>` themselves — no auto-bootstrap service. Source-tree changes landed 2026-05-01 (T01–T14); CI-validated continuously since via the rootless-podman / module-refactor / NVIDIA / kubernetes / Bazaar / flatpak-grow PRs. Spec preserved at `.specs/features/chezmoi-home/`.
- **`sideral-rpms`** — 26 requirements, inline RPM build inside the Containerfile (rpmbuild + `rpm -Uvh --replacefiles` + `rpm -e` toolchain teardown in one RUN layer). Renamed from `sideral-copr` 2026-04-29 when the Copr publishing path was dropped (D-15). See `.specs/features/sideral-rpms/spec.md`. Phase R landed 2026-04-30 (CI run 25188178498, sha `e06bc39`, 6m24s end-to-end). Signing requirements (ACR-27..29) still parked until user flips to signed-rebase; see `os/modules/signing/UPGRADE.md`.
- **`sideral`** — fork from `fedora-sideral`/Hyprland lineage into GNOME + tiling-shell on `silverblue-main:43`. 27 requirements across 5 user stories. See `.specs/features/sideral/spec.md`.
  - Superseded by `nix-home` then partially restored by `chezmoi-home`: ATH-14, ATH-15 (vscode.repo + RPM install) restored via chezmoi-home CHM-09. ATH-17 restored as image-build-time RPM (no first-login service). ATH-23, ATH-24, ATH-26 stay superseded (mise config + bashrc activation now user-managed via chezmoi).
  - 2026-04-23 cleanup: ATH-12 (helium → Zen flatpak — itself reverted 2026-05-01, see below), ATH-18 (now superseded again — VS Code is back as RPM), ATH-13 count (7 → 8 → 7 → **11** flatpaks; latest from 2026-05-02 manifest grow-out).
  - ATH-04 amended: 5 → 4 enabled extensions (bazaar-integration retired 2026-05-01 alongside original Bazaar→GNOME-Software swap; later GNOME-Software→Bazaar re-swap on 2026-05-02 did NOT bring the integration extension back — Bazaar is a flatpak now, not an in-shell integration). Current enabled set: appindicator + dash-to-panel + tilingshell + rounded-window-corners.
  - ATH-11 (sentinel-gated once-only run) superseded 2026-05-01: service runs every boot as forward-compat self-heal, plus a third active-purge pass added 2026-05-02. Still valid: ATH-01..10, ATH-16, ATH-19..22, ATH-25, ATH-27.

## Past feature (retired pre-shipping)
- `nix-home` — designed and implemented locally (40 requirements, 15 locked decisions) but retired before VM verification on 2026-05-01. Reason: composefs vs nix-installer ostree planner ([nix-installer#1445](https://github.com/DeterminateSystems/nix-installer/issues/1445)), SELinux mislabel of /nix store paths ([#1383](https://github.com/DeterminateSystems/nix-installer/issues/1383), still open), and `/nix` + nix-daemon disappearing after `rpm-ostree upgrade` on F42+ (multiple Universal Blue forum reports). Replaced by `chezmoi-home`. Spec preserved at `.specs/features/nix-home/spec.md` for historical reference. See `.specs/features/chezmoi-home/context.md` D-01.

## Roadmap
- See `.specs/project/ROADMAP.md` for queued (`image-ops`, `niri-shell`) and backlog features.

## Pending decisions
- **Signed-rebase flip** — currently `ostree-unverified-registry:` is canonical. To flip: replace `os/modules/signing/src/etc/containers/policy.json` with the strict `sigstoreSigned` schema (template in `os/modules/signing/UPGRADE.md`), update README's install command. Keyless OIDC signing of the OCI image already runs in `build.yml`. (Same work as ACR-29.)
- **Niri vs GNOME — fully replace, or ship as a parallel `sideral-niri` variant?** Tracked in `.specs/features/niri-shell/context.md`.

## Locked decisions

### Source tree layout (2026-05-02 — module refactor, commit `9aef370`)
- **`os/lib/{build,build-rpms}.sh`** — orchestrator + inline-RPM driver. Replaces `os/build.sh` + `os/build-rpms.sh`.
- **`os/modules/<capability>/`** — every capability owns one dir holding its `packages.txt`, `*.sh` scripts, and `rpm/<spec>` + `src/` tree. Replaces the previous `os/build_files/features/` + `os/packages/sideral-*/` split.
- Module list: `containers desktop flatpaks fonts kubernetes meta nvidia shell-init shell-tools signing`.
- Build order in `os/lib/build.sh`: `shell-tools desktop containers kubernetes fonts flatpaks nvidia` — shell-tools first because `sideral-cli-tools.spec` Requires every binary it installs; nvidia last so variant tweaks land on the final tree.
- Modules without `packages.txt` or `*.sh` are silently skipped by the orchestrator (signing, shell-init, meta) — they only contribute via the inline RPM build.
- Sub-package names kept stable across the refactor for upgrade safety (`sideral-base`, `sideral-services`, `sideral-shell-ux`, etc.); the **module dir** name is the descriptive one.
- Build scripts committed with +x via `git update-index --chmod=+x`; `/ctx` is bind-mounted read-only so runtime chmod is no longer possible.
- `just lint` now runs `shellcheck os/lib/*.sh os/modules/*/*.sh`.

### Desktop / GNOME
- **GNOME + tiling-shell**, Hyprland dropped entirely. Currently 4 enabled extensions: `appindicator`, `dash-to-panel` (Fedora-main RPMs) + `tilingshell`, `rounded-window-corners` (e.g.o, fetched at image build by `os/modules/desktop/extensions.sh`).
- **App store (2026-05-02): Bazaar (Flathub) is canonical.** gnome-software + gnome-software-rpm-ostree are actively removed from the inherited base by `os/lib/build.sh`'s prune step. OS-update notifications come from inherited `ublue-os-update-services`; RPM layering is done via the `rpm-ostree` CLI. Matches bluefin's current direction. The 2026-05-01 `gnome-software` swap (which itself replaced an earlier Bazaar) was reversed once Bazaar's flatpak-first UX matured.
- **dconf override `20-sideral-gnome-software`** still ships (cheap defensive default in case gnome-software ever re-enters via user override) but is functionally inert in the shipped image.
- **Inherited-base prune** (`os/lib/build.sh`): `firefox`, `firefox-langpacks`, `dconf-editor`, `gnome-software`, `gnome-software-rpm-ostree`. `htop` evaluated and **kept** (pairs with inherited `nvtop` — htop covers CPU/RAM/processes, nvtop covers GPU).

### Browser
- **Zen Browser** (`app.zen_browser.zen` from Flathub). Preinstalled at image build by `os/modules/flatpaks/install.sh`; updates via standard `flatpak update` (run nightly by inherited `ublue-os-update-services`).
- **Chromium installed but hidden** via `NoDisplay=true` patched into `/usr/share/applications/chromium*.desktop` by `os/modules/shell-tools/hide-chromium.sh`. For headless automation (puppeteer/playwright), web-app debugging, fallback rendering. Invokable as `chromium-browser`.

### Editor
- **Editor split** (2026-05-02): `EDITOR=hx`, `VISUAL=code`. Helix is modal-default for terminal contexts (git commit, sudoedit, mise edit, less's `v`, ssh sessions); VS Code wins where `$VISUAL` is checked first (Ctrl+P quick-open, some git frontends).
- VS Code via Microsoft RPM repo at `packages.microsoft.com/yumrepos/vscode` (sideral-base ships `/etc/yum.repos.d/vscode.repo`). Extensions install from the marketplace on first launch (Remote-SSH + Remote-Containers expected).

### Container runtime (2026-05-02)
- **Rootless podman + docker compatibility shims.** Layered RPMs: `podman-docker` (installs `/usr/bin/docker` wrapper + `/etc/profile.d/podman-docker.sh` setting `DOCKER_HOST=unix:///run/user/$UID/podman/podman.sock`) and `podman-compose` (Python compose v2 ~95% parity).
- `sideral-services` ships `/usr/lib/systemd/user/sockets.target.wants/podman.socket → ../podman.socket` so the per-user podman API socket comes up on first login without `systemctl --user enable podman.socket`.
- **docker-ce stack retired**: `docker-ce.repo`, `containerd.io --allowerasing` swap, the docker group footgun, and the `Requires: docker-ce` from sideral-base all gone.
- `/etc/distrobox/distrobox.conf` migrated from `sideral-base` to `sideral-services` (containers config lives with the containers module).

### Kubernetes (new 2026-05-02)
- New `sideral-kubernetes` RPM ships `/etc/yum.repos.d/kubernetes.repo` (pkgs.k8s.io stable v1.32, persistent) + `/etc/profile.d/sideral-kind-podman.sh` (`KIND_EXPERIMENTAL_PROVIDER=podman`, `MINIKUBE_DRIVER=podman`).
- `os/modules/kubernetes/{packages.txt → kind helm, kubectl-install.sh}` does the binary install at image build.
- Powers Podman Desktop's Kubernetes panel; `kind`/`minikube`/`helm` commands work without a docker daemon.

### NVIDIA variant (new 2026-05-02)
- Separate image variant built from `silverblue-nvidia:43` in the same CI matrix; tagged `ghcr.io/<owner>/sideral-nvidia:{latest,YYYYMMDD,sha-…}`.
- `os/modules/nvidia/apply.sh` runs in every build but is gated on `rpm -q kmod-nvidia` — only the nvidia matrix entry does anything.
- Writes `/usr/lib/bootc/kargs.d/00-nvidia.toml` (4 kargs incl. `nvidia-drm.modeset=1`, required for proper Wayland on NVIDIA) + `/etc/dconf/db/local.d/50-sideral-nvidia` (mutter `kms-modifiers=true` — stock GNOME on F43 doesn't enable it for nvidia-drm and Wayland tears without it).
- ISO `anaconda-hook.sh` reads `lspci`, picks the matching variant from ghcr at install time.

### CLI tools (2026-05-02)
- `sideral-cli-tools.spec` Requires graph: `chezmoi mise atuin fzf bat eza ripgrep zoxide gh git-lfs gcc make cmake code helix fish zsh zsh-syntax-highlighting zsh-autosuggestions rclone fuse3` (21 names; chezmoi + 12 day-to-day + code + helix + fish + zsh + zsh-fish-parity (2) + rclone-stack (2)).
- **starship** — fetched as the latest upstream binary by `os/modules/shell-tools/starship-install.sh`, sha256-verified, baked into `/usr/bin`. Not RPM-tracked, NOT in `Requires:`. Detected at runtime via `command -v` so removing the binary doesn't break the init script.
- **chromium** — installed via `os/modules/shell-tools/packages.txt` and hidden from the app grid (see Browser above).
- **mise** via persistent `mise.jdx.dev/rpm/` repo; **VS Code** via persistent `packages.microsoft.com/yumrepos/vscode` repo; both shipped as `/etc/yum.repos.d/{mise,vscode}.repo` files in `sideral-base` so `rpm-ostree upgrade` keeps pulling updates between rebuilds.
- `/etc/mise/config.toml` ships settings only (`trusted_config_paths`, `not_found_auto_install`, `jobs`, etc.). Tools live in `~/.config/mise/config.toml` (seeded by `sideral-shell-seed.service` with the full default toolchain; chezmoi-trackable). User-level config merges with system config additively.

### Shells (2026-05-02)
- **Three parallel shells**: bash (default), fish, zsh. Sideral ships parallel init for all three:
  - `/etc/profile.d/sideral-cli-init.sh` (bash)
  - `/etc/fish/conf.d/sideral-cli-init.fish` (fish)
  - `/etc/zsh/sideral-cli-init.zsh` + custom `/etc/zshrc` (zsh; replaces Fedora's stock 3-line zshrc via `rpm -Uvh --replacefiles`)
- All three wire the same set: starship, atuin, zoxide, mise, fzf, EDITOR=hx + VISUAL=code, eza/bat aliases (skipped for AI agents), Ctrl+P fzf quick-open, Alt+S sudo toggle, Ctrl+G fzf git-branch checkout.
- zsh fish-parity via `zsh-syntax-highlighting` + `zsh-autosuggestions` (Fedora main, source-loaded with the upstream-required ordering — autosuggestions first, syntax-highlighting last). No plugin manager needed for two source lines.
- Switch via `ujust chsh [bash|fish|zsh]` — uses `sudo usermod -s` because ublue removes setuid `chsh` as part of its hardening pass. Interactive picker via `ugum choose` if no shell name passed.

### Shell init details
- **AI-agent shell detection**: 14 env-var markers (AGENT, AI_AGENT, CLAUDECODE, CURSOR_AGENT, CURSOR_TRACE_ID, GEMINI_CLI, CODEX_SANDBOX, AUGMENT_AGENT, CLINE_ACTIVE, OPENCODE_CLIENT, TRAE_AI_SHELL_ID, ANTIGRAVITY_AGENT, REPL_ID, COPILOT_MODEL, plus manual `SIDERAL_NO_ALIASES`). Suppresses eza/bat aliases so agents see plain `ls`/`cat` output instead of icons + ANSI escapes.
- **zoxide** stays as plain `z`/`zi` — `--cmd cd` was tried and clashed with mise's `__zsh_like_cd` chpwd wrapper (whichever loaded last won, the loser silently broke). Plain `z` sidesteps the conflict.
- **Re-entry guard** — `SIDERAL_CLI_INIT_RAN` flag prevents double-sourcing.

### ujust extension slot (2026-05-02)
- `/usr/share/ublue-os/just/60-custom.just` fills `ublue-os-just`'s `import? "60-custom.just"` slot.
- Shipped recipes: `chsh [shell]`, `chezmoi-init <repo>`, `gdrive-setup`, `gdrive-remove`, `tools` (behavior cheatsheet motd via inherited `ugum` + Urllink for OSC-8 hyperlinks).

### Welcome UX (2026-05-02)
- `/etc/user-motd` — every-login banner picked up by inherited `/etc/profile.d/user-motd.sh` (ublue-os-just). Lists common `ujust` recipes.
- Replaces the previous one-shot `/etc/profile.d/sideral-onboarding.sh` (was bash-only, tied to first-shell; the motd works for any login shell and any session).
- Per-user opt-out: `touch ~/.config/no-show-user-motd`.

### Google Drive (2026-05-02)
- Systemd **user** unit `/usr/lib/systemd/user/rclone-gdrive.service` (Type=notify, mounts `~/gdrive` with `--vfs-cache-mode=writes`, Restart=on-failure for transient network drops + token-refresh hiccups).
- `ujust gdrive-setup` walks rclone OAuth on first run, enables + starts the unit; `ujust gdrive-remove` disables/stops, defensively unmounts via `fusermount3 -u`, then asks via `ugum confirm` whether to wipe the rclone `gdrive:` remote config + remove the empty mount dir.

### Fonts
- Source Serif 4 + Source Sans 3 fetched from Adobe GitHub at image build (`os/modules/fonts/post.sh`); `cascadia-code-fonts`, `jetbrains-mono-fonts-all`, `adwaita-fonts-all`, `opendyslexic-fonts` from Fedora main.

### Flatpaks (2026-05-02 grow-out)
- **11 curated entries** preinstalled at image build into `/var/lib/flatpak`, all from flathub — Zen Browser, Bazaar, Flatseal, Extension Manager, Podman Desktop, DistroShelf, Resources, Smile, Web App Hub, Pika Backup, Junction.
- Single `flathub` remote (the previous fedora oci+registry remote was retired 2026-05-01 — caused titanoboa live-ISO install failures on refs that exist in both remotes, e.g. Flatseal).
- `/etc/sideral-flatpak-purge` (new 2026-05-02) lists refs to **actively uninstall** on deployed systems on every boot. Currently: `io.github.flattool.Warehouse` (dropped from curated set 2026-05-01; the purge file gets it removed from already-deployed systems too). Closes the gap from the older self-heal model where dropping a manifest entry left existing copies in place forever.
- `sideral-flatpak-install.service` repurposed as forward-compat self-heal — every-boot idempotent re-apply of remotes + manifest + purge list. Future image rebases that add new entries install on existing user systems.

### Distrobox
- `/etc/distrobox/distrobox.conf` lives in `sideral-services` (was sideral-base; moved 2026-05-02). Defaults only — no `/nix` mounts (chezmoi-home D-01).

### Host-only / non-goals
- mise and chezmoi run on the host. Distrobox containers install their own tooling if needed (no shared `/nix`, no shared user profile).
- No brew, no nix (user declined both; ad-hoc CLI tooling via distrobox or RPM, language runtimes via mise).

## Known blockers
None.

## Build verification
- Per-PR: `build-sideral` GH Actions matrix builds both `sideral` (silverblue-main:43) and `sideral-nvidia` (silverblue-nvidia:43) variants in parallel, ending in `bootc container lint`.
- ISO builds via titanoboa (`build-iso.yml`) on push of `v*` tags + workflow_dispatch; uploads single overwrite-keyed `Sideral x86_64.iso` to Cloudflare R2.
- Local: `just lint` (shellcheck) + `just build` (podman build → bootc container lint) + `just rebase` (rpm-ostree rebase to local image).

## Lessons
- **Persistent repo pattern**: repos enabled during build.sh + kept enabled in the shipped image let `rpm-ostree upgrade` pull new releases without touching the image. Currently used for `mise.repo`, `vscode.repo`, `kubernetes.repo`. *(`docker-ce.repo` retired 2026-05-02 with the rootless-podman swap.)*
- **GNOME-extension download at build time** needs the real `gnome-shell --version` of the running container — call `gnome-shell --version` inside the container (silverblue-main ships gnome-shell), then query `extensions.gnome.org/extension-info/?uuid=<uuid>&shell_version=<N>`. `glib2-devel`/`jq`/`unzip` are installed and removed in the same script so they don't bloat the final layer.
- **`dconf update` must run after `COPY system_files/etc /etc`.** The Containerfile has a dedicated RUN step for that, followed by the final `ostree container commit`.
- **flatpak-install service is system-level, not user.** System-wide flatpaks live under `/var/lib/flatpak`, which is mutable on atomic. User-level would require a per-user unit.
- **2026-05-02 — module refactor.** Source-tree split between `os/build_files/features/` and `os/packages/sideral-*/src/` made it hard to see "what does the desktop module actually own?" because the dconf snippets, the GNOME-extension fetch script, and the packages.txt were in three different trees. Collapsing each capability into one directory under `os/modules/<capability>/` cut "where does X live?" lookups dramatically. Sub-package names stayed stable for upgrade safety; only the directory layout changed.
- **2026-05-02 — rootless podman over docker-ce.** Fedora atomic + rootful Docker is a known friction point: docker group footgun, daemon to enable, ostree-unfriendly storage on `/var/lib/docker`. Rootless podman is the de-facto atomic-desktop default. The persistent docker-ce repo, the `--allowerasing` swap of Fedora's containerd, and the docker-ce Requires in sideral-base all go away with this change. `podman-docker` shim covers `docker` muscle memory; `podman-compose` covers compose.yaml workflows (~95% parity).
- **2026-05-02 — chromium install vs surface.** Chromium is genuinely useful (puppeteer/playwright headless, fallback rendering), but having two browsers in the app grid creates "which one do I open?" friction with no upside. `NoDisplay=true` patched in by `hide-chromium.sh` keeps it CLI-invokable as `chromium-browser` while removing the GUI surface. Bluefin uses the same approach for gnome-system-monitor etc.
- **2026-05-02 — chsh isn't available on ublue.** ublue-os/main strips setuid `chsh` as part of its hardening pass. `usermod -s` (root-only) is the equivalent path, and `ujust chsh [shell]` wraps it for users.
- **2026-05-02 — Bazaar over gnome-software.** Bazaar is flatpak-first (GNOME-Shell-extension-free), portable across non-GNOME variants, and matches bluefin's current direction. `ublue-os-update-services` (inherited from silverblue-main) covers OS-update notifications; `rpm-ostree` CLI covers RPM layering; the gnome-software shell-extension dependency goes away. Reversed the brief 2026-05-01 detour where Bazaar was dropped for gnome-software.
- **AI-agent alias suppression.** Aliasing `ls` → eza or `cat` → bat injects icons + ANSI escapes + git decorations + line numbers that AI agents read as raw context. 14 env-var markers (AGENT, AI_AGENT, CLAUDECODE, CURSOR_*, GEMINI_CLI, CODEX_SANDBOX, AUGMENT_AGENT, CLINE_ACTIVE, OPENCODE_CLIENT, TRAE_AI_SHELL_ID, ANTIGRAVITY_AGENT, REPL_ID, COPILOT_MODEL, SIDERAL_NO_ALIASES) suppress the aliases. `\ls` and `\cat` always reach GNU coreutils for scripts that want deterministic output.
- **End-of-build initramfs regen.** Defensive `dracut --no-hostonly --kver "$KERNEL_VERSION" --reproducible --add ostree -f` matching bluefin's pattern. Sideral installs only userspace packages and shouldn't invalidate the inherited initramfs, but if a future package install triggers a kernel post-script that strips drivers without rebuilding, this catches it. `--reproducible` + `DRACUT_NO_XATTR=1` keep output deterministic.
- **2026-05-01 — nix on Fedora atomic 42+ is fragile.** Three issues remain unresolved upstream as of late 2025: composefs vs ostree planner ([nix-installer#1445](https://github.com/DeterminateSystems/nix-installer/issues/1445)), SELinux mislabel of /nix paths ([#1383](https://github.com/DeterminateSystems/nix-installer/issues/1383)), /nix daemon disappearing after rpm-ostree upgrade. Decision to retire nix-home was made before paying the production cost. See chezmoi-home D-01.
- **2026-05-01 — starship: COPR detour, then upstream binary.** Tried `atim/starship` COPR (worked), evaluated dropping the COPR layer entirely, decided to fetch `releases/latest/download/starship-x86_64-unknown-linux-musl.tar.gz` + sha256 in `os/modules/shell-tools/starship-install.sh`. **Lesson: on atomic images, every "RPM-tracked third-party package" should clear a real bar — what does `rpm-ostree upgrade` actually buy you over a baked binary, given image rebuilds happen anyway?** For starship the answer was "nothing meaningful"; for docker-ce/mise/vscode/kubectl the answer is "frequent security and feature updates that users genuinely want between rebuilds."
- **Phase R lessons (2026-04-30, run 25188178498)** still apply:
  - **`/ctx` bind-mount layout is `/ctx/lib/...` and `/ctx/modules/...`** post-refactor (was `/ctx/build_files/...`). The orchestrator at `/ctx/lib/build.sh` references `/ctx/modules/<name>/`.
  - **RPM file-path Requires resolves through the rpmdb, not the filesystem.** Use `ConditionPathExists=` in systemd units instead.
  - **`rpm -Uvh --replacefiles --replacepkgs` does not bypass package-level `Conflicts:`.** silverblue-{main,nvidia}:43 ship `ublue-os-signing` and `sideral-signing.spec` declares `Conflicts:` against it. Containerfile must `rpm -e --nodeps ublue-os-signing` *before* the install step.
  - **`set -o pipefail` makes `var=$(... | grep ...)` a hidden landmine** when the grep can find nothing. Capture into a variable first, then `grep ... || true`, then validate.

## Deferred
- **Chezmoi default dotfiles repo** — create a `sideral-dotfiles` GitHub repo containing all seeded skeletons (`~/.bashrc`, `~/.zshrc`, `~/.config/nushell/{env.nu,config.nu}`, `~/.config/mise/config.toml`). Replace the `sideral-shell-seed` file-creation logic with `chezmoi init --apply github.com/athenabriana/sideral-dotfiles` (one-shot, only if `~/.local/share/chezmoi` is empty). Users who want their own dotfiles repo run `ujust chezmoi-init <their-repo>` to take over. Open question: GitHub-hosted (requires network on first login, users can `chezmoi update` for improvements) vs bundled in image at `/usr/share/sideral/chezmoi/` (offline-safe, updates ship with image rebuilds). Spec this as a follow-on to `nushell` once the seed service ships.
- Tailscale daemon + GNOME indicator. (Niri migration may change the indicator angle.)
- QCOW2 / raw bootc-image-builder outputs (ISO landed 2026-04-30; qcow2/raw still skipped).
- Matrix builds (aarch64).
- Bitwarden CLI integration via chezmoi templates (chezmoi-home D-07 — user can opt in by editing their chezmoi source tree; image stays neutral).
- VS Code extension auto-install via `code --install-extension` in /etc/profile.d/ (chezmoi-home open concern; not worth the time-to-first-shell penalty for now).
- **Niri migration** — see `niri-shell` feature spec under `.specs/features/niri-shell/`.
