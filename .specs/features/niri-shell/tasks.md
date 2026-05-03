# niri-shell Tasks

> Spec: `spec.md` · Design: `design.md` · Context: `context.md`
> Source-tree work for the GNOME → niri+Noctalia swap. All 17 D-XX decisions locked 2026-05-02.

## Implementation-time decisions (resolved upfront before T-tasks)

- **Noctalia launch**: niri config uses `spawn-at-startup "noctalia-shell"` (the upstream-shipped wrapper that internally invokes `qs -c noctalia-shell`). Falls back to `qs -c noctalia-shell` if a future Terra noctalia-shell drops the wrapper.
- **Noctalia config seed**: ship `/etc/skel/.config/noctalia/settings.json` (user-side seed) — do NOT overwrite `/etc/xdg/quickshell/noctalia-shell/` (RPM-owned by `noctalia-shell` from Terra). The design's `sideral-overrides.json` is dropped.
- **matugen template for Noctalia**: NOT shipped. Noctalia has its own internal theming pipeline (Python template-processor + built-in matugen integration). `ujust theme` writes only ghostty + helix; Noctalia's recolor goes through its own wallpaper picker.
- **Terra repo URL**: `https://repos.fyralabs.com/terra$releasever`, gpgkey `https://repos.fyralabs.com/terra$releasever/key.asc`. (Original URL `repo.terra.fyralabs.com` was NXDOMAIN — corrected 2026-05-03 after CI failure.)
- **SilentSDDM tag**: pinned to **v1.4.2** (latest stable as of 2026-05-02).
- **niri include directive**: design's `include "/etc/xdg/niri/config.d/*.kdl"` syntax (string-quoted glob) per niri ≥0.1.5 docs; Fedora-main `niri-26.04` supports it.
- **niri.desktop wayland-session entry**: ship sideral's copy at `/usr/share/wayland-sessions/niri.desktop`. If Fedora-main `niri` RPM also ships it, `rpm -Uvh --replacefiles` reconciles ownership.

---

## Phase 1 — `desktop-niri/` module skeleton

### T01: Create `desktop-niri/packages.txt` + `terra.repo`
- **Files**: `os/modules/desktop-niri/packages.txt`, `os/modules/desktop-niri/src/etc/yum.repos.d/terra.repo`.
- **Reuses**: `os/modules/meta/src/etc/yum.repos.d/mise.repo` shape.
- **Done when**: packages.txt lists Fedora-main + Terra packages (one per line, comments allowed); terra.repo enabled=1 with verified gpgkey URL.
- **Gate**: none (text only).

### T02: Create `sddm-silent-install.sh`
- **Files**: `os/modules/desktop-niri/sddm-silent-install.sh` (executable).
- **Reuses**: `os/modules/shell-tools/starship-install.sh` curl + sha256-verify shape.
- **Done when**: pins `v1.4.2` tag; downloads tarball; verifies sha256 (computed at first build, pinned in script); extracts to `/usr/share/sddm/themes/silent/`; idempotent on re-run.
- **Gate**: `just lint`.

### T03: Create niri config (`config.kdl`) — system + skel layers
- **Files**: `os/modules/desktop-niri/src/etc/xdg/niri/config.kdl`, `os/modules/desktop-niri/src/etc/skel/.config/niri/config.kdl` (identical content).
- **Done when**: KDL config covers input/layout/binds (Mod+T → ghostty, Mod+D launcher via Noctalia, Mod+L lock, Mod+Q close, Mod+arrow column nav, Mod+Shift+arrow column move, workspace 1–9, screenshot, volume keys); spawn-at-startup for kanshi, fcitx5, cliphist watcher, noctalia-shell; trailing `include "/etc/xdg/niri/config.d/*.kdl"` for nvidia drop-in.
- **Gate**: none (no shell scripts touched).

### T04: Create matugen templates + config — system + skel layers
- **Files**:
  - `os/modules/desktop-niri/src/etc/xdg/matugen/config.toml`
  - `os/modules/desktop-niri/src/etc/xdg/matugen/templates/ghostty`
  - `os/modules/desktop-niri/src/etc/xdg/matugen/templates/helix.toml`
  - `os/modules/desktop-niri/src/etc/skel/.config/matugen/config.toml`
  - `os/modules/desktop-niri/src/etc/skel/.config/matugen/templates/ghostty`
  - `os/modules/desktop-niri/src/etc/skel/.config/matugen/templates/helix.toml`
