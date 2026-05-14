# silverfox — Project State

Persistent memory: decisions, blockers, lessons, todos, deferred ideas.

## Current focus
- **`nix+nh` (revived 2026-05-13).** Declarative user config via nix + nh. Sem home-manager — `nh home switch` faz tudo. 33 requirements. Spec em `.specs/features/nix/`.
- **`fox-enhancements` (2026-05-11).** Port useful ujust recipes to fox, ship silverfox-owned motd display script, and remove the inherited `ublue-os-just` RPM from the image entirely. `fox` gains: `toggle-banner` (new), `upgrade-firmware` (new), `clean` (renamed de `cleanup`; cobre podman + rpm-ostree + nix GC via nh — sem flatpak, gerenciado por nix). `silverfox-shell-ux` gains `/etc/profile.d/silverfox-motd.sh` (replaces ublue's `user-motd.sh`). 17 testable requirements. Spec at `.specs/features/fox-enhancements/`.

## Past features (shipped)

- **`fox` (2026-05-11).** Silverfox-owned operator CLI (`/usr/bin/fox`, ~20-line bash dispatcher around `just`). 9 v1 verbs: `chsh`, `cheatsheet`, `home factory-reset`, `update`, `upgrade`, `rollback`, `status`, `cleanup`, `changelog`. Manpage at `man 7 silverfox` (rendered via pandoc). Two new modules (`fox/`, `home/`), one narrowed (`shell-ux/`), one retired (`dotfiles/`). 47 testable requirements, 18 locked decisions. Spec preserved at `.specs/features/fox/`.
- **`chezmoi-home`** — replaces `nix-home` (retired pre-VM-verification 2026-05-01). 23 requirements, 9 locked decisions. Drops nix entirely (composefs/SELinux/post-upgrade frictions on Fedora atomic 42+), restores 14 CLI tools as RPMs in a `silverfox-cli-tools` sub-package, adds VS Code via Microsoft repo (restores ATH-14/15), centralizes shell-init wiring in `/etc/profile.d/silverfox-cli-init.sh` shipped by `silverfox-shell-ux`. User runs `chezmoi init --apply <repo>` themselves — no auto-bootstrap service. Source-tree changes landed 2026-05-01 (T01–T14); CI-validated continuously since via the rootless-podman / module-refactor / NVIDIA / kubernetes / Bazaar / flatpak-grow PRs. Spec preserved at `.specs/features/chezmoi-home/`.
- **`silverfox-rpms`** — 26 requirements, inline RPM build inside the Containerfile (rpmbuild + `rpm -Uvh --replacefiles` + `rpm -e` toolchain teardown in one RUN layer). Renamed from `silverfox-copr` 2026-04-29 when the Copr publishing path was dropped (D-15). See `.specs/features/silverfox-rpms/spec.md`. Phase R landed 2026-04-30 (CI run 25188178498, sha `e06bc39`, 6m24s end-to-end). Signing requirements (ACR-27..29) still parked until user flips to signed-rebase; see `os/modules/signing/UPGRADE.md`.
- **`silverfox`** — fork from `fedora-silverfox`/Hyprland lineage into GNOME + tiling-shell on `silverblue-main:43`. 27 requirements across 5 user stories. See `.specs/features/silverfox/spec.md`.
  - Superseded by `nix-home` then partially restored by `chezmoi-home`: ATH-14, ATH-15 (vscode.repo + RPM install) restored via chezmoi-home CHM-09. ATH-17 restored as image-build-time RPM (no first-login service). ATH-23, ATH-24, ATH-26 stay superseded (mise config + bashrc activation now user-managed via chezmoi).
  - 2026-04-23 cleanup: ATH-12 (helium → Zen flatpak — itself reverted 2026-05-01, see below), ATH-18 (now superseded again — VS Code is back as RPM), ATH-13 count (7 → 8 → 7 → **11** flatpaks; latest from 2026-05-02 manifest grow-out).
  - ATH-04 amended: 5 → 4 enabled extensions (bazaar-integration retired 2026-05-01 alongside original Bazaar→GNOME-Software swap; later GNOME-Software→Bazaar re-swap on 2026-05-02 did NOT bring the integration extension back — Bazaar is a flatpak now, not an in-shell integration). Current enabled set: appindicator + dash-to-panel + tilingshell + rounded-window-corners.
  - ATH-11 (sentinel-gated once-only run) superseded 2026-05-01: service runs every boot as forward-compat self-heal, plus a third active-purge pass added 2026-05-02. Still valid: ATH-01..10, ATH-16, ATH-19..22, ATH-25, ATH-27.

## Past feature (retired pre-shipping)
- `nix-home` — designed and implemented locally (40 requirements, 15 locked decisions) but retired before VM verification on 2026-05-01. Reason: composefs vs nix-installer ostree planner ([nix-installer#1445](https://github.com/DeterminateSystems/nix-installer/issues/1445)), SELinux mislabel of /nix store paths ([#1383](https://github.com/DeterminateSystems/nix-installer/issues/1383), still open), and `/nix` + nix-daemon disappearing after `rpm-ostree upgrade` on F42+ (multiple Universal Blue forum reports). Replaced by `chezmoi-home`. Spec preserved at `.specs/features/nix-home/spec.md` for historical reference. See `.specs/features/chezmoi-home/context.md` D-01.

## Roadmap
- See `.specs/project/ROADMAP.md` for queued (`image-ops`) and backlog features.

## Pending decisions
- **Signed-rebase flip** — currently `ostree-unverified-registry:` is canonical. To flip: replace `os/modules/signing/src/etc/containers/policy.json` with the strict `sigstoreSigned` schema (template in `os/modules/signing/UPGRADE.md`), update README's install command. Keyless OIDC signing of the OCI image already runs in `build.yml`. (Same work as ACR-29.)

## Locked decisions

### Source tree layout (2026-05-11 — fox feature, module count 7 → 8)
- **`os/lib/{build,build-rpms}.sh`** — orchestrator + inline-RPM driver. Unchanged across the fox feature.
- **`os/modules/<capability>/`** — current 8 modules: `base, cli-tools, flatpaks, fox, home, kubernetes, services, shell-ux`. Changed in the fox feature: `+fox`, `+home`, `-dotfiles`; `shell-ux` narrowed to system-level shell concerns (`/etc/user-motd`, `/etc/mise/config.toml`, `/etc/profile.d/silverfox-shell-migrate.sh`); `cli-tools` dropped `rclone`+`fuse3` and added `just` (as a Layer-1 dep for `silverfox-fox` Requires).
- Module list (pre-fox, 2026-05-02): `containers desktop flatpaks fonts kubernetes meta nvidia shell-init shell-tools signing`.
- Build order in `os/lib/build.sh`: `shell-tools desktop containers kubernetes fonts flatpaks nvidia` — shell-tools first because `silverfox-cli-tools.spec` Requires every binary it installs; nvidia last so variant tweaks land on the final tree.
- Modules without `packages.txt` or `*.sh` are silently skipped by the orchestrator (signing, shell-init, meta) — they only contribute via the inline RPM build.
- Sub-package names kept stable across the refactor for upgrade safety (`silverfox-base`, `silverfox-services`, `silverfox-shell-ux`, etc.); the **module dir** name is the descriptive one.
- Build scripts committed with +x via `git update-index --chmod=+x`; `/ctx` is bind-mounted read-only so runtime chmod is no longer possible.
- `just lint` now runs `shellcheck os/lib/*.sh os/modules/*/*.sh`.

### Desktop / GNOME
- **GNOME + tiling-shell**, Hyprland dropped entirely. Currently 4 enabled extensions: `appindicator`, `dash-to-panel` (Fedora-main RPMs) + `tilingshell`, `rounded-window-corners` (e.g.o, fetched at image build by `os/modules/desktop/extensions.sh`).
- **App store (2026-05-02): Bazaar (Flathub) is canonical.** gnome-software + gnome-software-rpm-ostree are actively removed from the inherited base by `os/lib/build.sh`'s prune step. OS-update notifications come from inherited `ublue-os-update-services`; RPM layering is done via the `rpm-ostree` CLI. Matches bluefin's current direction. The 2026-05-01 `gnome-software` swap (which itself replaced an earlier Bazaar) was reversed once Bazaar's flatpak-first UX matured.
- **dconf override `20-silverfox-gnome-software`** still ships (cheap defensive default in case gnome-software ever re-enters via user override) but is functionally inert in the shipped image.
- **Inherited-base prune** (`os/lib/build.sh`): `firefox`, `firefox-langpacks`, `dconf-editor`, `gnome-software`, `gnome-software-rpm-ostree`. `htop` evaluated and **kept** (pairs with inherited `nvtop` — htop covers CPU/RAM/processes, nvtop covers GPU).

### Browser
- **Zen Browser** (`app.zen_browser.zen` from Flathub). Preinstalled at image build by `os/modules/flatpaks/install.sh`; updates via standard `flatpak update` (run nightly by inherited `ublue-os-update-services`).
- **Chromium installed but hidden** via `NoDisplay=true` patched into `/usr/share/applications/chromium*.desktop` by `os/modules/shell-tools/hide-chromium.sh`. For headless automation (puppeteer/playwright), web-app debugging, fallback rendering. Invokable as `chromium-browser`.

### Editor
- **Editor** (2026-05-11): zed unified — `EDITOR='zed --wait'` and `VISUAL='zed --wait'`. Vim mode with `default_mode: helix_normal` for selection-first modal editing. Replaces the prior hx/code split (helix + VS Code both dropped); vscode.repo no longer ships in silverfox-base.
- Zed comes from Terra (`repos.fyralabs.com/terra44`, persistent repo shipped via silverfox-cli-tools); `rpm-ostree upgrade` keeps it current between image rebuilds.

### Container runtime (2026-05-02)
- **Rootless podman + docker compatibility shims.** Layered RPMs: `podman-docker` (installs `/usr/bin/docker` wrapper + `/etc/profile.d/podman-docker.sh` setting `DOCKER_HOST=unix:///run/user/$UID/podman/podman.sock`) and `podman-compose` (Python compose v2 ~95% parity).
- `silverfox-services` ships `/usr/lib/systemd/user/sockets.target.wants/podman.socket → ../podman.socket` so the per-user podman API socket comes up on first login without `systemctl --user enable podman.socket`.
- **docker-ce stack retired**: `docker-ce.repo`, `containerd.io --allowerasing` swap, the docker group footgun, and the `Requires: docker-ce` from silverfox-base all gone.
- `/etc/distrobox/distrobox.conf` migrated from `silverfox-base` to `silverfox-services` (containers config lives with the containers module).

### Kubernetes (new 2026-05-02)
- New `silverfox-kubernetes` RPM ships `/etc/yum.repos.d/kubernetes.repo` (pkgs.k8s.io stable v1.32, persistent) + `/etc/profile.d/silverfox-kind-podman.sh` (`KIND_EXPERIMENTAL_PROVIDER=podman`, `MINIKUBE_DRIVER=podman`).
- `os/modules/kubernetes/{packages.txt → kind helm, kubectl-install.sh}` does the binary install at image build.
- Powers Podman Desktop's Kubernetes panel; `kind`/`minikube`/`helm` commands work without a docker daemon.

### NVIDIA variant (new 2026-05-02)
- Separate image variant built from `silverblue-nvidia:43` in the same CI matrix; tagged `ghcr.io/<owner>/silverfox-nvidia:{latest,YYYYMMDD,sha-…}`.
- `os/modules/nvidia/apply.sh` runs in every build but is gated on `rpm -q kmod-nvidia` — only the nvidia matrix entry does anything.
- Writes `/usr/lib/bootc/kargs.d/00-nvidia.toml` (4 kargs incl. `nvidia-drm.modeset=1`, required for proper Wayland on NVIDIA) + `/etc/dconf/db/local.d/50-silverfox-nvidia` (mutter `kms-modifiers=true` — stock GNOME on F43 doesn't enable it for nvidia-drm and Wayland tears without it).
- ISO `anaconda-hook.sh` reads `lspci`, picks the matching variant from ghcr at install time.

### CLI tools (2026-05-14 — nix como fonte da verdade)
- `silverfox-cli-tools.spec` Requires graph (bootstrap only, 8 names): `stow starship carapace-bin zsh zsh-syntax-highlighting zsh-autosuggestions ghostty zed`.
- **Ferramentas dia-a-dia** (atuin, fzf, bat, eza, ripgrep, zoxide, gh, git-lfs, gcc, make, cmake) movidas para `home.packages` no flake.nix — gerenciadas por `nh home switch`. Sem duplicação RPM + nix.
- **mise** via `programs.mise.enable = true` no flake.nix. Sem mise.jdx.dev/rpm/.
- `/etc/mise/config.toml` ships settings only (`trusted_config_paths`, etc.). Ferramentas declaradas em `tools {}` no flake.nix via `programs.mise.globalConfig`.
- **chezmoi removido** do stack — nunca foi usado. Dotfiles via stow exclusivamente.

### Shells (2026-05-11 — two shells, /etc/skel seeded)
- **Two shells**: bash (default) and zsh. fish dropped entirely (not in cli-tools, not in `fox chsh` allowlist, not in `/etc/skel`). nu was already gone (2026-05-10 dotfile-seeding rework).
- **User-domain rcs**: `~/.bashrc` and `~/.zshrc` are real files seeded once into new user homes by `useradd` from `/etc/skel/.config/silverfox/stow/{bash,zsh}/` (via the pre-farmed top-level symlinks in `/etc/skel/`). Owned by `silverfox-home`. Silverfox never modifies them after seed. Existing users opt in to new defaults via `fox home factory-reset`.
- Both rcs wire the same set: starship, atuin, zoxide, mise, fzf, EDITOR=`zed --wait` + VISUAL=`zed --wait`, eza/bat aliases (skipped for AI agents), Ctrl+P fzf quick-open, Alt+S sudo toggle, Ctrl+G fzf git-branch checkout. The retired `/etc/profile.d/silverfox-cli-init.sh` + zsh + fish variants have been gone since the 2026-05-10 chezmoi → stow rework.
- zsh fish-parity via `zsh-syntax-highlighting` + `zsh-autosuggestions` (Fedora main, source-loaded with the upstream-required ordering — autosuggestions first, syntax-highlighting last). No plugin manager needed for two source lines.
- Stock Fedora `/etc/zshrc` returns: shell-ux 0.0.0-15 dropped silverfox's customized `/etc/zshrc`. The `zsh` RPM reclaims ownership on next upgrade (open concern: `%ghost` workaround may be needed for one release if upgrade balks at file-ownership transfer — verify in first rebase-on-VM).
- Switch via `fox chsh [bash|zsh]` — uses `sudo usermod -s` because ublue removes setuid `chsh` as part of its hardening pass. No-arg falls back to `read -p` (the `tv` picker considered but dropped — not in Terra or Fedora-main; see fox D-07).

### Shell init details
- **AI-agent shell detection**: 14 env-var markers (AGENT, AI_AGENT, CLAUDECODE, CURSOR_AGENT, CURSOR_TRACE_ID, GEMINI_CLI, CODEX_SANDBOX, AUGMENT_AGENT, CLINE_ACTIVE, OPENCODE_CLIENT, TRAE_AI_SHELL_ID, ANTIGRAVITY_AGENT, REPL_ID, COPILOT_MODEL, plus manual `SILVERFOX_NO_ALIASES`). Suppresses eza/bat aliases so agents see plain `ls`/`cat` output instead of icons + ANSI escapes.
- **zoxide** stays as plain `z`/`zi` — `--cmd cd` was tried and clashed with mise's `__zsh_like_cd` chpwd wrapper (whichever loaded last won, the loser silently broke). Plain `z` sidesteps the conflict.
- **Re-entry guard** — `SILVERFOX_CLI_INIT_RAN` flag prevents double-sourcing.

### Operator CLI (2026-05-11 — fox replaces ujust)
- `/usr/bin/fox` — ~20-line bash dispatcher at `/usr/bin/fox` (owned by `silverfox-fox`). Routes argv into `/usr/share/silverfox/silverfox.justfile` via `just -f`. One transform: `fox home <sub>` → `just home::<sub>` (just's module syntax). Reads `SILVERFOX_JUSTFILE` and `SILVERFOX_OS_RELEASE` from env for test injection.
- **v1 verbs** (9): `chsh`, `cheatsheet`, `home factory-reset`, `update`, `upgrade`, `rollback`, `status`, `cleanup`, `changelog`. Non-trivial logic (chsh allowlist + usermod; factory-reset skel walk + prompt) lives in libexec bash at `/usr/libexec/silverfox/{chsh,home-factory-reset}.sh`. Simple verbs are one-liners wrapping `flatpak`/`rpm-ostree`/`man`.
- **fox-enhancements verbs (2026-05-11)** — `toggle-banner` (new), `upgrade-firmware` (new), `upgrade` and `cleanup` expanded to cover podman/flatpak/distrobox/fwupdmgr alongside the original ostree scope.
- **Cheatsheet** moved to `man 7 silverfox` — rendered from `os/modules/fox/src/man/silverfox.md` via pandoc in the new `man-build` Containerfile stage (`fedora-minimal:44 + pandoc`, ~150MB transient). Bridged into the final image via `/var/tmp/fox-prebuilt/`, which silverfox-fox.spec's `%install` reads from. `apropos silverfox` / `man -k silverfox` resolve.
- **Testing**: `os/modules/fox/src/tests/{fox,factory-reset}.test.sh` exercise the dispatcher and factory-reset behavior with tmpfs fixtures + a fake-`just` stub. `just fox-lint && just fox-test` runs as a CI pre-flight job (`ubuntu-24.04`, apt installs just+shellcheck+util-linux, <2min) ahead of the image-build matrix.
- **`ublue-os-just` removed (2026-05-11)**: the inherited ublue RPM is pruned at image build. `ujust` binary no longer exists in the image; `/usr/share/ublue-os/justfile` + module tree removed; `/etc/profile.d/user-motd.sh` replaced by silverfox's own `silverfox-motd.sh`. The silverfox 60-custom.just extension slot had already been deleted in the fox feature; this completes the removal by dropping the entire upstream package.

### Welcome UX (2026-05-11 — silverfox-motd.sh replaces ublue user-motd.sh)
- `/etc/user-motd` — every-login banner, now displayed by silverfox-owned `/etc/profile.d/silverfox-motd.sh` (silverfox-shell-ux RPM). Replaces the inherited ublue-os-just `user-motd.sh` which was removed with the `ublue-os-just` package.
- Per-user opt-out: `fox toggle-banner` or `touch ~/.config/no-show-user-motd`.
- Lists common `fox` recipes; no `ujust` references remain.

### Google Drive — RETIRED (2026-05-11)
- All gdrive scaffolding deleted: `rclone-gdrive.service` (removed from shell-ux), `rclone`+`fuse3` (removed from silverfox-cli-tools Requires + cli-tools packages.txt), `ujust gdrive-setup`/`gdrive-remove` recipes (60-custom.just deleted with the rest of the ujust extension slot).
- Users who want Google Drive: `rpm-ostree install rclone fuse3`, then write a user-level systemd unit. The 10-line setup is not worth silverfox owning — single-user image with one workflow needing this.

### Fonts
- Source Serif 4 + Source Sans 3 fetched from Adobe GitHub at image build (`os/modules/fonts/post.sh`); `cascadia-code-fonts`, `jetbrains-mono-fonts-all`, `adwaita-fonts-all`, `opendyslexic-fonts` from Fedora main.

### Flatpaks (2026-05-14 — nix-flatpak como fonte da verdade)
- **Gerenciados via `services.flatpak.packages`** no flake.nix do usuário (nix-flatpak module). `nh home switch` instala, remove, e atualiza. Sem `/etc/flatpak-manifest`, sem `silverfox-flatpak-install.service`, sem purge list.
- Apps curados declarados no starter flake.nix: Zen Browser, Flatseal, Extension Manager, Podman Desktop, Resources, Smile, Web App Hub, Pika Backup.
- Remote `flathub` configurado no flake (`remotes` block). Único remote.
- `fox sync` = `nh home switch` — é o único verbo necessário para reconciliar flatpaks.

### Distrobox
- `/etc/distrobox/distrobox.conf` lives in `silverfox-services` (was silverfox-base; moved 2026-05-02). Defaults only — no `/nix` mounts.

### Dotfile seeding (2026-05-11 — stow-on-first-login → /etc/skel via useradd)
- Image-default dotfiles ship as a stow source tree at `/etc/skel/.config/silverfox/stow/{bash,zsh,mise,ghostty,zed}/`, plus five pre-farmed relative symlinks at `/etc/skel/{.bashrc,.zshrc,.config/{mise/config.toml,ghostty/config,zed/settings.json}}`. Owned by the new `silverfox-home` RPM.
- `useradd` copies the whole `/etc/skel` tree (cp -a semantics, symlinks preserved) into new user homes. From that moment the dotfiles are **user-domain real files** — silverfox never modifies them. Image upgrades that change `/etc/skel` only affect future-created users.
- Existing users opt in destructively via `fox home factory-reset` (depth-≤2 wipe + reseed under silverfox-managed paths; preserves non-silverfox subdirs of `~/.config/`).
- Customization is direct: edit the real file in `$HOME`. Custom user stow packages must live OUTSIDE `~/.config/{silverfox,mise,ghostty,zed}/` (those four trees are wiped by factory-reset). Recommended layout: `~/.config/dotfiles/<pkg>/`, applied with `stow --target=$HOME --dir=$HOME/.config/dotfiles <pkg>`.
- Replaces the 2026-05-10 stow-on-first-login model. `/etc/profile.d/silverfox-stow-defaults.sh` + the marker + the read-only `/usr/share/silverfox/stow/` tree are all gone (silverfox-stow-defaults RPM retired, not renamed). The dotfiles module (`os/modules/dotfiles/`) is deleted entirely.

### Host-only / non-goals
- mise runs on the host. Distrobox containers install their own tooling if needed (no shared user profile).

## Known blockers
None.

## Build verification
- Per-PR: `build-silverfox` GH Actions matrix builds both `silverfox` (silverblue-main:43) and `silverfox-nvidia` (silverblue-nvidia:43) variants in parallel, ending in `bootc container lint`.
- ISO builds via titanoboa (`build-iso.yml`) on push of `v*` tags + workflow_dispatch; uploads single overwrite-keyed `Silverfox x86_64.iso` to Cloudflare R2.
- Local: `just lint` (shellcheck) + `just build` (podman build → bootc container lint) + `just rebase` (rpm-ostree rebase to local image).

## Lessons

- **2026-05-11 — bash dispatcher beats Bun for 20-line dispatch.** fox D-02 originally chose Bun+compile for `/usr/bin/fox`. Reversed same-day after the dispatcher's role narrowed to pure argv routing: shipping a 50–80MB embedded Bun runtime to host ~20 lines of bash-equivalent logic is pure overhead. v2 (`fox home sync`) may reintroduce a typed runtime *when there's substance to host* (TOML manifest parsing + backend drivers for flatpaks/dconf/systemd-user). Lesson generalizes: don't pre-pay runtime cost for anticipated future complexity — pick the substrate when the substance exists.
- **2026-05-11 — `/etc/skel` is the right seam for "image-default dotfiles + user-domain after seed".** Replaces the prior stow-on-first-login model (chezmoi → stow → /etc/skel). Wins: dotfiles are real, user-visible, user-editable from day 1; `cat ~/.bashrc` shows actual content; no symlink-into-read-only-ostree dance for editing; useradd's cp-a semantics preserve symlinks (the stow tree stays browsable); home-manager-style revert UX recovered via `fox home factory-reset` without nix substrate. Cost: image upgrades don't auto-update existing users — opt-in via `fox home factory-reset` (destructive) or per-file manual cp from `/etc/skel`.
- **Persistent repo pattern**: repos enabled during build.sh + kept enabled in the shipped image let `rpm-ostree upgrade` pull new releases without touching the image. Currently used for `mise.repo`, `vscode.repo`, `kubernetes.repo`. *(`docker-ce.repo` retired 2026-05-02 with the rootless-podman swap.)*
- **GNOME-extension download at build time** needs the real `gnome-shell --version` of the running container — call `gnome-shell --version` inside the container (silverblue-main ships gnome-shell), then query `extensions.gnome.org/extension-info/?uuid=<uuid>&shell_version=<N>`. `glib2-devel`/`jq`/`unzip` are installed and removed in the same script so they don't bloat the final layer.
- **`dconf update` must run after `COPY system_files/etc /etc`.** The Containerfile has a dedicated RUN step for that, followed by the final `ostree container commit`.
- **flatpak-install service is system-level, not user.** System-wide flatpaks live under `/var/lib/flatpak`, which is mutable on atomic. User-level would require a per-user unit.
- **2026-05-02 — module refactor.** Source-tree split between `os/build_files/features/` and `os/packages/silverfox-*/src/` made it hard to see "what does the desktop module actually own?" because the dconf snippets, the GNOME-extension fetch script, and the packages.txt were in three different trees. Collapsing each capability into one directory under `os/modules/<capability>/` cut "where does X live?" lookups dramatically. Sub-package names stayed stable for upgrade safety; only the directory layout changed.
- **2026-05-02 — rootless podman over docker-ce.** Fedora atomic + rootful Docker is a known friction point: docker group footgun, daemon to enable, ostree-unfriendly storage on `/var/lib/docker`. Rootless podman is the de-facto atomic-desktop default. The persistent docker-ce repo, the `--allowerasing` swap of Fedora's containerd, and the docker-ce Requires in silverfox-base all go away with this change. `podman-docker` shim covers `docker` muscle memory; `podman-compose` covers compose.yaml workflows (~95% parity).
- **2026-05-02 — chromium install vs surface.** Chromium is genuinely useful (puppeteer/playwright headless, fallback rendering), but having two browsers in the app grid creates "which one do I open?" friction with no upside. `NoDisplay=true` patched in by `hide-chromium.sh` keeps it CLI-invokable as `chromium-browser` while removing the GUI surface. Bluefin uses the same approach for gnome-system-monitor etc.
- **2026-05-02 — chsh isn't available on ublue.** ublue-os/main strips setuid `chsh` as part of its hardening pass. `usermod -s` (root-only) is the equivalent path, and `ujust chsh [shell]` wraps it for users.
- **2026-05-02 — Bazaar over gnome-software.** Bazaar is flatpak-first (GNOME-Shell-extension-free), portable across non-GNOME variants, and matches bluefin's current direction. `ublue-os-update-services` (inherited from silverblue-main) covers OS-update notifications; `rpm-ostree` CLI covers RPM layering; the gnome-software shell-extension dependency goes away. Reversed the brief 2026-05-01 detour where Bazaar was dropped for gnome-software.
- **AI-agent alias suppression.** Aliasing `ls` → eza or `cat` → bat injects icons + ANSI escapes + git decorations + line numbers that AI agents read as raw context. 14 env-var markers (AGENT, AI_AGENT, CLAUDECODE, CURSOR_*, GEMINI_CLI, CODEX_SANDBOX, AUGMENT_AGENT, CLINE_ACTIVE, OPENCODE_CLIENT, TRAE_AI_SHELL_ID, ANTIGRAVITY_AGENT, REPL_ID, COPILOT_MODEL, SILVERFOX_NO_ALIASES) suppress the aliases. `\ls` and `\cat` always reach GNU coreutils for scripts that want deterministic output.
- **End-of-build initramfs regen.** Defensive `dracut --no-hostonly --kver "$KERNEL_VERSION" --reproducible --add ostree -f` matching bluefin's pattern. Silverfox installs only userspace packages and shouldn't invalidate the inherited initramfs, but if a future package install triggers a kernel post-script that strips drivers without rebuilding, this catches it. `--reproducible` + `DRACUT_NO_XATTR=1` keep output deterministic.
- **2026-05-01 — nix on Fedora atomic 42+ is fragile.** Three issues remained unresolved upstream as of late 2025: composefs vs ostree planner ([nix-installer#1445](https://github.com/DeterminateSystems/nix-installer/issues/1445)), SELinux mislabel of /nix paths ([#1383](https://github.com/DeterminateSystems/nix-installer/issues/1383)), /nix daemon disappearing after rpm-ostree upgrade. *Revived 2026-05-13 with all three addressed: Determinate installer handles SELinux (`var_t` context), systemd `.mount` unit handles composefs (binds `/var/lib/nix` to `/nix`), `--persistence /var/lib/nix` ensures `/var`-based state survives ostree generations. See `.specs/features/nix/context.md` D-03/D-04.*
- **2026-05-01 — starship: COPR detour, then upstream binary.** Tried `atim/starship` COPR (worked), evaluated dropping the COPR layer entirely, decided to fetch `releases/latest/download/starship-x86_64-unknown-linux-musl.tar.gz` + sha256 in `os/modules/shell-tools/starship-install.sh`. **Lesson: on atomic images, every "RPM-tracked third-party package" should clear a real bar — what does `rpm-ostree upgrade` actually buy you over a baked binary, given image rebuilds happen anyway?** For starship the answer was "nothing meaningful"; for docker-ce/mise/vscode/kubectl the answer is "frequent security and feature updates that users genuinely want between rebuilds."
- **Phase R lessons (2026-04-30, run 25188178498)** still apply:
  - **`/ctx` bind-mount layout is `/ctx/lib/...` and `/ctx/modules/...`** post-refactor (was `/ctx/build_files/...`). The orchestrator at `/ctx/lib/build.sh` references `/ctx/modules/<name>/`.
  - **RPM file-path Requires resolves through the rpmdb, not the filesystem.** Use `ConditionPathExists=` in systemd units instead.
  - **`rpm -Uvh --replacefiles --replacepkgs` does not bypass package-level `Conflicts:`.** silverblue-{main,nvidia}:43 ship `ublue-os-signing` and `silverfox-signing.spec` declares `Conflicts:` against it. Containerfile must `rpm -e --nodeps ublue-os-signing` *before* the install step.
  - **`set -o pipefail` makes `var=$(... | grep ...)` a hidden landmine** when the grep can find nothing. Capture into a variable first, then `grep ... || true`, then validate.

- **2026-05-11 — ublue-os-just removal.** The inherited ublue RPM was pruned from the image build (added to `install-packages.sh`'s remove list alongside firefox/gnome-software/gnome-terminal). Before removal, three useful recipes were ported to fox (`toggle-banner`, expanded `cleanup`, `upgrade-firmware`) and `upgrade` was expanded to cover flatpak + distrobox. The motd display script (`/etc/profile.d/user-motd.sh`) had to be replaced by silverfox's own `silverfox-motd.sh` — a 10-line profile.d script that cats `/etc/user-motd`. Lesson: when depending on an upstream RPM for runtime behavior (motd display), ensure the replacement is ready before the RPM is removed. The motd.sh replacement cost was ~5 minutes to write + 2 lines in the spec `%files`. Simpler than anticipated.

## Deferred
- Tailscale daemon + GNOME indicator. (Niri migration may change the indicator angle.)
- QCOW2 / raw bootc-image-builder outputs (ISO landed 2026-04-30; qcow2/raw still skipped).
- Matrix builds (aarch64).
- Bitwarden CLI integration via chezmoi templates (chezmoi-home D-07 — user can opt in by editing their chezmoi source tree; image stays neutral).
- VS Code extension auto-install via `code --install-extension` in /etc/profile.d/ (chezmoi-home open concern; not worth the time-to-first-shell penalty for now).
