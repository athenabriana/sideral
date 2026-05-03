# nushell — Tasks

Generated from spec.md (22 requirements, NSH-21 already implemented).

Gate matrix (from TESTING.md):
- Shell scripts touched → `just lint`
- Containerfile / packages.txt / rpm/ / src/ touched → `just build`
- Text-only (specs, justfile recipes, motd) → none

---

## Phase 1 — Fish removal + nushell wiring (P1)

### T01 — Remove fish from packages + spec [P]
**NSH-01, NSH-02**
**What**: Remove `fish` from `packages.txt` and from `sideral-cli-tools.spec Requires`. Update spec description and changelog to reflect three-shell set is now bash/zsh/nu.
**Where**:
- `os/modules/shell-tools/packages.txt` — delete `fish` and its comment block
- `os/modules/shell-tools/rpm/sideral-cli-tools.spec` — remove `Requires: fish`; update `%description` shell list; add changelog entry
**Depends on**: —
**Done when**: `fish` absent from both files; spec still valid RPM syntax
**Gate**: `just build`

---

### T02 — Remove fish init file + spec entry [P]
**NSH-03**
**What**: Delete `sideral-cli-init.fish`; remove it from `sideral-shell-ux.spec %files`; update spec description and changelog.
**Where**:
- `os/modules/shell-init/src/etc/fish/conf.d/sideral-cli-init.fish` — delete file
- `os/modules/shell-init/rpm/sideral-shell-ux.spec` — remove `/etc/fish/conf.d/sideral-cli-init.fish` from `%files`; update `%description`; add changelog entry
**Depends on**: —
**Done when**: fish init file gone; spec `%files` no longer lists it; `just build` passes
**Gate**: `just build`

---

### T03 — Add nushell to packages + spec [P]
**NSH-04**
**What**: Add `nushell` (verify exact Fedora package name via `dnf5 info nushell` at task time — binary is `nu`, package may be `nushell`) to `packages.txt` and `sideral-cli-tools.spec Requires`. Update spec description.
**Where**:
- `os/modules/shell-tools/packages.txt` — add `nushell` with comment
- `os/modules/shell-tools/rpm/sideral-cli-tools.spec` — add `Requires: nushell`; update `%description`; add changelog entry
**Depends on**: —
**Done when**: nushell in both files; `just build` passes; `which nu` resolves in the image
**Gate**: `just build`

---

### T04 — Create nushell vendor autoload init [P]
**NSH-05**
**What**: Create `/usr/share/nushell/vendor/autoload/sideral-cli-init.nu`. Wire (env-phase safe): starship, atuin (`--disable-up-arrow`), zoxide, `view` command (guarded by highlight plugin), agent detection (same 14-marker list as bash/zsh), `$env.EDITOR`/`$env.VISUAL`. No eza/bat aliases (D-07). No mise, no keybindings, no carapace (D-01, D-03).
**Where**:
- `os/modules/shell-init/src/usr/share/nushell/vendor/autoload/sideral-cli-init.nu` — create
- `os/modules/shell-init/rpm/sideral-shell-ux.spec` — add file path to `%files`; add `cp -a usr` is already in `%install` (verify); add changelog entry
**Depends on**: T03 (nushell must be in image for vendor autoload path to exist)
**Done when**: file exists; loads without error in `nu -c ""`; starship/atuin/zoxide wired; `view` defined when highlight plugin present; `just build` passes
**Gate**: `just build`

**Implementation notes**:
```nu
# Agent detection in nushell — check env vars via $env | get --ignore-errors
# Tool inits: `starship init nu | save -f /tmp/starship-init.nu; source /tmp/starship-init.nu`
# atuin: `atuin init nu --disable-up-arrow | save -f ...`
# zoxide: `zoxide init nushell | save -f ...`
# view command:
#   def view [file: path] {
#     if (plugin list | where name == "nu_plugin_highlight" | is-not-empty) {
#       open --raw $file | highlight
#     } else {
#       open --raw $file
#     }
#   }
```

---

### T05 — Update ujust chsh + motd [P]
**NSH-06, NSH-07**
**What**: Replace `fish` with `nu` in the `ujust chsh` interactive picker and add `/usr/bin/nu` as a valid target. Update `ujust tools` motd to reference `nu` instead of `fish`.
**Where**:
- `os/modules/shell-init/src/usr/share/ublue-os/just/60-custom.just` — update `chsh` recipe; update `tools` motd text
**Depends on**: —
**Done when**: `ujust chsh` picker offers `{bash, zsh, nu}`; `ujust chsh nu` sets shell to `/usr/bin/nu`; fish absent from picker; motd references `nu`
**Gate**: none (text-only justfile changes; `just lint` does not cover justfile)