- **Done when**: config.toml maps each template to its `~/.config/<app>/...` output path; ghostty template emits palette stanza; helix template emits a Material 3 → Helix theme TOML at `~/.config/helix/themes/sideral.toml`.
- **Gate**: none.

### T05: Create misc src files
- **Files**:
  - `os/modules/desktop-niri/src/etc/sddm.conf.d/sideral-silent.conf` (`[Theme] Current=silent`)
  - `os/modules/desktop-niri/src/etc/profile.d/sideral-niri-ime.sh` (XMODIFIERS / GTK_IM_MODULE / QT_IM_MODULE)
  - `os/modules/desktop-niri/src/etc/skel/.config/noctalia/settings.json` (sideral defaults seed; minimal — just what we want to override from upstream)
  - `os/modules/desktop-niri/src/usr/share/wayland-sessions/niri.desktop` (`Exec=niri-session`)
  - `os/modules/desktop-niri/src/usr/share/wallpapers/sideral/README.md` (placeholder noting user must drop a `default.jpg` here; spec demands a JPEG, image asset added in a follow-up commit)
- **Done when**: each file present with correct content; profile.d snippet passes `shellcheck`.
- **Gate**: `just lint`.

### T06: Create `sideral-niri-defaults.spec`
- **Files**: `os/modules/desktop-niri/rpm/sideral-niri-defaults.spec`.
- **Reuses**: `os/modules/shell-init/rpm/sideral-shell-ux.spec` shape.
- **Done when**: spec owns every src/ path from T01/T03/T04/T05 in `%files`; `Requires: niri sddm noctalia-shell noctalia-qs ghostty rust-matugen kanshi fcitx5 fcitx5-configtool grim slurp wl-clipboard cliphist`; `Conflicts: gdm gnome-shell gnome-session mutter gnome-control-center gnome-settings-daemon`; no `%post` needed.
- **Gate**: none (verified by full build later).

### T07: Create `desktop-niri/README.md`
- **Files**: `os/modules/desktop-niri/README.md`.
- **Done when**: documents pinned versions, file layout, where to override via chezmoi, NVIDIA known-issues section per NIR-34.
- **Gate**: none.

---

## Phase 2 — nvidia module updates

### T10: Add `nvidia/packages.txt`
- **Files**: `os/modules/nvidia/packages.txt` (NEW).
- **Done when**: lists `libva-nvidia-driver` + `libva-utils`.
- **Gate**: none. (build.sh installs these only when the module dir has packages.txt; `apply.sh` still gates the rest on `rpm -q kmod-nvidia` — but `dnf5 install` on the open-source build will cleanly pull the libva packages too, which is harmless. Confirmed safe per spec NIR-33f.)

> **Re-verified during T10 implementation**: `libva-nvidia-driver` Requires `libva` (always present) but does NOT Require kmod-nvidia, so installing it on the open-source variant is safe — the driver loads only if NVIDIA hardware is present. `libva-utils` is generic. Decision: keep `packages.txt` shipped on both variants for build symmetry; the `apply.sh` gate covers the variant-specific config files only.

### T11: Update `nvidia/kargs.d/00-nvidia.toml`
- Add `nvidia-drm.fbdev=1` to the kargs list. Comment update for the new karg.
- **Gate**: none.

### T12: Add `nvidia/modprobe.d/sideral-nvidia.conf`
- 4 NVreg options per spec NIR-33b.
- **Gate**: none.

### T13: Add `nvidia/nvidia-app-profiles/50-niri.json`
- niri-procname GLVidHeapReuseRatio=0 profile per NIR-33c.
- **Gate**: none.

### T14: Add `nvidia/environment.d/90-sideral-niri-nvidia.conf`
- 5 env vars per NIR-33e.
- **Gate**: none.

### T15: Add `nvidia/niri.config.d/sideral-nvidia.kdl`
- `debug { disable-cursor-plane }` block per NIR-33d.
- **Gate**: none.

