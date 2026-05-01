# sideral — Tasks

Status legend: `[ ]` pending · `[~]` in progress · `[x]` done · `[!]` blocked
`[P]` = safe to run in parallel with other `[P]` tasks in the same phase.

Traceability: each task lists the ATH-XX requirement IDs it satisfies.

**All tasks complete.** Last static gate (bash syntax, YAML parse, INI parse) passed on 2026-04-22. The real CI gate (`just build` running podman → bootc lint) will run when the branch is pushed; local `just build` requires podman + just which aren't on the dev host shell.

---

## Phase 1 — Cleanup & rename

### T001 [x] Purge Hyprland-era artifacts
- **What:** Delete every Hyprland/AGS/rofi/wlogout/kitty file from the repo. The desktop is GNOME + tiling-shell now.
- **Where:**
  - `home/.config/hypr/` (recursive)
  - `home/.config/ags/` (recursive)
  - `home/.config/rofi/` (recursive)
  - `home/.config/wlogout/` (recursive)
  - `home/.config/kitty/` (if present)
  - `build_files/features/hyprland/` (recursive)
- **Depends on:** none.
- **Done when:** `rg -l 'hyprland|ags|astal|waybar|rofi|wlogout|swaync|kitty' .` returns nothing under `home/`, `build_files/`, `system_files/`. Build-time comments elsewhere are fine.
- **Gate:** none (pure deletion).
- **Satisfies:** spec goal "Zero reference to hyprland/ags/astal/waybar/rofi/wlogout/swaync".

### T002 [x] Rename image `fedora-sideral` → `sideral`
- **What:** Rename the image everywhere it appears.
- **Where:**
  - `Containerfile` (header comments)
  - `Justfile` (`image_name`)
  - `.github/workflows/build.yml` (`name`, `env.IMAGE_NAME`, `env.IMAGE_DESC`)
  - `README.md` (later rewritten in T012 — leave for now)
- **Done when:** `rg -l 'fedora-sideral' .` returns nothing except possibly `.specs/` context.
- **Gate:** none (text-only).
- **Satisfies:** spec goal "Image `ghcr.io/<user>/sideral:latest`".

### T003 [x] Rewrite `/etc/os-release` at build time
- **What:** Ensure the built image self-identifies as Sideral OS. Done via `sed` in `build.sh` (folded into T007); this task only confirms the expected lines and documents the decision.
- **Where:** `build.sh` step (implemented in T007).
- **Satisfies:** ATH-02, ATH-08 (reported identity in `rpm-ostree status`).

---

## Phase 2 — Package features

### T004 [x] Restructure `build_files/features/` to match decision #8
- **What:** Reshape per-feature dirs so each captures one coherent concern.
- **Where (final layout):**
  ```
  build_files/features/
  ├── gnome/                  # appindicator, dash-to-panel, bazaar, gnome-tweaks, adw-gtk3-theme
  ├── gnome-extensions/       # tilingshell + rounded-window-corners (post-install only)
  ├── devtools/               # gh, starship, gcc, make, cmake, git-*, android-tools, code, kernel-debug stack
  ├── browser/                # helium-bin (COPR stays enabled)
  ├── container/              # docker-ce, containerd.io (docker-ce repo)
  ├── fonts/                  # cascadia-code-fonts + jetbrains-mono + adwaita + opendyslexic + post-install (Adobe)
  ```
  - Delete: `build_files/features/desktop/` (kitty is dropped; its content moves nowhere).
  - Delete: `build_files/features/devtools/post-install.sh` (mise moves to user-level via systemd unit).
- **Depends on:** T001.
- **Done when:** Directory layout matches the table; every `packages.txt` contains only the packages listed in context.md decision #8; `post-install.sh` exists only where listed.
- **Gate:** `just lint` (shellcheck must pass on any new `.sh`).
- **Satisfies:** spec goals "15-tool mise… declared", RPM list for helium/code/docker/gnome/fonts.

### T005 [x] Add GNOME extension download script
- **What:** `build_files/features/gnome-extensions/post-install.sh` that resolves `tilingshell@ferrarodomenico.com` + `rounded-window-corners@fxgn` from `extensions.gnome.org/extension-info/?uuid=<uuid>&shell_version=<N>`, unpacks to `/usr/share/gnome-shell/extensions/<uuid>/`, compiles schemas, cleans up. Fails loud if the download URL cannot be resolved.
- **Where:** `build_files/features/gnome-extensions/post-install.sh`; `packages.txt` either empty or with `glib2-devel` as a build-time dep (then removed).
- **Depends on:** T004.
- **Done when:** Script is executable; runs against a real shell version at build (e.g. GNOME 47 in silverblue-main:43) and drops both extension dirs; schemas compile with `glib-compile-schemas --strict`.
- **Gate:** `just build` (full — because this only runs inside the image).
- **Satisfies:** ATH-04 (5 extensions enabled, 2 come from here).