---

### T06 — Update sideral-shell-ux.spec for nushell
**NSH-08, NSH-09**
**What**: Update `sideral-shell-ux.spec` `%description` to reflect fish removal and nushell addition. Add changelog entry. (File additions handled per-task in T04, T07, T09.)
**Where**:
- `os/modules/shell-init/rpm/sideral-shell-ux.spec` — update `%description` shell list; bump summary line
**Depends on**: T02 (fish removed), T04 (nushell added)
**Done when**: description accurate; spec valid; `just build` passes
**Gate**: `just build`

---

### T07 — Create sideral-shell-seed.service unit [P]
**NSH-10, NSH-13**
**What**: Create `sideral-shell-seed.service` — systemd user unit, `Type=oneshot`, `WantedBy=default.target`, `ExecStart` pointing to the seed script. Add to `sideral-shell-ux.spec %files` and `%install`.
**Where**:
- `os/modules/shell-init/src/usr/lib/systemd/user/sideral-shell-seed.service` — create
- `os/modules/shell-init/rpm/sideral-shell-ux.spec` — add to `%files`; add changelog entry
**Depends on**: —
**Done when**: unit file present; `systemd-analyze verify` passes on the unit; `just build` passes
**Gate**: `just build`

---

### T08 — Create seed script
**NSH-11, NSH-22**
**What**: Create `/usr/libexec/sideral-shell-seed` — the idempotent seed script run by the service. Handles in order:
1. Broken login shell check: if `$SHELL` binary absent → `usermod -s /usr/bin/zsh "$USER"`
2. Seed `~/.bashrc` if missing (sources `/etc/bashrc`; placeholder comment)
3. Seed `~/.zshrc` if missing (placeholder comment only — `/etc/zshrc` already loads init)
4. Seed `~/.config/nushell/env.nu` if missing (mise shims on PATH)
5. Seed `~/.config/nushell/config.nu` if missing (mise activate + carapace completer + Ctrl-P keybinding)
6. Seed `~/.config/mise/config.toml` if missing (full toolchain: node/bun/pnpm, python/uv, java/kotlin/gradle, go/rust/zig, act)

All writes are atomic (write to tmp, move into place). Never overwrites existing files. Idempotent.
**Where**:
- `os/modules/shell-init/src/usr/libexec/sideral-shell-seed` — create (bash script, +x)
- `os/modules/shell-init/rpm/sideral-shell-ux.spec` — add `/usr/libexec/sideral-shell-seed` to `%files`; add `%attr(0755,root,root)` prefix
**Depends on**: T07 (service references this script path)
**Done when**: script passes shellcheck; handles all 6 seed cases; idempotent on re-run; `just lint` + `just build` pass
**Gate**: `just lint` then `just build`

---

### T09 — Package seed service in spec
**NSH-12**
**What**: Verify `sideral-shell-ux.spec %install` copies `usr/` tree (it already does `cp -a usr %{buildroot}/`). Confirm both the service unit and seed script are in `%files`. Final spec review for this phase.
**Where**:
- `os/modules/shell-init/rpm/sideral-shell-ux.spec`
**Depends on**: T07, T08
**Done when**: `rpm -qlp sideral-shell-ux-*.rpm` shows both `/usr/lib/systemd/user/sideral-shell-seed.service` and `/usr/libexec/sideral-shell-seed`; `just build` passes
**Gate**: `just build`

---

## Phase 2 — Carapace completions (P2)

### T10 — Carapace binary install script [P]
**NSH-17**
**What**: Create `carapace-install.sh` — fetch latest carapace-bin x86_64 Linux static binary from GitHub releases, sha256-verify, install to `/usr/bin/carapace`. Same pattern as `starship-install.sh`. Pin version; download sha256 from the same release page.
**Where**:
- `os/modules/shell-tools/carapace-install.sh` — create (+x)
- `os/lib/build.sh` — add `bash /ctx/modules/shell-tools/carapace-install.sh` call (same position as starship)
**Depends on**: —
**Done when**: `which carapace` resolves in image; sha256 verified at build time; `just build` passes
**Gate**: `just build`

