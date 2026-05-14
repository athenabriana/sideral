# fox — Task Breakdown

47 requirements broken into 21 atomic tasks across 6 phases. Each task =
one commit. Trace columns map back to `spec.md` (`FOX-NN`) and
`context.md` (`D-NN`). `[P]` flags work that can run in parallel after
its declared `Depends on` lands. Status starts at `pending` and moves
through `in_progress` → `complete` (occasionally `blocked` /
`deferred`).

Gate-check matrix (from `.specs/codebase/TESTING.md`):

| Task touches                                              | Gate                                                  |
|-----------------------------------------------------------|-------------------------------------------------------|
| `os/lib/*.sh` / `os/modules/*/*.sh`                       | `just lint`                                           |
| `os/modules/fox/src/{bin,libexec,tests}/*.sh` + `bin/fox` | `just fox-lint && just fox-test` (after T13 lands)    |
| `os/Containerfile`, `packages.txt`, `src/`, `rpm/*.spec`  | `just build` (full image + `bootc container lint`)    |
| Specs, README, Justfile, workflow YAML only               | none (text-only)                                      |

The fox lint/test recipes (`just fox-lint`, `just fox-test`) come into
existence with T13. Tasks T01–T12 ship the artifacts those recipes
target; their per-task gate is plain `shellcheck` invoked locally on the
touched bash files. Once T13 lands, every subsequent bash edit must pass
`just fox-lint && just fox-test`.

---

## Phase 1 — `os/modules/fox/` new module

### T01 — fox module scaffolding

- **What**: Create `os/modules/fox/` with subdirs `src/{bin,recipes,libexec,man,tests}` and `rpm/`. No file content yet (just empty dirs preserved via `.gitkeep` if necessary, or land alongside T02–T08).
- **Where**: `os/modules/fox/{src/{bin,recipes,libexec,man,tests},rpm}/`
- **Depends on**: nothing
- **Reuses**: `os/modules/<other>/` layout convention from `.specs/project/STATE.md` "Source tree layout" decision
- **Done when**: directories exist on disk; safe to layer T02–T09 into them
- **Traceability**: FOX-22 (module dir layout)
- **Gate**: none (empty dirs)
- **Status**: pending

> Practical note: skip a separate commit if T02..T08 land in the same PR.
> The skeleton can be created by `mkdir -p` alongside the first
> content-bearing task; reserve T01 purely as a logical anchor.

### T02 — `bin/fox` bash dispatcher

- **What**: Write `os/modules/fox/src/bin/fox` (~20 lines). Shebang `#!/usr/bin/env bash`, `set -euo pipefail`. Reads `SILVERFOX_JUSTFILE` (default `/usr/share/silverfox/silverfox.justfile`) and `SILVERFOX_OS_RELEASE` (default `/etc/os-release`) from env. `case` on `$1`:
  - no arg / `--help` / `-h` → `exec just -f "$SILVERFOX_JUSTFILE" --list`
  - `--version` / `-V` → parse `VERSION_ID` from `$SILVERFOX_OS_RELEASE` via `awk -F= '/^VERSION_ID=/ {gsub(/"/,"",$2); print $2}'`, print, exit 0
  - `home` (no sub) → `exec just -f "$SILVERFOX_JUSTFILE" --list home`
  - `home <sub> [...args]` → `exec just -f "$SILVERFOX_JUSTFILE" "home::$2" "${@:3}"`
  - default → `exec just -f "$SILVERFOX_JUSTFILE" "$@"`
- **Where**: `os/modules/fox/src/bin/fox`
- **Depends on**: T01
- **Reuses**: nothing
- **Done when**: `bash -n bin/fox` passes; `shellcheck` clean; manual smoke (`SILVERFOX_JUSTFILE=/dev/null bin/fox --version` parses an injected os-release fixture).
- **Traceability**: FOX-01, FOX-02, FOX-03, FOX-04, FOX-05, FOX-17 (`bin/fox`), D-02, D-18
- **Gate**: `shellcheck os/modules/fox/src/bin/fox`
- **Status**: pending

### T03 — `recipes/silverfox.justfile`

- **What**: Write the top-level Justfile that fox dispatches into. Recipes (every body verbose enough to read in `just --list`):
  - `chsh shell="":` → `/usr/libexec/silverfox/chsh.sh {{shell}}`
  - `cheatsheet:` → `exec man 7 silverfox`
  - `update *args:` → `flatpak update {{args}}`
  - `upgrade *args:` → `rpm-ostree upgrade {{args}}` + `@echo "Reboot to apply the staged deployment."`
  - `rollback *args:` → `rpm-ostree rollback {{args}}` + `@echo "Reboot to apply."`
  - `status *args:` → `rpm-ostree status {{args}}`
  - `cleanup *args:` → `rpm-ostree cleanup {{ if args == "" { "-prm" } else { args } }}` (verify the inline-`if` parses on the bundled `just` in the first build; if not, fall back to a recipe-local `--shell-cmd` workaround — see FOX-13)
  - `changelog *args:` → `rpm-ostree db diff {{args}}`
  - Trailing line: `mod home`