### T16: Update `nvidia/apply.sh`
- Drop dconf install line; add 5 new install lines (kargs unchanged path; modprobe.d, app-profiles, environment.d, niri.config.d).
- **Gate**: `just lint`.

### T17: Delete `nvidia/dconf/50-sideral-nvidia`
- `git rm` the file (and the `dconf/` dir if empty).
- **Gate**: none.

---

## Phase 3 — orchestrator + Containerfile

### T20: Update `os/lib/build.sh`
- MODULES list: `desktop` → `desktop-niri`.
- Base prune list: append `gdm gnome-shell gnome-session mutter gnome-control-center gnome-settings-daemon gnome-shell-extension-appindicator gnome-shell-extension-dash-to-panel`.
- **Gate**: `just lint`.

### T21: Update `os/Containerfile`
- Drop the trailing `RUN dconf update && ostree container commit` block (sideral-dconf retired; nothing in /etc/dconf/db/local.d/).
- **Gate**: full `just build` (deferred to Phase 6).

---

## Phase 4 — meta + shell-init updates

### T30: Update `sideral-base.spec`
- Drop `Requires: sideral-dconf`; add `Requires: sideral-niri-defaults`.
- Add changelog entry.
- **Gate**: none.

### T31: Update `user-motd`
- Add one row pointing at `ujust niri`.
- **Gate**: none.

### T32: Add `theme` + `niri` recipes to `60-custom.just`
- `ujust theme <wallpaper>` per design.
- `ujust niri` cheatsheet modeled on existing `tools` recipe.
- **Gate**: none (just-syntax only; `just lint` shellchecks the embedded bash heredocs).

### T33: Update `sideral-shell-ux.spec` changelog
- Add entry for the motd row + 60-custom.just recipes.
- **Gate**: none.

---

## Phase 5 — delete old desktop module

### T40: `git rm -r os/modules/desktop/`
- Removes `packages.txt`, `extensions.sh`, `rpm/sideral-dconf.spec`, `src/etc/dconf/...`.
- **Gate**: none.

---

## Phase 6 — top-level docs + final gate

### T50: Update top-level `README.md`
- Document niri image, default keybinds, rollback path. No "rebase to a frozen GNOME tag" instruction (D-15 lock).
- **Gate**: none.

### T60: Final `just lint`
- Confirms shellcheck passes across all modified `*.sh`.

### T61: Final `just build` (full image build + bootc lint)
- Confirms the full image builds end-to-end on at least the open-source variant (silverblue-main:43). NVIDIA matrix runs in CI.
- **NOTE**: image-rebase verification (boot a VM, log in, see niri+Noctalia) is a manual step beyond /spec-run scope; flagged in the validation report.

---

## Traceability

| Task | Spec ACs covered |
|---|---|
| T01 | NIR-02, NIR-05, NIR-07, NIR-09, NIR-15c, NIR-15d, NIR-15e, NIR-16, deps table |
| T02 | NIR-01 |
| T03 | NIR-02, NIR-03, NIR-04, NIR-07, NIR-15c, NIR-15d, NIR-15e |
| T04 | NIR-17, NIR-28, NIR-29 |
| T05 | NIR-01, NIR-15e |
| T06 | NIR-03, NIR-23, NIR-27 + cross-cutting Conflicts |
| T07 | NIR-34, NIR-36 |
| T10–T17 | NIR-32, NIR-33, NIR-33a–h |
| T20 | cross-cutting prune ACs |
| T21 | cross-cutting bootc lint AC |
| T30 | cross-cutting RPM graph |
| T31 | NIR-23 |
| T32 | NIR-18, NIR-22a |
| T40 | cross-cutting "desktop/ removed" AC |
| T50 | NIR-35, NIR-37 |

---

## Notes

- Tasks T01–T07 in Phase 1 are mostly file creates with no inter-dependencies, so they can be done in parallel within one batch.
- T17 deletion needs to land in the same commit as T16 to avoid a window where apply.sh references a missing file.
- The default wallpaper JPEG (NIR-15b) is left as a placeholder README in T05 — the actual binary image asset is a manual user-side commit, not something /spec-run can produce.