---

### T11 — Bash carapace completion backend [P]
**NSH-18**
**What**: Add `source <(carapace _carapace bash)` to `sideral-cli-init.sh` (guarded by `command -v carapace`). Remove any explicit `bash-completion` sourcing if present. Place after fzf init (completions should load after other tools).
**Where**:
- `os/modules/shell-init/src/etc/profile.d/sideral-cli-init.sh`
**Depends on**: T10 (carapace binary installed)
**Done when**: carapace init present in bash init; guarded; `just lint` passes
**Gate**: `just lint`

---

### T12 — Zsh carapace completion backend [P]
**NSH-19**
**What**: Add `source <(carapace _carapace zsh)` to `sideral-cli-init.zsh` (guarded by `(( ${+commands[carapace]} ))`). Remove any `compinit`/`_comp_init` call in `/etc/zshrc` or the zsh init — carapace calls compinit internally. Place after fzf init, before syntax-highlighting (which must stay last).
**Where**:
- `os/modules/shell-init/src/etc/zsh/sideral-cli-init.zsh`
- `os/modules/shell-init/src/etc/zshrc` — verify no compinit present (it's currently just `umask + source`)
**Depends on**: T10 (carapace binary installed)
**Done when**: carapace init present; no compinit double-init; syntax-highlighting still loads last; `just lint` passes
**Gate**: `just lint`

---

## Phase 3 — Nushell plugins (P2)

### T13 — Build and install 7 plugins
**NSH-14, NSH-15**
**What**: Add a new `RUN` layer in `Containerfile` (before the RPM layer) that:
1. Installs nupm + Rust toolchain (cargo)
2. For each plugin: attempt `nupm install --git <repo>`; on failure apply per-plugin fallback (D-04):
   - query/formats/gstat → extract from matching nushell release tarball
   - nu_plugin_file → pre-built GitHub release binary + sha256
   - highlight/rpm/explore → `cargo install`
3. Moves compiled binaries to `/usr/lib/nushell/plugins/`
4. Tears down Rust toolchain and nupm
5. Verifies nu_plugin_explore compatibility with installed nushell version (D-06); drops it if incompatible

All in one `RUN` layer to avoid bloating intermediate layers.
**Where**:
- `os/Containerfile` — add plugin build RUN layer after the main build.sh layer
- Optionally: `os/modules/shell-tools/nushell-plugins-install.sh` — extract into script for readability
**Depends on**: T03 (nushell installed)
**Done when**: `/usr/lib/nushell/plugins/nu_plugin_{query,formats,gstat,file,highlight,rpm,explore}` present (or explore dropped per D-06); `just build` passes
**Gate**: `just build`

---

### T14 — Plugin registration in seed script
**NSH-16**
**What**: Extend the seed script (T08) to register each plugin not yet in `~/.config/nushell/plugin.msgpackz`. For each binary in `/usr/lib/nushell/plugins/`: run `nu --commands "plugin add /usr/lib/nushell/plugins/<name>"` if plugin not already registered. Plugin errors are non-fatal (continue on failure per spec AC3).
**Where**:
- `os/modules/shell-init/src/usr/libexec/sideral-shell-seed` — add plugin registration loop
**Depends on**: T08 (seed script exists), T13 (plugin binaries installed)
**Done when**: seed script registers plugins idempotently; continues on per-plugin failure; `just lint` passes
**Gate**: `just lint`

---

## Requirement coverage

| Req | Task | Status |
|---|---|---|
| NSH-01 | T01 | Pending |
| NSH-02 | T01 | Pending |
| NSH-03 | T02 | Pending |
| NSH-04 | T03 | Pending |
| NSH-05 | T04 | Pending |
| NSH-06 | T05 | Pending |
| NSH-07 | T05 | Pending |
| NSH-08 | T06 | Pending |
| NSH-09 | T01+T06 | Pending |
| NSH-10 | T07 | Pending |
| NSH-11 | T08 | Pending |
| NSH-12 | T09 | Pending |
| NSH-13 | T07 | Pending |
| NSH-14 | T13 | Pending |
| NSH-15 | T13 | Pending |
| NSH-16 | T14 | Pending |
| NSH-17 | T10 | Pending |
| NSH-18 | T11 | Pending |
| NSH-19 | T12 | Pending |
| NSH-20 | T08 | Pending |
| NSH-21 | — | Implemented |
| NSH-22 | T08 | Pending |