- **Where**: `os/modules/fox/src/recipes/silverfox.justfile`
- **Depends on**: T01
- **Reuses**: nothing (greenfield; no inherited recipe shape carried from `60-custom.just`)
- **Done when**: `just --justfile recipes/silverfox.justfile --list` enumerates 9 recipes (8 top-level + `home::factory-reset`); each body verified by tracing in T13's test.
- **Traceability**: FOX-06, FOX-07, FOX-09 … FOX-14, FOX-17 (`recipes/silverfox.justfile`)
- **Gate**: `just --justfile os/modules/fox/src/recipes/silverfox.justfile --evaluate` (parses without invocation)
- **Status**: pending

### T04 — `recipes/home.just`

- **What**: Write the `home` module Justfile. Single recipe:
  ```just
  # Hard reset $HOME from /etc/skel (silverfox-managed paths only)
  factory-reset *args:
      /usr/libexec/silverfox/home-factory-reset.sh {{args}}
  ```
- **Where**: `os/modules/fox/src/recipes/home.just`
- **Depends on**: T01
- **Reuses**: nothing
- **Done when**: `just --justfile recipes/silverfox.justfile --list home` shows `factory-reset *args` after T03 + this land.
- **Traceability**: FOX-17 (`recipes/home.just`), FOX-31
- **Gate**: as T03
- **Status**: pending

### T05 — `libexec/home-factory-reset.sh` [P with T06]

- **What**: Bash script (~40 lines). Shebang `#!/usr/bin/env bash`, `set -euo pipefail`. Implements FOX-08 + FOX-32 exactly:
  - reads `SKEL_DIR` (default `/etc/skel`) and `HOME` from env
  - parses argv via a `for arg in "$@"` loop — `--yes` / `-y` anywhere sets `yes=1`; any other arg → `printf 'error: unknown flag: %s\n' "$arg" >&2; exit 1`
  - enumerates scope paths at depth ≤ 2 under `$SKEL_DIR` into a bash array:
    ```
    while IFS= read -r -d '' top; do … done < <(find "$SKEL_DIR" -mindepth 1 -maxdepth 1 -print0)
    ```
    then for each top-level entry that's a directory and not skipped (no skip list in v1 — every `/etc/skel/*` is in scope), descend one more level the same way.
  - TTY check: `if [[ ${yes:-0} -eq 0 && ! -t 0 ]]; then echo 'error: no TTY available — use --yes for non-interactive' >&2; exit 1; fi`
  - prompt (interactive only): `read -r -p "Apply factory reset to $HOME from $SKEL_DIR (${#paths[@]} entries affected). [y/N] " ans`; accept `y|Y|yes|YES`; else `echo Cancelled.; exit 0`
  - apply loop: `rm -rf "$HOME/$p"; mkdir -p "$(dirname "$HOME/$p")"; cp -a "$SKEL_DIR/$p" "$HOME/$p"`
  - final `echo "Reset ${#paths[@]} entries from $SKEL_DIR."`
- **Where**: `os/modules/fox/src/libexec/home-factory-reset.sh`
- **Depends on**: T01
- **Reuses**: nothing
- **Done when**: `bash -n` + `shellcheck` clean; tmpfs smoke-run (manual: `SKEL_DIR=/tmp/skel-fixture HOME=/tmp/home-fixture bash libexec/home-factory-reset.sh --yes`) succeeds against a populated fixture.
- **Traceability**: FOX-08, FOX-17 (`libexec/home-factory-reset.sh`), FOX-32
- **Gate**: `shellcheck os/modules/fox/src/libexec/home-factory-reset.sh`
- **Status**: pending

### T06 — `libexec/chsh.sh` [P with T05]

- **What**: Bash script (~25 lines). Shebang `#!/usr/bin/env bash`, `set -euo pipefail`. Implements FOX-06:
  - allowlist: `bash`, `zsh`
  - arg 1 unset / empty → if `command -v tv` then `target=$(printf 'bash\nzsh\n' | tv --no-preview --height 30%%)`; else `read -r -p 'Switch login shell to (bash/zsh): ' target`
  - validate `target` is in the allowlist; else `printf 'Unknown shell: %s (try: bash, zsh)\n' "$target" >&2; exit 1`
  - resolve current shell: `current=$(getent passwd "$USER" | cut -d: -f7)`; if `current == "/usr/bin/$target"` → `echo "Already on $target."; exit 0`
  - else `sudo usermod -s "/usr/bin/$target" "$USER"`
  - final `echo "Done. Log out and back in, or 'exec $target -l' to swap now."`