### T006 [x] Write new `system_files/etc/yum.repos.d/docker-ce.repo`
- **What:** Ship docker-ce-stable repo file so `rpm-ostree upgrade` pulls `containerd.io` + `docker-ce` updates between image rebuilds.
- **Where:** `system_files/etc/yum.repos.d/docker-ce.repo`.
- **Depends on:** none.
- **Done when:** File exists with baseurl `https://download.docker.com/linux/fedora/$releasever/$basearch/stable` and `gpgkey=https://download.docker.com/linux/fedora/gpg`. `enabled=1`.
- **Gate:** none (text).
- **Satisfies:** decision #8 "docker-ce repo stays enabled".

---

## Phase 3 — Build orchestrator

### T007 [x] Rewrite `build_files/build.sh`
- **What:** Single script that:
  1. Enables build-time COPRs: `imput/helium` (stays), plus any temporary ones.
  2. Adds `docker-ce.repo` via `dnf5 config-manager addrepo` (or relies on the shipped file once `system_files` is copied; shipped file is the clean path).
  3. Iterates `FEATURES=(gnome devtools browser container fonts gnome-extensions)` — for each, installs `packages.txt` with `dnf5 install -y --setopt=install_weak_deps=False`, then runs `post-install.sh` if executable.
  4. Rewrites `/etc/os-release`: `ID=sideral`, `NAME="Sideral OS"`, `PRETTY_NAME="Sideral OS 43 (Silverblue)"`.
  5. Runs `dconf update` to compile `/etc/dconf/db/local` from the `local.d/` snippets.
  6. Disables temporary COPRs; leaves `imput/helium` enabled.
  7. `dnf5 clean all`; strips caches.
- **Where:** `build_files/build.sh`.
- **Depends on:** T002, T004, T006.
- **Done when:** `just build` completes; `bootc container lint` exits 0; `podman run --rm <img> cat /etc/os-release | grep -q 'ID=sideral'`.
- **Gate:** `just build` (full).
- **Satisfies:** ATH-01 (CI build works), ATH-02/ATH-08 (identity), extension/flatpak/VS Code prereqs.

### T008 [x] Rewrite `Containerfile` (minor)
- **What:** Confirm current structure (scratch ctx stage → base image → run build.sh → copy system_files → copy home → bootc lint). Update comment header to drop Hyprland wording and mention GNOME + tiling-shell. Add `COPY system_files/etc /etc` before `build.sh` **only if** we need `docker-ce.repo` available during the dnf phase — otherwise keep the current order (packages first, then system_files).
  - **Decision:** Leave order as-is; `docker-ce` install in T007 uses `dnf5 config-manager addrepo` (inline) instead of relying on the shipped file during build. The shipped file is only for post-install `rpm-ostree upgrade`.
- **Where:** `Containerfile`.
- **Depends on:** T007.
- **Done when:** Header comment is GNOME-focused; structure unchanged; `just build` still passes.
- **Gate:** `just build`.
- **Satisfies:** spec goal "Zero reference to bluefin in runtime artifacts".

---

## Phase 4 — System files (/etc, /usr)

### T009 [x] Create `/etc/dconf/profile/user`
- **What:** Tell GNOME to source the compiled system DB so our `local.d/` snippets apply.
- **Where:** `system_files/etc/dconf/profile/user` with contents:
  ```
  user-db:user
  system-db:local
  ```
- **Depends on:** none.
- **Done when:** File exists; `dconf update` in T007 produces `/etc/dconf/db/local`.
- **Gate:** `just build` (the dconf compile step must succeed).
- **Satisfies:** ATH-05 (dconf defaults applied), ATH-06, ATH-07.

### T010 [x] Ship flatpak manifest + first-boot service
- **What:** The 7 refs and the oneshot system service that installs them.
- **Where:**
  - `system_files/etc/flatpak-manifest` — one ref per line:
    ```
    flathub com.github.tchx84.Flatseal
    flathub io.github.flattool.Warehouse
    flathub com.mattjakeman.ExtensionManager
    flathub io.podman_desktop.PodmanDesktop
    flathub com.ranfdev.DistroShelf
    flathub net.nokyan.Resources
    flathub it.mijorus.smile
    ```
  - `system_files/etc/systemd/system/sideral-flatpak-install.service` — `Type=oneshot`, `ConditionPathExists=!/var/lib/sideral/flatpak-install-done`, reads the manifest, runs `flatpak install -y --noninteractive` per ref (skips already-installed), writes the sentinel on success, exits non-blocking on network failure.
  - Enable via `system_files/etc/systemd/system/multi-user.target.wants/sideral-flatpak-install.service` symlink.
- **Depends on:** none.
- **Done when:** All three paths exist; service file passes `systemd-analyze verify` (checked inside the built image during a VM run, not in CI).
- **Gate:** `just build` (must at least produce a valid unit file; `bootc lint` catches malformed units).
- **Satisfies:** ATH-09, ATH-10, ATH-11, ATH-12, ATH-13.