- **Where**: `os/modules/fox/src/libexec/chsh.sh`
- **Depends on**: T01
- **Reuses**: shape (allowlist + usermod-not-chsh) from the retiring `os/modules/shell-ux/src/usr/share/ublue-os/just/60-custom.just` chsh recipe
- **Done when**: `bash -n` + `shellcheck` clean; tracing run with fake `sudo` confirms allowlist + already-on detection + tv-fallback (`PATH=/tmp/empty-bin:$PATH` to hide tv).
- **Traceability**: FOX-06, FOX-17 (`libexec/chsh.sh`), D-07, D-12
- **Gate**: `shellcheck os/modules/fox/src/libexec/chsh.sh`
- **Status**: pending

### T07 — `man/silverfox.md` (pandoc source)

- **What**: Pandoc Markdown source for the section-7 manpage. Sections per FOX-47:
  - `% silverfox(7) | Silverfox OS` title block
  - `# NAME` — `silverfox — operator CLI + environment overview`
  - `# SYNOPSIS` — `fox [verb] [args]`, `man 7 silverfox`
  - `# COMMANDS` — one bullet per verb (`fox` itself, `chsh`, `cheatsheet`, `home factory-reset`, `update`, `upgrade`, `rollback`, `status`, `cleanup`, `changelog`)
  - `# ENVIRONMENT`
    - **Editor**: `EDITOR=zed --wait`, `VISUAL=zed --wait`; vim_mode + helix_normal default_mode (no hx/code split)
    - **Navigation**: zoxide `z`/`zi`, Ctrl+P fzf quick-open, Ctrl+R atuin, Ctrl+T fzf file, Alt+C fzf cd, Alt+S sudo toggle, Ctrl+G fzf git-branch
    - **Containers**: rootless podman, `docker` shim, podman-compose
    - **Runtime versions**: mise (user toolchain in `~/.config/mise/config.toml`)
    - **Drop-in replacements**: `ls→eza`, `cat→bat`, `grep→rg` (aliases gated by AI-agent guard)
    - **Shells**: bash + zsh (no fish, no nu)
  - `# SEE ALSO` — `fox(1)` (placeholder for future v1.1), `just(1)`, `rpm-ostree(1)`, `flatpak(1)`, `man-pages(7)`
- **Where**: `os/modules/fox/src/man/silverfox.md`
- **Depends on**: T01
- **Reuses**: cheatsheet content from the retiring `60-custom.just`'s `tools` recipe (translate from libformatting.sh markup to pandoc Markdown)
- **Done when**: `pandoc -s -t man src/man/silverfox.md -o /tmp/silverfox.7` produces a valid manpage; `man -l /tmp/silverfox.7` renders.
- **Traceability**: FOX-17 (`man/silverfox.md`), FOX-47, D-14
- **Gate**: `pandoc -s -t man os/modules/fox/src/man/silverfox.md -o /tmp/silverfox.7` exit 0
- **Status**: pending

### T08 — `tests/{lib,fox,factory-reset}.test.sh` [P with T05, T06]

- **What**: Three files:
  - `tests/lib.sh` — shared helpers: `mktmpdir`, `mk_fake_just <output_dir>` (creates `bin/just` stub printing argv to stderr, exiting with `${FAKE_JUST_EXIT:-0}`), `assert_eq actual expected`, `run_with_pty <input> -- <cmd…>` (wraps `script -qc` for FOX-44's prompt cases).
  - `tests/fox.test.sh` — exercises `bin/fox` with fake-just on PATH + fixture `/etc/os-release`. Tests FOX-43's assertion list (version parse, `--list` default, verb passthrough, `home <sub>` transform, `home` (no sub) → `--list home`, unknown-verb passthrough + exit-code propagation).
  - `tests/factory-reset.test.sh` — exercises `libexec/home-factory-reset.sh` with `SKEL_DIR=/tmp/skel-…` + `HOME=/tmp/home-…` fixtures. Tests FOX-44's assertion list (PTY y/n, `--yes` short-circuit, non-TTY denial, user-file removal, non-silverfox-path preservation, unknown-flag refusal).
  - Each `.test.sh` ends with a summary tally and exits non-zero on any failure (no test framework — plain bash + `assert_eq`).
- **Where**: `os/modules/fox/src/tests/{lib.sh,fox.test.sh,factory-reset.test.sh}`
- **Depends on**: T02, T05, T06 (needs the artifacts under test)
- **Reuses**: nothing (no existing bash test harness in the repo)
- **Done when**: `bash os/modules/fox/src/tests/fox.test.sh && bash os/modules/fox/src/tests/factory-reset.test.sh` exits 0 locally.
- **Traceability**: FOX-17 (`tests/*`), FOX-43, FOX-44
- **Gate**: `shellcheck os/modules/fox/src/tests/*.sh` + run them
- **Status**: pending

### T09 — `rpm/silverfox-fox.spec`

- **What**: RPM spec wiring per FOX-16. Key sections:
  - `Name: silverfox-fox`, `Version: %{?_silverfox_version}%{!?_silverfox_version:0.0.0}`, `Release: 1%{?dist}`, `BuildArch: noarch`
  - `Source0:` — same synthesized empty-tarball pattern other spec files use (verify the pattern is wired in `os/lib/build-rpms.sh`; if missing, T11 lands the convention)
  - `Requires:` `just`, `bash >= 4`, `coreutils`, `findutils`, `gawk`, `man-db`, `rpm-ostree`, `flatpak`, `sudo`, `shadow-utils`
  - `%install` — six `install -D` lines per FOX-16
  - `%files` — six paths (binary, manpage, 2 just files, 2 libexec scripts)
- **Where**: `os/modules/fox/rpm/silverfox-fox.spec`
- **Depends on**: T02, T03, T04, T05, T06, T07
- **Reuses**: synthesized-tarball Source0 pattern from existing silverfox spec files (verify against `os/modules/dotfiles/rpm/silverfox-stow-defaults.spec` — same `BuildArch: noarch`, `Source0: %{name}-%{version}.tar.gz`)
- **Done when**: spec file lints (`rpmlint` not required by CI, but spec is syntactically valid); the spec lives in `rpm/silverfox-fox.spec` so `build-rpms.sh` will pick it up at full-image-build time.
- **Traceability**: FOX-16, FOX-22 (rpm path), D-04
- **Gate**: full `just build` (deferred until Phase 3 T14 lands the Containerfile bridge)
- **Status**: pending

---

## Phase 2 — `os/modules/home/` new module

### T10 — `home/` module skeleton + stow content + symlinks

- **What**: Create `os/modules/home/src/etc/skel/.config/silverfox/stow/{bash,zsh,mise,ghostty,zed}/` with content migrated from `os/modules/dotfiles/src/usr/share/silverfox/stow/`. Specifically:
  - copy `bash/.bashrc` and `zsh/.zshrc` verbatim (185 + 175 lines respectively; the AI-agent guard, starship/atuin/zoxide/mise/fzf wiring, Ctrl+P / Alt+S / Ctrl+G keybinds, eza/bat aliases). Both reference `zed --wait` already.
  - copy `mise/.config/mise/config.toml` **minus the JVM block** (the file already has the JVM lines stripped — keep current 9-toolchain layout: node, bun, pnpm, python, uv, go, rust, zig, act)
  - copy `ghostty/.config/ghostty/config` verbatim
  - copy `zed/.config/zed/settings.json` verbatim
  - create five relative symlinks at `/etc/skel/.bashrc`, `/etc/skel/.zshrc`, `/etc/skel/.config/mise/config.toml`, `/etc/skel/.config/ghostty/config`, `/etc/skel/.config/zed/settings.json`, each pointing into the stow tree (`../.config/silverfox/stow/bash/.bashrc` etc.). Use `git add` with full preservation of symlink mode (`git ls-files -s` shows `120000` for symlinks).
- **Where**: `os/modules/home/src/etc/skel/`
- **Depends on**: nothing (parallel to Phase 1)
- **Reuses**: existing `os/modules/dotfiles/src/usr/share/silverfox/stow/*` content verbatim except mise (JVM already absent)
- **Done when**: `find os/modules/home/src/etc/skel -type l -or -type f | wc -l` shows 9 entries (4 stow source files + 5 symlinks); `readlink` on each symlink resolves to a path containing `silverfox/stow/`.
- **Traceability**: FOX-21, FOX-25, FOX-26, FOX-27, FOX-28, FOX-28b, FOX-29, D-11
- **Gate**: none (data files) — verify at T26's full-build pass
- **Status**: pending

### T11 — `rpm/silverfox-home.spec`

- **What**: New spec at `os/modules/home/rpm/silverfox-home.spec`. Owns all `/etc/skel/...` paths from T10. `BuildArch: noarch`, empty `Requires:` (stow stays in `silverfox-cli-tools`). `%description` notes: "Ships user-domain defaults via /etc/skel; useradd seeds them once; users own them thereafter; `fox home factory-reset` reseeds." `%files` enumerates all 9 paths + `%dir` entries for `/etc/skel/.config/silverfox`, `/etc/skel/.config/silverfox/stow`, and each `/etc/skel/.config/silverfox/stow/<pkg>/` package. Symlinks declared as plain `%files` entries (rpm preserves symlink-type from buildroot; verify in first build per Open Concern in context.md).
- **Where**: `os/modules/home/rpm/silverfox-home.spec`
- **Depends on**: T10
- **Reuses**: spec shape from `os/modules/dotfiles/rpm/silverfox-stow-defaults.spec` (same `%setup -q` + `cp -a etc %{buildroot}/` style)
- **Done when**: spec file lints syntactically; `build-rpms.sh` will pick it up via the `os/modules/home/rpm/*.spec` glob.
- **Traceability**: FOX-21, FOX-30, D-15
- **Gate**: `just build` (deferred to T26)
- **Status**: pending

---

## Phase 3 — Build pipeline wiring

### T12 — Containerfile: `man-build` stage + `/var/tmp/fox-prebuilt/` bridge

- **What**: Edit `os/Containerfile`:
  - Above the final stage, insert `FROM registry.fedoraproject.org/fedora-minimal:44 AS man-build` running `microdnf install -y pandoc gzip && mkdir -p /out && pandoc -s -t man /workspace/silverfox.md -o /out/silverfox.7 && gzip -9 /out/silverfox.7`, with the `man/silverfox.md` source `COPY`d from `os/modules/fox/src/man/silverfox.md` to `/workspace/`.
  - In Layer 2 (before `build-rpms.sh` runs), add the four `COPY` lines: `--from=man-build /out/silverfox.7.gz`, plus direct `COPY` of `os/modules/fox/src/{bin,recipes,libexec}` into `/var/tmp/fox-prebuilt/{bin,recipes,libexec}/`. Wire via `--mount=type=bind,from=ctx,…` (the existing pattern) so the COPY targets `/ctx/modules/fox/src/...` — re-stage in `ctx` if needed.
  - Append `rm -rf /var/tmp/fox-prebuilt` to the same Layer 2 RUN after `rm -rf /tmp/rpmbuild`.
- **Where**: `os/Containerfile`
- **Depends on**: T07 (pandoc source must exist for the new stage), T02..T06 (bridge targets), T09 (spec consumes the bridge)
- **Reuses**: existing `ctx` and `ctx-packages` stage pattern; existing `--mount=type=bind,from=ctx` recipe
- **Done when**: `just build` succeeds with `bootc container lint` exit 0; image contains `/usr/bin/fox`, `/usr/share/man/man7/silverfox.7.gz`, both Justfiles, both libexec scripts.
- **Traceability**: FOX-15, FOX-16, D-03
- **Gate**: `just build` (full pipeline)
- **Status**: pending

### T13 — Build-side `Justfile`: fox-test / fox-lint / fox-gen-man

- **What**: Edit repo-root `Justfile`:
  - Add `fox-test:` recipe running `bash os/modules/fox/src/tests/fox.test.sh && bash os/modules/fox/src/tests/factory-reset.test.sh`
  - Add `fox-lint:` recipe running `bash -n` (syntax) + `shellcheck` on `os/modules/fox/src/bin/fox`, `os/modules/fox/src/libexec/*.sh`, `os/modules/fox/src/tests/*.sh`
  - Extend `lint:` recipe to chain `just fox-lint` after the existing `shellcheck os/lib/*.sh os/modules/*/*.sh`
  - Add `fox-gen-man:` (dev convenience) running `pandoc -s -t man os/modules/fox/src/man/silverfox.md -o /tmp/silverfox.7`
  - Swap any `ujust`-using dev recipes to `fox` equivalents (per FOX-41). Quick grep of current `Justfile` shows none — verify.
- **Where**: `Justfile` (repo root)
- **Depends on**: T02, T05, T06, T07, T08 (the artifacts these recipes target)
- **Reuses**: existing `lint:` recipe shape
- **Done when**: `just fox-lint && just fox-test` exits 0; `just lint` includes the fox subset.
- **Traceability**: FOX-19, FOX-41 (Justfile part)
- **Gate**: `just fox-lint && just fox-test && just lint` exit 0
- **Status**: pending

### T14 — CI pre-flight: `.github/workflows/build.yml`

- **What**: Add a `fox-preflight` job above the existing image-build matrix:
  - `runs-on: ubuntu-latest`
  - install just (`apt install just` or `cargo install just` — verify which is shorter on stock Ubuntu 24.04)
  - install shellcheck (`apt install -y shellcheck`)
  - checkout
  - `just fox-lint && just fox-test`
  - declare the image-build matrix `needs: fox-preflight` so a red pre-flight short-circuits the heavy job.
- **Where**: `.github/workflows/build.yml`
- **Depends on**: T13
- **Reuses**: existing matrix-job structure
- **Done when**: `gh workflow run build.yml` (or PR push) shows `fox-preflight` as a gating job ahead of `build`.
- **Traceability**: FOX-20, D-08
- **Gate**: green CI on the PR landing this task
- **Status**: pending

---

## Phase 4 — Retirement / narrowing (cli-tools, dotfiles, shell-ux)

### T15 — `cli-tools`: drop `rclone`/`fuse3`, add `tv`

- **What**: Edit `os/modules/cli-tools/packages.txt` (drop `rclone`, `fuse3`; add `tv` — verify it's in the Terra repo by `dnf repoquery --repo=terra44 tv` against a built layer, or follow context.md Open Concern: if `tv` isn't in Terra, fall back to a fetch-the-binary script in this same task or drop `tv` and rely on chsh.sh's `read -p` fallback only). Edit `os/modules/cli-tools/rpm/silverfox-cli-tools.spec`: drop `Requires: rclone` + `Requires: fuse3`; add `Requires: tv` (or none if the binary-fetch fallback wins). Update `%description` accordingly. Add a changelog entry.
- **Where**: `os/modules/cli-tools/packages.txt`, `os/modules/cli-tools/rpm/silverfox-cli-tools.spec`
- **Depends on**: nothing (parallel to Phase 1–2)
- **Reuses**: existing packages.txt comment style
- **Done when**: `rpm -q rclone fuse3` reports "not installed" in the built image; `rpm -q tv` either installed (Terra path) or N/A (binary-fetch path).
- **Traceability**: FOX-35, FOX-38, D-07, D-13
- **Gate**: `just build` (image must still build with the new package set)
- **Status**: pending

### T16 — Retire `os/modules/dotfiles/` entirely

- **What**: `git rm -r os/modules/dotfiles/`. After this, `build-rpms.sh` no longer finds `silverfox-stow-defaults.spec` (the orchestrator walks `os/modules/*/rpm/`). The retired RPM disappears from the image; existing user homes are unaffected (image-build-only stow-symlinks are already on a read-only ostree path that the new image won't ship).
- **Where**: `os/modules/dotfiles/` (deleted)
- **Depends on**: T10 (the content has been migrated to `os/modules/home/src/etc/skel/`)
- **Reuses**: nothing
- **Done when**: directory gone; `find os/modules -name 'silverfox-stow-defaults.spec'` returns nothing; `just build` succeeds without the retired sub-package.
- **Traceability**: FOX-24, FOX-37, D-10
- **Gate**: `just build`
- **Status**: pending

### T17 — Narrow `os/modules/shell-ux/`

- **What**: Edit shell-ux in place:
  - **Delete files**:
    - `os/modules/shell-ux/src/etc/zshrc` (silverfox's customized one; stock Fedora `/etc/zshrc` from the `zsh` RPM reclaims the path — see context.md Open Concern about `%ghost` workaround if the upgrade balks)
    - `os/modules/shell-ux/src/usr/lib/systemd/user/rclone-gdrive.service` (gdrive integration retired per FOX-34)
    - `os/modules/shell-ux/src/usr/share/ublue-os/just/60-custom.just` (ujust slot retired per FOX-39)
  - **Rewrite**: `os/modules/shell-ux/src/etc/user-motd` per FOX-40 / FOX-46 — every `ujust <recipe>` row → `fox <recipe>`; `tools` row → `man silverfox` (with `fox cheatsheet` as alias); add `fox home factory-reset` row; drop `gdrive-setup`, `apply-defaults` rows.
  - **Keep**: `etc/mise/config.toml`, `etc/profile.d/silverfox-shell-migrate.sh` (verify the migrate.sh allowlist points to `/usr/bin/zsh` only — patch if it ever referenced fish or nu).
  - Edit `os/modules/shell-ux/rpm/silverfox-shell-ux.spec` `%files`: drop `/etc/zshrc`, `/usr/share/ublue-os/just/60-custom.just`, `/usr/lib/systemd/user/rclone-gdrive.service`. Rewrite `%description` for narrowed scope. Add changelog entry.
- **Where**: `os/modules/shell-ux/` (multiple files)
- **Depends on**: nothing (parallel to Phase 1–2); coordinated with T12 (the new motd refers to `fox`, but motd is data — no build-time check)
- **Reuses**: existing user-motd banner layout (the box-drawing line + body)
- **Done when**: shell-ux ships only `/etc/user-motd`, `/etc/mise/config.toml`, `/etc/profile.d/silverfox-shell-migrate.sh`; `rpm -ql silverfox-shell-ux` lists exactly those three paths in the built image.
- **Traceability**: FOX-23, FOX-34, FOX-39, FOX-40, FOX-46, D-13
- **Gate**: `just lint` (silverfox-shell-migrate.sh is shell) + `just build`
- **Status**: pending

---

## Phase 5 — Documentation + housekeeping

### T18 — Update `README.md`

- **What**: Rewrite affected sections:
  - **Set up dotfiles** (currently L126–163): replace stow-on-first-login narrative with `/etc/skel` + useradd seeding + user-domain real files; reference `fox home factory-reset` for image-defaults revert; note custom stow packages live OUTSIDE `~/.config/silverfox/` (`~/.config/dotfiles/` recommended layout); git-track for selective rollback.
  - **What's in the image** table row (L67): edit "User dotfiles" to describe the new useradd-seeded flow.
  - **CLI toolset** table (L171): drop `rclone`, `fuse3` from the Fedora-44-main column.
  - **Repo layout** tree (L83-84): update `dotfiles/`/`shell-ux/` descriptions; add `home/` and `fox/` rows.
  - **Iterating on dotfiles** (L180): point to edit-in-`~/.config/silverfox/stow/` + custom-stow-outside-silverfox note.
  - **Rollback** section (L191): swap `rpm-ostree rollback` invocation references to `fox rollback` (image-side usage) but keep direct `rpm-ostree` commands for ssh/recovery contexts.
  - **Quick start** (L48): drop "VS Code" claim (zed is now the editor); update post-rebase wiring summary.
- **Where**: `README.md`
- **Depends on**: T10, T11, T15, T16, T17 (the files/paths the README describes must exist in their new form)
- **Reuses**: existing README section headers
- **Done when**: `grep -E '\b(ujust|chezmoi|gdrive|rclone)\b' README.md` returns zero matches (except in historical "Considered, dropped" prose, if any).
- **Traceability**: FOX-33, FOX-36 (README part), FOX-41 (README part)
- **Gate**: none (text-only)
- **Status**: pending

### T19 — Update `.specs/project/STATE.md` + `ROADMAP.md`

- **What**: Edit STATE.md:
  - "Current focus" → fox feature in-flight (T-prefixed task list in `.specs/features/fox/tasks.md`); previous "no feature in flight" line retired.
  - "Dotfile seeding (2026-05-10 — chezmoi → GNU stow)" → add follow-up note "2026-05-11 — stow seeding → /etc/skel user-domain via fox feature; silverfox-stow-defaults retired; silverfox-home + silverfox-fox introduced."
  - "Shells (2026-05-02)" → three-shell entry → two-shell (bash + zsh); drop fish-related notes; note `fox chsh` replaces `ujust chsh`.
  - "ujust extension slot (2026-05-02)" → entire section moves to historical; replaced by "Operator CLI (2026-05-11) — `/usr/bin/fox` thin bash dispatcher around `just -f /usr/share/silverfox/silverfox.justfile`; recipes ship in `silverfox-fox` RPM; manpage at `man 7 silverfox` rendered via pandoc."
  - "Editor split (2026-05-02)" → already updated to zed in a prior commit; verify still accurate.
  - Add "Module layout" note: 8 modules (was 7) — +home, +fox, -dotfiles; `shell-ux` narrowed.
  - "Lessons" → append a fox-specific note about bash-pivot reasoning (D-02 reversal — 20 lines of dispatch doesn't earn a 50MB compile runtime).
  Edit ROADMAP.md:
  - "Current" → fox in flight.
  - "Previous (shipped)" → add fox once T26 passes (deferred entry; this task only seeds the in-flight state).
  - "Backlog" → add `fox-home-sync` (v2) entry: declarative TOML manifests at `~/.config/silverfox/manifests/*.toml`, backend drivers for flatpaks/dconf/systemd-user, substrate (bash+jq vs Bun TS vs Rust) and reconciliation contract designed at v2 time with a real backend in hand. Link to context.md D-16 + D-17.
- **Where**: `.specs/project/{STATE.md,ROADMAP.md}`
- **Depends on**: nothing (independent text)
- **Reuses**: existing STATE/ROADMAP section structure
- **Done when**: both files reference fox feature in "Current"; `fox-home-sync` queued in ROADMAP backlog.
- **Traceability**: FOX-33, success criterion 12
- **Gate**: none
- **Status**: pending

### T20 — Scrub gdrive/rclone/ujust refs from `%description` blocks + scripts

- **What**: Single sweep across `os/modules/*/rpm/*.spec` `%description` blocks and any remaining `*.sh` files in `os/modules/*/`:
  - `grep -rn 'ujust\|gdrive\|rclone-gdrive\|libformatting\.sh\|ugum\|Urllink' os/modules/*/rpm/*.spec os/modules/*/*.sh` → drop or rephrase each match. `%changelog` blocks LEFT INTACT (historical record).
  - The retiring `60-custom.just` (already deleted in T17) accounted for most of the surface; what remains is `%description` prose.
- **Where**: across `os/modules/`
- **Depends on**: T15, T17 (the actual deletions happen first; this task only mops up text)
- **Reuses**: nothing
- **Done when**: success-criterion grep returns zero matches outside `%changelog`.
- **Traceability**: FOX-36 (`%description` portion), FOX-42
- **Gate**: `just lint` (catches if a `*.sh` shellcheck regresses) + the grep verification
- **Status**: pending

---

## Phase 6 — End-to-end verification

### T21 — Full build + lint pass

- **What**:
  - `just lint` (includes `fox-lint` after T13)
  - `just fox-test`
  - `just build` (full image build + `bootc container lint`)
  - Spot-check the image: `podman run --rm localhost/silverfox:dev rpm -ql silverfox-fox` (6 paths), `rpm -ql silverfox-home` (9 paths), `rpm -q silverfox-stow-defaults` (not installed), `rpm -q rclone fuse3 fish` (none installed), `rpm -q just stow tv` (all installed unless tv path took the binary-fetch fallback in T15).
  - Verify the manpage: `podman run --rm localhost/silverfox:dev man 7 silverfox` renders.
  - Verify the dispatcher: `podman run --rm localhost/silverfox:dev fox --version` prints `VERSION_ID`, `podman run --rm localhost/silverfox:dev fox` lists 9 recipes.
- **Where**: shell on the dev host
- **Depends on**: ALL prior tasks
- **Reuses**: existing verification commands from `.specs/codebase/TESTING.md` ("Quick gate" + "Full gate")
- **Done when**: all spot checks pass; nothing in TESTING.md's "Manual verification (VM / rebase)" list regresses for the items still in scope.
- **Traceability**: success criteria 1, 2, 4, 5, 6, 7, 9, 10, 11, 13 from spec.md; FOX-15, FOX-20 (gate part)
- **Gate**: the gate IS this task
- **Status**: pending

---

## Execution order summary

```
T01 ─┬─→ T02 ──┐
     ├─→ T03 ─┤
     ├─→ T04 ─┤
     ├─→ T05 ─┤
     ├─→ T06 ─┤            ┌─→ T13 ─→ T14
     ├─→ T07 ─┼─→ T08 ─────┤
     └─→ T09 ─┘            │
                           │
T10 ─→ T11 ────────────────┤
                           │
T15 ───────────────────────┤
                           │
T10 ─→ T16 ────────────────┤
T17 ───────────────────────┼─→ T12 ─→ T18 ─→ T19 ─→ T20 ─→ T21
                           │
(T18..T20 also depend on T10..T17 for accurate paths/refs)
```

Parallelizable batches:
- **Batch A** (after T01): T02, T03, T04, T05, T06, T07 — six independent files
- **Batch B** (independent, anytime): T10, T15, T17
- **Batch C** (after content lands): T18, T19, T20

## Risks / open per-task concerns

(Surfaced from spec.md "Open implementation concerns" — verify in the
first PR landing each task.)

| Concern | First-PR check | Task it shows up in |
|---|---|---|
| `just`'s inline-`if` parses on the bundled version | Manual `just --evaluate` against the bundled `just` binary | T03 (FOX-13) |
| `Source0:` empty-tarball pattern wired in `build-rpms.sh` | Read `os/lib/build-rpms.sh`; if absent, add the synth in T09's commit | T09 (FOX-16) |
| `tv` in Terra repo | `dnf repoquery --repo=terra44 tv` against a layer; pick path (RPM vs binary vs drop) before changelog | T15 (D-07) |
| Symlink preservation through rpmbuild | Build + `ls -la /etc/skel/.bashrc` in the resulting image | T11 (FOX-29) |
| `/etc/zshrc` reclaim — `%ghost` workaround needed? | Build + rebase a test VM; if upgrade balks, ship `%ghost /etc/zshrc` in shell-ux for one release | T17 (FOX-23) |
| `bash` SIGINT/SIGTERM propagation through fox→just→man | Manual `fox cheatsheet` + Ctrl-C during the man pager | T21 (D-18) |