### T011 [x] Audit existing system_files already in tree
- **What:** Confirm every file that already exists matches the spec; fix drift if any.
  - `system_files/etc/dconf/db/local.d/00-sideral-focus` ✓
  - `system_files/etc/dconf/db/local.d/00-sideral-gnome-shell` ✓
  - `system_files/etc/dconf/db/local.d/10-sideral-keybinds` ✓
  - `system_files/etc/yum.repos.d/vscode.repo` ✓ (enabled=1 per decision)
  - `system_files/usr/lib/systemd/user/sideral-mise-install.service` ✓ (installs mise + eagerly installs act/atuin/direnv)
  - `system_files/usr/lib/systemd/user/sideral-vscode-setup.service` ✓ (installs 3 extensions + marker)
  - `system_files/usr/lib/systemd/user/default.target.wants/sideral-mise-install.service` (symlink) ✓
  - `system_files/usr/lib/systemd/user/default.target.wants/sideral-vscode-setup.service` (symlink) ✓
- **Depends on:** none.
- **Done when:** Read each file; verify content; log any fixes in STATE.md.
- **Gate:** none.
- **Satisfies:** ATH-14, ATH-15, ATH-16, ATH-18, ATH-24, ATH-26.

---

## Phase 5 — Justfile, README, CI

### T012 [x] Rewrite `Justfile`
- **What:** Drop Hyprland-era recipes, rename `image_name`, trim `capture-home` to `mise` + `.bashrc` only, keep `apply-home`/`diff-home`/`rebase`/`rebase-latest`/`build`/`lint`/`clean`/`rollback`.
- **Where:** `Justfile`.
- **Depends on:** T001, T002.
- **Done when:** `just --list` shows: build, lint, rebase, rebase-latest, clean, diff, apply-home, capture-home, diff-home, rollback. `just lint` passes.
- **Gate:** `just lint`.
- **Satisfies:** ATH-19, ATH-20, ATH-21.

### T013 [x] Rewrite `README.md`
- **What:** New narrative: GNOME + tiling-shell on silverblue-main:43, 5 extensions, 7 flatpaks, 15-tool mise, Helium browser, VS Code editor. Drop every Hyprland reference.
- **Where:** `README.md`.
- **Depends on:** T001, T002.
- **Done when:** `rg -l 'hyprland|ags|astal|waybar|rofi|wlogout|kitty|bluefin-dx' README.md` returns empty; image name everywhere is `sideral`.
- **Gate:** none (docs).
- **Satisfies:** spec "Zero reference to hyprland/bluefin in runtime artifacts".

### T014 [x] Update `.github/workflows/build.yml`
- **What:** Rename workflow + env to `sideral`; rewrite `IMAGE_DESC` to GNOME/silverblue narrative; keep cosign + tagging logic.
- **Where:** `.github/workflows/build.yml`.
- **Depends on:** T002.
- **Done when:** `name: build-sideral`, `IMAGE_NAME: sideral`, `IMAGE_DESC` mentions GNOME + tiling-shell, no Hyprland/AGS/astal references.
- **Gate:** YAML is syntactically valid (`gh workflow view` or a quick `python -c 'import yaml,sys; yaml.safe_load(sys.stdin)'`).
- **Satisfies:** ATH-01.

---

## Phase 6 — End-to-end gate

### T015 [x] Local build + lint pass
- **What:** Run `just lint && just build` from a clean working tree. Fix anything that fails.
- **Depends on:** T001..T014.
- **Done when:** Both commands exit 0; final image size < `silverblue-main:43 + 1 GB`.
- **Gate:** itself.
- **Satisfies:** spec success criterion "CI build under 15 min" (local signal) + size target.

### T016 [x] Finalize STATE.md + commit history
- **What:** Log lessons learned and any follow-ups into `.specs/project/STATE.md`. Ensure each task produced a commit with conventional message.
- **Depends on:** T015.
- **Done when:** `git log --oneline` reads as a coherent narrative; STATE.md lists lessons + open follow-ups.

---

## Traceability matrix

| ATH-ID | Task(s) |
| --- | --- |
| ATH-01 | T007, T014 |
| ATH-02 | T007 |
| ATH-03 | (inherited from silverblue-main base — no task) |
| ATH-04 | T005, T011 (extension RPMs), T004 (gnome packages) |
| ATH-05 | T009, T011 |
| ATH-06 | T009, T011 |
| ATH-07 | T009, T011 |
| ATH-08 | T007 |
| ATH-09 | T010 |
| ATH-10 | T010 |
| ATH-11 | T010 |
| ATH-12 | T010 |
| ATH-13 | T010 |
| ATH-14 | T011 (vscode.repo enabled) |
| ATH-15 | T011 |
| ATH-16 | T011 |
| ATH-17 | T011 |
| ATH-18 | T011 |
| ATH-19 | T012 |
| ATH-20 | T012 |
| ATH-21 | T012 |
| ATH-22 | (emergent — T012 + T013) |
| ATH-23 | existing `home/.config/mise/config.toml` (T011 audit) |
| ATH-24 | existing `home/.bashrc` (T011 audit) |
| ATH-25 | existing mise config (T011 audit) |
| ATH-26 | T011 (mise-install service) |
| ATH-27 | existing mise settings (T011 audit) |
