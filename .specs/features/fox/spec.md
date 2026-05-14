# fox Specification

## Problem Statement

Silverfox's operator interface today is `ujust` (provided by uBlue's `ublue-os-just`, inherited from `silverblue-main:44`). Five silverfox recipes live in `os/modules/shell-ux/src/usr/share/ublue-os/just/60-custom.just` — `chsh`, `apply-defaults`, `tools`, `gdrive-setup`, `gdrive-remove` (the gdrive pair retires with this feature) — plus the inherited `update`. Recipes depend on `ujust` runtime, `/usr/lib/ujust/libformatting.sh`, `ugum`, and `Urllink` — all owned upstream. The image also ships implicit-injection: `/etc/profile.d/silverfox-stow-defaults.sh` runs `stow` over `/usr/share/silverfox/stow/*` on first login (marker-guarded); image-default dotfiles symlink `~/.bashrc` into read-only ostree paths under `/usr/share/silverfox/stow/`. Two layers of magic (ujust + ostree-symlinked rcs via first-login stow) for a personal image used by one person. (The earlier `/etc/profile.d/silverfox-cli-init.sh` + zsh/fish variants from the chezmoi era are already gone; `silverfox-shell-migrate.sh` survives as a small rescue script for users whose login shell binary was removed by an upgrade.)

Three pressures push toward a silverfox-owned CLI alongside a broader user-config rethink:

1. **Roadmap independence from uBlue.** The deferred `post-ublue` feature will leave `silverblue-main:44` for a stock-Fedora atomic or `fedora-bootc` base. `ujust` and its dependency graph (`ublue-os-just`, `ugum`, `libformatting.sh`, the `/usr/share/ublue-os/justfile` import slot) all disappear with that swap. Replacing the recipe surface beforehand decouples the two migrations. Note: `just` (the upstream task runner from casey/just) is NOT a uBlue artifact — it's a standard standalone Rust binary in stock Fedora repos, retained as fox's dispatch backend.

2. **User-config model: implicit injection → user-domain.** The new model pushes all user-facing config to `/etc/skel`, shipped as a stow source tree at `/etc/skel/.config/silverfox/stow/{bash,zsh,mise,ghostty,zed}/` with pre-farmed symlinks at `/etc/skel/{.bashrc,.zshrc,.config/{mise/config.toml,ghostty/config,zed/settings.json}}` pointing into that tree. `useradd` (traditional Unix, cp-a semantics, preserves symlinks) copies everything into new users' homes. From that moment the dotfiles are user-domain: silverfox never modifies them. Image upgrades that change defaults affect only future-created users; existing users own their copy. The auto-loading `/etc/profile.d/silverfox-cli-init.sh` + zsh + fish variants are deleted (content moves into the `/etc/skel/.config/silverfox/stow/<shell>/.<shell>rc` files). Fish is dropped — silverfox ships exactly two shells now (bash + zsh).

3. **Declarative ambition for v2 — silverfox's home-manager.** `fox home` is the silverfox equivalent of nix's home-manager — declarative user-level config — without the nix substrate. `nix-home` (retired 2026-05-01) failed on Fedora atomic 42+ due to composefs/SELinux/post-upgrade frictions. The home-manager UX (manifest → reconciliation) is recoverable without the nix ecosystem and will land in **v2**: TOML manifests under `~/.config/silverfox/manifests/`, backend-specific drivers (flatpak CLI, dconf, systemctl --user), orchestrated by `fox home sync`. **v1 ships only `fox home factory-reset`** — an imperative hard wipe + reseed of the silverfox-managed subtree of `$HOME` from `/etc/skel/`. The counterpart to home-manager's "revert to defaults", and a foothold in the `home` namespace ahead of v2. Generations / native rollback are NOT replicated: users git-track `~/.config/silverfox/` for history; rollback is `git checkout` + `fox home factory-reset`. The `SyncCommand<T>` contract for v2 reconciliation is **deferred** — designing it without a real backend (flatpak/dconf/systemd-user) risks getting the type shape wrong. Substrate choice for v2 (bash + jq, Bun TS, Rust, etc.) is also deferred to v2 time.

`fox` is a **tiny bash dispatcher** at `/usr/bin/fox` (~20 lines, <1KB). Its sole job is argv routing into a silverfox-owned Justfile (`exec just -f /usr/share/silverfox/silverfox.justfile <verb> <args>`) with one transform: `fox home <sub>` → `just home::<sub>` (just module syntax). Verbs map 1:1 to recipes. Non-trivial logic (factory-reset skel walk; chsh tv-picker + usermod) lives in libexec bash scripts that recipes invoke. Simple verbs (update, upgrade, rollback, status, cleanup, cheatsheet, changelog) are one-line recipes wrapping `flatpak`/`rpm-ostree`/`man` directly. Result: v1 has essentially no compiled surface — bash + just recipes + bash scripts — under 200 lines of bash total across the whole feature.

The 9 v1 verbs: `chsh`, `cheatsheet`, `home factory-reset`, `update`, `upgrade`, `rollback`, `status`, `cleanup`, `changelog`. The gdrive integration (`rclone-gdrive.service`, `rclone`, `fuse3`) retires entirely. The `tools` cheatsheet moves to a manpage at `/usr/share/man/man7/silverfox.7.gz`.

Module reorganization accompanies the CLI introduction:

- **`shell-ux/`** narrows to *system-level* shell concerns: `/etc/user-motd` + `/etc/mise/config.toml`. RPM name `silverfox-shell-ux` stays (per stable-RPM-name policy).
- **`home/`** is new: ships `/etc/skel/.config/silverfox/stow/*` + the pre-farmed symlinks at `/etc/skel/*`. RPM: new `silverfox-home`. (The retired `silverfox-stow-defaults` is dropped, not renamed.)
- **`fox/`** is new: bash dispatcher, manpage source, Justfile + module Justfile, libexec bash scripts, **plus `rpm/silverfox-fox.spec`**. Bash + Justfiles + libexec scripts COPY'd directly from build context; manpage rendered in a tiny `man-build` stage (`fedora-minimal:44` + `pandoc`) and bridged via `COPY --from`. All artifacts land in `/var/tmp/fox-prebuilt/` then `silverfox-fox.spec`'s `%install` lays them down. `rpm -qf /usr/bin/fox` returns `silverfox-fox`.
- **`dotfiles/`** retires entirely.

Build is multi-stage Containerfile, but radically simpler than the prior Bun-based design: `fedora-minimal:44 AS man-build` runs `pandoc -s -t man src/man/silverfox.md -o /out/silverfox.7 && gzip -9 /out/silverfox.7`; final stage `COPY --from=man-build /out/silverfox.7.gz /var/tmp/fox-prebuilt/`, plus direct `COPY os/modules/fox/src/{bin,recipes,libexec} /var/tmp/fox-prebuilt/` from the build context.

Result: silverfox-owned operator CLI; dotfiles as user-domain real files seeded once via `/etc/skel`; zero `ujust`/uBlue-tooling dependency from silverfox (plain `just` remains, as a stock Fedora tool); module structure aligned with the new conceptual split (system-level vs user-domain); foundation laid for home-manager-style declarative v2 via `fox home sync` (substrate + contract designed at v2 time, with a real backend in hand).

## Goals

- [ ] `/usr/bin/fox` (bash dispatcher, ~20 lines) ships in both `silverfox` and `silverfox-nvidia` images, executable on rebase with no further setup
- [ ] 9 commands work: `chsh`, `cheatsheet`, `home factory-reset`, `update`, `upgrade`, `rollback`, `status`, `cleanup`, `changelog`
- [ ] `fox` (no args) and `fox --help` print the recipe list via `just --list`; `fox --version` prints the image version; `fox home` (no sub) prints the home module's recipe list via `just --list home`
- [ ] `/usr/share/silverfox/silverfox.justfile` + `/usr/share/silverfox/home.just` ship, owned by `silverfox-fox` RPM
- [ ] `/usr/libexec/silverfox/home-factory-reset.sh` + `/usr/libexec/silverfox/chsh.sh` ship as executable bash scripts, owned by `silverfox-fox` RPM; pass shellcheck
- [ ] `silverfox-fox.spec` declares `Requires: just` (fox's runtime dispatch dependency)
- [ ] `/etc/skel/.config/silverfox/stow/{bash,zsh,mise,ghostty,zed}/` ships full silverfox seed content; `/etc/skel/{.bashrc,.zshrc,.config/mise/config.toml,.config/ghostty/config,.config/zed/settings.json}` ship as relative symlinks into the stow tree
- [ ] New module `os/modules/home/` ships `silverfox-home.spec` owning all `/etc/skel/` paths above
- [ ] `os/modules/shell-ux/` narrowed: ships only `/etc/user-motd` + `/etc/mise/config.toml`; RPM name `silverfox-shell-ux` retained
- [ ] `os/modules/dotfiles/` deleted entirely; `silverfox-stow-defaults` RPM retired; `/etc/profile.d/silverfox-stow-defaults.sh` + marker logic deleted; `/usr/share/silverfox/stow/` removed from image
- [ ] `os/modules/fox/` new: bash dispatcher (`bin/fox`) + manpage source + recipes + libexec + `rpm/silverfox-fox.spec`; binary at `/usr/bin/fox`, manpage at `/usr/share/man/man7/silverfox.7.gz`, recipes at `/usr/share/silverfox/`, libexec at `/usr/libexec/silverfox/` — all owned by `silverfox-fox` RPM
- [ ] `/etc/profile.d/silverfox-cli-init.sh`, `/etc/zsh/silverfox-cli-init.zsh`, customized `/etc/zshrc`, `/etc/fish/conf.d/silverfox-cli-init.fish` all deleted; stock Fedora `/etc/zshrc` returns
- [ ] Fish removed entirely: not in `silverfox-cli-tools` Requires, not in `chsh.sh` allowlist, no `/etc/skel/.config/fish/`, no `os/modules/cli-tools/packages.txt` entry
- [ ] `chsh.sh` uses `read -p` prompt only (no `tv` — package not in Terra/Fedora-main as of 2026-05-11; D-07 resolved to drop the picker dep, fallback is universal). Shell-level fzf bindings untouched.
- [ ] `stow` stays in `silverfox-cli-tools` (user-side tool for managing custom dotfile dirs outside the silverfox-managed subtree)
- [ ] `rclone-gdrive.service`, `rclone`, `fuse3` deleted; `~/gdrive` no longer auto-mounted
- [ ] User mise config (now in `/etc/skel`) drops the JVM block (java/kotlin/gradle); 9 toolchain pins remain
- [ ] `os/modules/shell-ux/src/usr/share/ublue-os/just/60-custom.just` deleted; `/etc/user-motd`, `README.md`, `Justfile` (build-side) switch from `ujust` to `fox`
- [ ] `/usr/share/man/man7/silverfox.7.gz` ships (generated via pandoc in the `man-build` Containerfile stage); `man silverfox` and `fox cheatsheet` both work
- [ ] `shellcheck` (all bash) + bash integration tests run in CI pre-flight before image-build matrix; build gated on green
- [ ] STATE.md + ROADMAP.md updated; new `fox-home-sync` backlog entry queues v2 manifests under `~/.config/silverfox/manifests/` (substrate + contract design deferred to v2)

## Out of Scope

| Feature | Reason |
|---|---|
| Implementing `fox home sync` for flatpaks / dconf / systemd-user-units | v2 scope. The substrate (bash + jq vs Bun TS vs Rust) and the reconciliation contract are both designed at v2 time with a real backend in hand |
| Shipping any `~/.config/silverfox/manifests/` content or path in `/etc/skel` | v1 ships the stow tree only; manifests dir appears in v2 with the first sync backend |
| `--json` global flag / silverfox-level structured output | Deferred to v2. Recipes pass `--json` through to the underlying tools where the tool supports it (`fox status --json` → `rpm-ostree status --json`); no silverfox-level JSON wrapper in v1 |
| `/etc/silverfox/` reserved as system config root | Reservation retired — all declarative config lives in `~/.config/silverfox/` |
| Auto-propagating shell config updates to existing users on image upgrade | Dotfiles are user-domain after useradd. Existing users invoke `fox home factory-reset` to pick up new defaults; otherwise their copies stay |
| Generations / native rollback for home state | Users git-track `~/.config/silverfox/`; rollback is `git checkout` + `fox home factory-reset` |
| Per-file / per-package partial reset | `home factory-reset` is total. For finer rollback: git-track + `git checkout <path>`, or manual `cp -a /etc/skel/.config/silverfox/stow/<pkg>/ ~/.config/silverfox/stow/` |
| `--dry-run` / `--diff` flags on `home factory-reset` | Removed during design iteration: factory-reset is unconditional reseed; the prompt is the single safety. Diff of "everything from skel" was noise without enough signal |
| Compiled binary for `fox` (Bun, Rust, Go) | Reverted during design iteration (was Bun). With dispatch logic at ~20 lines, a 50MB compiled binary is pure overhead. v2 may reintroduce a compiled runtime when `fox home sync` needs real substrate |
| CLI framework / argument parser | Bash `case` statement on `$1` does the entire job; framework would add ceremony with no payoff |
| Replacing shell-level `fzf` with `tv` | `tv` enters cli-tools for the `chsh.sh` picker only |
| Migrating user data out of `~/gdrive` before unit removal | Personal image; user remounts manually if needed |
| Auto-completion (bash/zsh completions for `fox`) | Defer to v1.1 |
| Migrating off uBlue base image | Separate `post-ublue` feature |
| Cross-arch binaries (aarch64) | amd64-only per existing non-goal |
| Telemetry / usage reporting | Personal image |

## User Stories

### P1: `fox` dispatcher present ⭐ MVP

**Story**: After rebase to the fox-enabled image, the user runs `fox` and gets a list of available commands from `just --list`. `fox --version` reports the silverfox image version.

**Acceptance**:
1. **FOX-01** — `/usr/bin/fox` exists in both `silverfox` and `silverfox-nvidia` image variants, mode `0755`, identified by `file /usr/bin/fox` as a Bourne-Again shell script. ~20 lines, no compilation.
2. **FOX-02** — `fox` (no args) and `fox --help` / `-h` dispatch to `just -f /usr/share/silverfox/silverfox.justfile --list` and print the recipe list (9 recipes: 8 top-level + `home::factory-reset`). Exit 0.
3. **FOX-03** — `fox --version` / `-V` prints `VERSION_ID` from `/etc/os-release` (parsed via `awk -F= '/^VERSION_ID=/ {gsub(/"/,"",$2); print $2}'`). Path overridable via `SILVERFOX_OS_RELEASE` env var (default `/etc/os-release`) — used by tests to inject a fixture file without touching the host. No build-time substitution; runtime read. Exit 0.
4. **FOX-04** — Unknown verb is passed through to `just`; fox exits with `just`'s exit code and error (typically `error: Justfile does not contain recipe \`<name>\``, exit 1). No silverfox-level pre-validation.
5. **FOX-05** — `fox home <sub> [args]` is transformed to `just -f <justfile> home::<sub> [args]`. `fox home` (no sub) → `just -f <justfile> --list home`. All other verbs pass through unchanged: `fox <verb> [args]` → `just -f <justfile> <verb> [args]`.

**Test**: `file /usr/bin/fox` → "Bourne-Again shell script". `fox` prints the recipe list. `fox --version` matches `awk -F= '/^VERSION_ID=/...' /etc/os-release`. `fox xyzzy` exits 1 with just's "recipe not found". `fox home factory-reset --yes` correctly invokes `just home::factory-reset --yes` (asserted via `set -x` trace in test wrapper).

---

### P1: Lifecycle commands ⭐ MVP

**Story**: Each verb maps to one operation with no surprises. Output is streamed directly from the underlying tool (no silverfox-level reformatting in v1). **All recipes (except `chsh` and `cheatsheet`) declare `*args` so flags supplied to `fox <verb>` reach the underlying tool unchanged** (e.g., `fox upgrade --allow-downgrade` → `rpm-ostree upgrade --allow-downgrade`).

**Acceptance**:
1. **FOX-06** — `fox chsh [shell]` → `just chsh {{shell}}` → `/usr/libexec/silverfox/chsh.sh {{shell}}`. Recipe signature: `chsh shell="":`. The script: no-arg falls back to `read -p` (D-07 was resolved to drop the `tv` picker — package not available in Terra/Fedora-main 2026-05-11; the script keeps a `command -v tv` probe so a future `rpm-ostree install tv` from upstream still upgrades the prompt without code change). Allowlist: `bash`, `zsh`. Refuses unknown shells (including `fish`) with exit 1, stderr `Unknown shell: <name> (try: bash, zsh)`. No-op (exit 0, prints `Already on <target>.`) if current login shell matches. Otherwise `sudo usermod -s /usr/bin/<target> $USER`. Closing message: `Done. Log out and back in, or 'exec <target> -l' to swap now.`
2. **FOX-07** — `fox cheatsheet` → `just cheatsheet` → recipe body is `exec man 7 silverfox` (just runs bash, bash execs man). Recipe signature: `cheatsheet:` (arg-less; man takes no relevant args from fox). End-to-end: `fox cheatsheet` becomes `exec` chain `fox → just → bash → man` (bash exec replaces with man). Exit code = man's exit code.
3. **FOX-08** — `fox home factory-reset [--yes|-y]` → `just home::factory-reset {{args}}` → `/usr/libexec/silverfox/home-factory-reset.sh {{args}}`. The script performs a **hard reseed** of `$HOME` from `/etc/skel/`, scope-limited to paths silverfox ships in skel.
   - **Scope**: paths at depth ≤ 2 under `/etc/skel/`. In the current layout this resolves to: top-level files/symlinks (`.bashrc`, `.zshrc`, `.bash_profile`, `.bash_logout`) and depth-2 children under `.config/` (`silverfox/`, `mise/`, `ghostty/`, `zed/`). The depth-1 `.config/` directory itself is NOT wiped — only its silverfox-owned subdirs. Result: `$HOME/.config/firefox/`, `$HOME/.config/Code/`, etc., are preserved; `$HOME/.config/silverfox/`, `$HOME/.config/mise/`, `$HOME/.config/ghostty/`, `$HOME/.config/zed/` are wiped and replaced wholesale.
   - **N (entries affected)**: the count of scope paths enumerated above. Current layout: 8 (4 top-level + 4 depth-2 children). The prompt and final tally use this same number.
   - **Default (no flag)**: prints `Apply factory reset to <interpolated $HOME> from /etc/skel (N entries affected). [y/N]`, reads stdin via bash `read -r -p`. `y`/`Y`/`yes`/`YES` proceeds; anything else (including empty / EOF) exits 0 with `Cancelled.`.
   - **`--yes` / `-y`**: skips the prompt, proceeds immediately. Recognized anywhere in argv (the parser walks `"$@"`, not just `$1`).
   - **Unknown flag** (anything except `--yes`/`-y`): exits 1 with stderr `error: unknown flag: <flag>` before any I/O.
   - **Non-TTY without `--yes`**: exits 1 with stderr `error: no TTY available — use --yes for non-interactive`. Detected via bash `[[ -t 0 ]]`.
   - **On proceed**: for each scope path `P`, `rm -rf "$HOME/$P"; mkdir -p "$(dirname "$HOME/$P")"; cp -a "$SKEL_DIR/$P" "$HOME/$P"`. Symlinks in skel are preserved as symlinks via `cp -a`.
   - **Output**: `Reset N entries from /etc/skel.` on success.
   - **`/etc/skel` and `$HOME` overridable** via `SKEL_DIR` and `HOME` env vars (for test fixtures).
4. **FOX-09** — `fox update [args]` → `just update {{args}}` → `flatpak update {{args}}`. Recipe signature: `update *args:`. Streams output. Exits with flatpak's exit code.
5. **FOX-10** — `fox upgrade [args]` → `just upgrade {{args}}` → `rpm-ostree upgrade {{args}}`. Recipe signature: `upgrade *args:`. Streams output. Recipe trailer prints `Reboot to apply the staged deployment.` on rpm-ostree's exit 0.
6. **FOX-11** — `fox rollback [args]` → `just rollback {{args}}` → `rpm-ostree rollback {{args}}`. Recipe signature: `rollback *args:`. Streams output. Recipe trailer prints `Reboot to apply.` on exit 0.
7. **FOX-12** — `fox status [args]` → `just status {{args}}` → `rpm-ostree status {{args}}`. Recipe signature: `status *args:`. Output passthrough. `fox status --json` flows through to `rpm-ostree status --json`.
8. **FOX-13** — `fox cleanup [args]` → `just cleanup {{args}}` → `rpm-ostree cleanup {{args}}`. Recipe signature: `cleanup *args:` with default args `-prm` when none provided (recipe inlines: `rpm-ostree cleanup {{ if args == "" { "-prm" } else { args } }}`). Streams output. **Open**: verify the inline `if` expression parses on `just >= 1.20` in the first PR; fall back to a recipe-local helper variable if not.
9. **FOX-14** — `fox changelog [args]` → `just changelog {{args}}` → `rpm-ostree db diff {{args}}`. Recipe signature: `changelog *args:`. Default invocation (`fox changelog`) runs `rpm-ostree db diff` (human-readable). `fox changelog --format=json` passes through. Streams output. Exits with rpm-ostree's exit code. "No pending deployment" behavior delegated to rpm-ostree (verify in first PR — see open concerns).

**Test**: Each verb exercised side-by-side against the pre-feature image. `fox home factory-reset` on a system with edits to `~/.config/silverfox/stow/bash/.bashrc` prompts; on `y`, file is replaced. `--yes` skips the prompt. `fox upgrade` runs rpm-ostree upgrade and prints the reboot trailer.

---

### P1: Build pipeline ⭐ MVP

**Story**: `just build` produces the fox-enabled image with a single `man-build` stage (pandoc) plus straight-from-context `COPY` of bash/Justfile artifacts. CI runs shellcheck + bash integration tests before the build matrix.

**Acceptance**:
1. **FOX-15** — `os/Containerfile` gains one new stage: `FROM registry.fedoraproject.org/fedora-minimal:44 AS man-build`. The stage runs `microdnf install -y pandoc gzip && mkdir -p /out && pandoc -s -t man /workspace/silverfox.md -o /out/silverfox.7 && gzip -9 /out/silverfox.7`, with `COPY os/modules/fox/src/man/silverfox.md /workspace/` upstream. (No Bun stage — `fox` is bash, no compilation. `mkdir -p /out` is required: pandoc does not create its output directory.)
2. **FOX-16** — The final image stage bridges artifacts into `/var/tmp/fox-prebuilt/` BEFORE `build-rpms.sh` runs:
   ```
   COPY --from=man-build /out/silverfox.7.gz    /var/tmp/fox-prebuilt/silverfox.7.gz
   COPY os/modules/fox/src/bin                /var/tmp/fox-prebuilt/bin
   COPY os/modules/fox/src/recipes            /var/tmp/fox-prebuilt/recipes
   COPY os/modules/fox/src/libexec            /var/tmp/fox-prebuilt/libexec
   ```
   All land in `/var/tmp/fox-prebuilt/` inside Layer 2's RUN block, ahead of `rpmbuild`. `build-rpms.sh` picks up `os/modules/fox/rpm/silverfox-fox.spec`. The spec's `%install`:
   ```
   install -D -m 0755 /var/tmp/fox-prebuilt/bin/fox                          %{buildroot}/usr/bin/fox
   install -D -m 0644 /var/tmp/fox-prebuilt/silverfox.7.gz                     %{buildroot}/usr/share/man/man7/silverfox.7.gz
   install -D -m 0644 /var/tmp/fox-prebuilt/recipes/silverfox.justfile         %{buildroot}/usr/share/silverfox/silverfox.justfile
   install -D -m 0644 /var/tmp/fox-prebuilt/recipes/home.just                %{buildroot}/usr/share/silverfox/home.just
   install -D -m 0755 /var/tmp/fox-prebuilt/libexec/home-factory-reset.sh    %{buildroot}/usr/libexec/silverfox/home-factory-reset.sh
   install -D -m 0755 /var/tmp/fox-prebuilt/libexec/chsh.sh                  %{buildroot}/usr/libexec/silverfox/chsh.sh
   ```
   `%files` lists all six paths. **`Requires:`** declares `just` (dispatch backend), `bash >= 4` (interpreter), `coreutils` (cp/rm/mkdir/install/dirname), `findutils` (find), `gawk` (awk for VERSION_ID parsing), `man-db` (`man 7 silverfox` for cheatsheet), `rpm-ostree` (lifecycle verbs), `flatpak` (update), `sudo` + `shadow-utils` (chsh.sh). Most are pulled by the base image; explicit declaration documents the runtime graph and protects against derivative images that minimize. `tv` is NOT a Requires — `chsh.sh` falls back to `read -p` when absent (stays in `silverfox-cli-tools`). `Source0`: same synthesized empty tarball as other no-`src/`-as-source specs in silverfox (verify pattern in first PR — see open concerns). Cleanup adds `rm -rf /var/tmp/fox-prebuilt` to the same RUN as the existing `rm -rf /tmp/rpmbuild`.
3. **FOX-17** — `os/modules/fox/src/` ships:
   - `bin/fox` — bash dispatcher (~20 lines). Shebang `#!/usr/bin/env bash`; `set -euo pipefail` at top. Reads `SILVERFOX_JUSTFILE` env (default `/usr/share/silverfox/silverfox.justfile`) and `SILVERFOX_OS_RELEASE` env (default `/etc/os-release`). Handles `--help`/`--version`/no-arg/`home <sub>`/other-verb cases via bash `case`. Uses `exec just ...` to replace process where possible (verbs not requiring post-dispatch logic).
   - `man/silverfox.md` — pandoc source for the manpage.
   - `recipes/silverfox.justfile` — main Justfile (8 top-level recipes + `mod home`).
   - `recipes/home.just` — home module (`factory-reset *args`).
   - `libexec/home-factory-reset.sh` — factory-reset bash (~40 lines, shebang `#!/usr/bin/env bash`, `set -euo pipefail`).
   - `libexec/chsh.sh` — shell-switching bash (~25 lines, shebang `#!/usr/bin/env bash`, `set -euo pipefail`).
   - `tests/fox.test.sh` — integration tests for `/usr/bin/fox` dispatcher (run bash dispatcher with mocked `just` on PATH).
   - `tests/factory-reset.test.sh` — integration tests for `home-factory-reset.sh` with tmpfs fixtures.
   - `tests/lib.sh` — shared helpers (mktemp fixtures, fake-just stub generator, assert helpers).
   No `package.json`, no `bun.lock`, no `tsconfig.json`, no `node_modules/`, no `dist/`.
4. **FOX-18** — Bash scripts are linted: `shellcheck` must pass clean on `bin/fox` + `libexec/*.sh` + `tests/*.sh`. Recipes (`recipes/*.just*`) are not linted by default; `just --fmt --check` can be added later. No external runtime deps beyond `just`, `pandoc` (build-time only), and standard coreutils.
5. **FOX-19** — `Justfile` (build-side) gains:
   - `just fox-test` — runs `bash os/modules/fox/src/tests/fox.test.sh && bash os/modules/fox/src/tests/factory-reset.test.sh`.
   - `just fox-lint` — runs `bash -n` (syntax check) then `shellcheck` on `os/modules/fox/src/bin/fox`, `os/modules/fox/src/libexec/*.sh`, `os/modules/fox/src/tests/*.sh`. `bash -n` catches syntax errors shellcheck sometimes parses around.
   - `just lint` extends to call `fox-lint`.
   - `just fox-gen-man` (optional, dev convenience) — runs `pandoc -s -t man os/modules/fox/src/man/silverfox.md -o /tmp/silverfox.7` for local preview.
   - `just build` invokes the Containerfile flow.
6. **FOX-20** — `.github/workflows/build.yml` runs `just fox-lint && just fox-test` as a pre-flight job (shellcheck via apt + bash on the runner). No Bun setup needed. Pre-flight failure short-circuits the image-build matrix.

**Test**: `just build` succeeds with no Bun on host. `just fox-test && just fox-lint` exits 0. CI: PR with a syntax error in `bin/fox` fails shellcheck and skips matrix.

---

### P2: Module reorg — `home/` + `fox/` created, `shell-ux/` narrowed, `dotfiles/` retired

**Story**: The `os/modules/` tree gains two new modules (`home/`, `fox/`), narrows one (`shell-ux/`), and retires one (`dotfiles/`).

**Acceptance**:
1. **FOX-21** — New `os/modules/home/` with subdirs:
   - `src/etc/skel/.config/silverfox/stow/` — the five stow packages (per FOX-25..28b)
   - `src/etc/skel/{.bashrc,.zshrc}` — relative symlinks (per FOX-29)
   - `src/etc/skel/.config/{mise/config.toml,ghostty/config,zed/settings.json}` — relative symlinks (per FOX-29)
   - `rpm/silverfox-home.spec` — declares all paths under `/etc/skel/.config/silverfox/` + the five `/etc/skel` symlinks. `Requires:` empty.
2. **FOX-22** — New `os/modules/fox/` with subdirs:
   - `src/` — bash + recipes + libexec + man source + tests per FOX-17.
   - `rpm/silverfox-fox.spec` — per FOX-16. Reads pre-built artifacts from `/var/tmp/fox-prebuilt/`. `Source0:` empty synthesized tarball.
   The `src/` tree is consumed by (a) the `man-build` Containerfile stage (for `man/silverfox.md` only) and (b) direct `COPY` in the final stage (for `bin/`, `recipes/`, `libexec/`).
3. **FOX-23** — `os/modules/shell-ux/` narrowed.
   - **Retained**: `etc/user-motd` (rewritten per FOX-40), `etc/mise/config.toml`, `etc/profile.d/silverfox-shell-migrate.sh` (rescue for users whose login shell binary was removed — covers ex-fish / ex-nu accounts after rebase; kept through v1.0 minimum, revisit when nobody could plausibly still be on a removed shell).
   - **Deleted from `shell-ux/src/`**: `etc/zshrc` (silverfox's customized one — `%files` drops the path so the `zsh` package's stock `/etc/zshrc` reclaims it on upgrade; if rpm complains about file ownership transfer, fall back to `%ghost` for one release), `usr/lib/systemd/user/rclone-gdrive.service` (moved here from the original FOX-34 plan — see FOX-34), `usr/share/ublue-os/just/60-custom.just` + the `%dir /usr/share/ublue-os/just` ownership.
   - **Already absent** (deleted in earlier refactors, listed only for the record): `etc/profile.d/silverfox-cli-init.sh`, `etc/zsh/silverfox-cli-init.zsh`, `etc/fish/conf.d/silverfox-cli-init.fish`. No action needed; FOX-23 leaves them alone.
   - `silverfox-shell-ux.spec` `%files` updated accordingly; `%description` rewritten to reflect the narrowed scope.
4. **FOX-24** — `os/modules/dotfiles/` deleted entirely. `build-rpms.sh` no longer finds `silverfox-stow-defaults.spec`. The `silverfox-stow-defaults` RPM is retired (not renamed).

**Test**: `ls os/modules/` shows `base cli-tools flatpaks home kubernetes services shell-ux fox` (8 dirs; was 7, -dotfiles, +home, +fox). `rpm -qa | grep ^silverfox-` lists `silverfox-{base,cli-tools,flatpaks,home,kubernetes,services,shell-ux,fox}` (8 RPMs). `rpm -ql silverfox-shell-ux` lists `/etc/user-motd` + `/etc/mise/config.toml` + `/etc/profile.d/silverfox-shell-migrate.sh` only.

---

### P2: `/etc/skel` content — bash, zsh, mise, ghostty, zed packages + symlinks

**Acceptance**:
1. **FOX-25** — `/etc/skel/.config/silverfox/stow/bash/.bashrc` ships full bash config (starship/atuin/zoxide/mise/fzf bindings, EDITOR/VISUAL, eza/bat aliases gated on the 14-env-var AI-agent guard, Ctrl+P fzf, Alt+S sudo, Ctrl+G fzf git-branch). `command -v <tool>` guard around each integration. Mode 0644.
2. **FOX-26** — `/etc/skel/.config/silverfox/stow/zsh/.zshrc` ships zsh equivalent (same integrations + zsh-syntax-highlighting + zsh-autosuggestions in Fedora-main paths). Same guard. Mode 0644.
3. **FOX-27** — `/etc/skel/.config/silverfox/stow/mise/.config/mise/config.toml` ships user mise pins. JVM block dropped. 9 toolchains: node=lts, bun=latest, pnpm=latest, python=latest, uv=latest, go=latest, rust=stable, zig=latest, act=latest. Mode 0644.
4. **FOX-28** — `/etc/skel/.config/silverfox/stow/ghostty/.config/ghostty/config` ships silverfox ghostty config (unchanged content). Mode 0644.
4b. **FOX-28b** — `/etc/skel/.config/silverfox/stow/zed/.config/zed/settings.json` ships silverfox zed config: JSONC with `"vim_mode": true` and `"vim": { "default_mode": "helix_normal", "use_smartcase_find": true, "use_system_clipboard": "always", "toggle_relative_line_numbers": false }`. Mode 0644. (Source of truth: `os/modules/dotfiles/src/usr/share/silverfox/stow/zed/.config/zed/settings.json` from commit 4cb84b3; migrated as-is into the new `home/` module.)
5. **FOX-29** — Five relative symlinks at `/etc/skel/{.bashrc,.zshrc,.config/mise/config.toml,.config/ghostty/config,.config/zed/settings.json}` pointing into the stow tree. `silverfox-home.spec` declares them as symlinks.
6. **FOX-30** — `silverfox-home.spec` `%files` lists all paths + `%dir` ownership for `/etc/skel/.config/silverfox`, `/etc/skel/.config/silverfox/stow`, `/etc/skel/.config/silverfox/stow/{bash,zsh,mise,ghostty,zed}`.

**Test**: Fresh `useradd testuser`:
- `ls -la ~testuser/.bashrc` shows symlink → `.config/silverfox/stow/bash/.bashrc`
- `~testuser/.config/silverfox/stow/{bash,zsh,mise,ghostty,zed}/` populated as real dirs (mode 0644)
- Login bash activates the full pre-feature wiring
- `grep -l 'silverfox' /etc/profile.d/` returns only `silverfox-shell-migrate.sh` (the kept rescue script)
- `grep -E '^(java|kotlin|gradle) =' ~testuser/.config/mise/config.toml` returns nothing
- `grep -F '"default_mode": "helix_normal"' ~testuser/.config/zed/settings.json` matches (JSONC; bypass jq's lack of JSON5 by string-matching the canonical line)

---

### P2: `home factory-reset` (image-defaults wipe via libexec)

**Story**: `fox home factory-reset` is the only `fox home` verb in v1. The user-facing behavior (prompt, --yes, scope, exit codes) is defined in FOX-08; this section pins the implementation: a Justfile recipe in `home.just` shelling out to `/usr/libexec/silverfox/home-factory-reset.sh`.

**Acceptance**:
1. **FOX-31** — `os/modules/fox/src/recipes/home.just` defines:
   ```
   # Hard reset $HOME from /etc/skel (silverfox-managed paths only)
   factory-reset *args:
       /usr/libexec/silverfox/home-factory-reset.sh {{args}}
   ```
   And `recipes/silverfox.justfile` declares `mod home` at the bottom to load it.
2. **FOX-32** — `os/modules/fox/src/libexec/home-factory-reset.sh` is a bash script (~40 lines, `set -euo pipefail`) implementing FOX-08:
   - Reads `SKEL_DIR` (default `/etc/skel`) and `HOME` from env.
   - Parses `--yes`/`-y` by walking `"$@"` (any position), not just `$1`; rejects other flags with exit 1 and stderr `error: unknown flag: <flag>`.
   - Enumerates paths at depth ≤ 2 under `$SKEL_DIR` via `find -mindepth 1 -maxdepth 1` at top + inside each top-level directory. Stores results in an array; `N=${#paths[@]}`.
   - TTY check: `[[ -t 0 ]]`. If `$YES` is unset and not a TTY, exit 1 with stderr `error: no TTY available — use --yes for non-interactive`.
   - Prompt: `read -r -p "Apply factory reset to $HOME from $SKEL_DIR (N entries affected). [y/N] " ans` — `$HOME` is interpolated to the actual path (e.g. `/home/athena`), not literal. Accept `y/Y/yes/YES`; anything else exits 0 with `Cancelled.`.
   - Apply: for each path, `rm -rf "$HOME/$p"; mkdir -p "$(dirname "$HOME/$p")"; cp -a "$SKEL_DIR/$p" "$HOME/$p"`.
   - Final `echo "Reset $N entries from $SKEL_DIR."`.
   - Mode 0755. Passes shellcheck.
3. **FOX-33** — README's "Set up dotfiles" + `.specs/project/ROADMAP.md`:
   - README documents: skel ships seed via useradd; dotfiles user-domain thereafter; `fox home factory-reset` reseeds (destructive); custom additions live OUTSIDE `~/.config/silverfox/`, `~/.config/mise/`, `~/.config/ghostty/` (recommended pattern: `~/.config/dotfiles/` farmed with stow); git-track `~/.config/silverfox/` for selective rollback.
   - ROADMAP queued: `fox-home-sync` (v2). Substrate (bash + jq vs Bun TS vs Rust) and the reconciliation contract are designed at v2 time.

**Test**: `fox home factory-reset --yes` (and `bash /usr/libexec/silverfox/home-factory-reset.sh --yes`) on a system with edits to `~/.config/silverfox/stow/bash/.bashrc` overwrites the file. User-added file at `~/.config/silverfox/stow/bash/custom.sh` is removed. `~/.config/firefox/` is preserved.

---

### P2: gdrive integration retired

**Acceptance**:
1. **FOX-34** — `/usr/lib/systemd/user/rclone-gdrive.service` deleted from `os/modules/shell-ux/src/` (the file actually lives in shell-ux today, not services as an earlier draft claimed); `silverfox-shell-ux.spec` `%files` updated. (Cross-references FOX-23, which already lists this path in shell-ux's "Deleted" set.)
2. **FOX-35** — `rclone` and `fuse3` removed from `silverfox-cli-tools.spec` Requires and `os/modules/cli-tools/packages.txt`.
3. **FOX-36** — References to `gdrive`, `rclone`, `~/gdrive`, `gdrive-setup`, `gdrive-remove` removed from `/etc/user-motd`, `README.md`, `Justfile`, and `os/modules/*/rpm/*.spec` `%description` blocks. `%changelog` left intact.

**Test**: `systemctl --user list-unit-files | grep gdrive` returns nothing. `rpm -q rclone fuse3` "not installed". `grep -rn 'gdrive' README.md Justfile $(find os -type f \( -name '*.sh' -o -name '*.md' -o -name 'user-motd' \))` returns zero.

---

### P2: Legacy stow runtime retired

**Acceptance**:
1. **FOX-37** — `os/modules/dotfiles/` deleted (covered by FOX-24). `/usr/share/silverfox/stow/` does not exist. `/etc/profile.d/silverfox-stow-defaults.sh` + marker no longer ship.
2. **FOX-38** — `stow` STAYS in `silverfox-cli-tools.spec` Requires + `os/modules/cli-tools/packages.txt`. README documents new use: `stow --target=$HOME --dir=$HOME/.config/dotfiles <pkg>`.

**Test**: `rpm -qa | grep ^silverfox-stow-defaults` returns nothing. `rpm -q stow` returns "installed". `find / -path /usr/share/silverfox/stow -prune -print 2>/dev/null` is empty.

---

### P2: ujust artifacts removed

**Acceptance**:
1. **FOX-39** — `os/modules/shell-ux/src/usr/share/ublue-os/just/60-custom.just` deleted (covered by FOX-23). `silverfox-shell-ux.spec` `%files` drops the path + `%dir /usr/share/ublue-os/just`.
2. **FOX-40** — `/etc/user-motd` rewritten: every `ujust <recipe>` row → `fox <recipe>`; `tools` row → `man silverfox` (with `fox cheatsheet` as alias); `fox home factory-reset` row added; gdrive rows removed. Banner retained.
3. **FOX-41** — `README.md` + repo-root `Justfile` (build-side, not the runtime `/usr/share/silverfox/silverfox.justfile`) rewritten: README sections "Set up dotfiles" → new `/etc/skel` + `fox home factory-reset` flow (per FOX-33); "Rollback" → `fox rollback`; "Iterating on dotfiles" → edit-in-`~/.config/silverfox/stow/` + custom-stow-outside-silverfox note. "Why not nix?" untouched. Build-side `Justfile` swaps any `ujust`-mentioning recipes (typically dev shortcuts) to `fox` equivalents.
4. **FOX-42** — `ujust` mentions in `%description` blocks replaced/removed. `%changelog` left intact.

**Test**: `grep -rn 'ujust\|60-custom\.just\|libformatting\.sh\|ugum\|Urllink' README.md Justfile $(find os -type f \( -name '*.spec' -o -name '*.sh' -o -name 'user-motd' -o -name '*.md' \))` returns zero outside `%changelog`.

---

### P2: Test coverage

**Story**: Bash dispatcher + factory-reset behavior + shellcheck locked on every PR.

**Acceptance**:
1. **FOX-43** — `os/modules/fox/src/tests/fox.test.sh`: integration tests for `bin/fox`. Tests use a fake `just` stub on PATH (prints its args to stderr, exits with caller-controlled code). Asserts:
   - `fox --version` prints expected `VERSION_ID` (with `/etc/os-release` mocked via env-override or tmpfile + override read path).
   - `fox` / `fox --help` invokes fake-just with `--list`.
   - `fox upgrade` invokes fake-just with `upgrade`.
   - `fox status --json` invokes fake-just with `status --json`.
   - `fox home factory-reset --yes` invokes fake-just with `home::factory-reset --yes`.
   - `fox home` (no sub) invokes fake-just with `--list home`.
   - Unknown verb passthroughs to fake-just; exit code propagated.
2. **FOX-44** — `os/modules/fox/src/tests/factory-reset.test.sh`: end-to-end against `libexec/home-factory-reset.sh`. Uses tmpfs fixtures (`SKEL_DIR=/tmp/skel-fixture-$$/`, `HOME=/tmp/home-fixture-$$/`). Asserts:
   - bare invocation with PTY-allocated stdin sending `y\n` (wrapper: `script -qc '<cmd>' /dev/null` invoked from the test with a here-doc feeding `y\n` — `script(1)` allocates a pseudo-terminal so `[[ -t 0 ]]` is true and `read` works) → applies; home matches skel for silverfox-managed paths.
   - bare with PTY stdin sending `n\n` (same `script(1)` wrapper) → exit 0, home unchanged, stdout contains `Cancelled.`.
   - `--yes` → no prompt, applies (no PTY needed; `--yes` short-circuits the TTY check).
   - stdin redirected from `/dev/null` (non-TTY: `[[ -t 0 ]]` false) + no `--yes` → exit 1 with stderr `no TTY`.
   - User-added `$HOME/.config/silverfox/stow/bash/custom.sh` removed after run.
   - Non-silverfox path `$HOME/.config/firefox/profile.ini` preserved.
   - Unknown flag (e.g., `--banana`) → exit 1 with `error: unknown flag: --banana` in stderr.
   - `tests/lib.sh` exposes a `run_with_pty <input> -- <cmd...>` helper wrapping `script -qc` for the PTY cases. CI runner must have `util-linux` (provides `script(1)`) — present in stock Ubuntu/Fedora GH Actions images.
3. **FOX-45** — `shellcheck os/modules/fox/src/bin/fox os/modules/fox/src/libexec/*.sh os/modules/fox/src/tests/*.sh` exits 0. Pre-flight runs shellcheck after the integration tests.

**Test**: `just fox-test && just fox-lint` exits 0. Tests cover all dispatch branches in `bin/fox` and all behavioral branches in `home-factory-reset.sh`.

---

### P3: motd + cheatsheet manpage

**Acceptance**:
1. **FOX-46** — `/etc/user-motd` (new content per FOX-40) lists: `fox` (discovery), `man silverfox` or `fox cheatsheet`, `fox upgrade` / `fox rollback` / `fox update`, `fox home factory-reset`. Drops `apply-defaults`, `gdrive-*`.
2. **FOX-47** — `os/modules/fox/src/man/silverfox.md` is the manpage source (pandoc-converted in `man-build` stage per FOX-15). Sections: SYNOPSIS, COMMANDS (one-line per `fox` verb including `home factory-reset`), ENVIRONMENT (editor: `zed --wait` unified as `$EDITOR` + `$VISUAL` with vim_mode + helix_normal default_mode — replaces the old hx/code split; navigation keybinds zoxide+Ctrl+P+Ctrl+R+Ctrl+T+Alt+C+Alt+S+Ctrl+G; containers rootless-podman; runtime versions mise; drop-in replacements eza/bat/rg; shells bash + zsh).

**Test**: Fresh login shows the motd. `man 7 silverfox` and `fox cheatsheet` open the same paginated content. `apropos silverfox` returns the entry.

---

## Edge Cases

- **User runs `ujust <recipe>` from muscle memory**: `ujust` binary still exists (inherited; goes away with `post-ublue`). With `60-custom.just` removed, `ujust chsh` prints "error: Justfile does not contain recipe `chsh`".
- **User runs `just <recipe>` directly** (bypassing fox): `/usr/share/silverfox/silverfox.justfile` is not in any default just search path; plain `just <recipe>` in `$HOME` fails. Workaround: `just -f /usr/share/silverfox/silverfox.justfile <recipe>` (what fox does). README documents this as an escape hatch.
- **`fox <verb> --help` doesn't show recipe doc**: `just` has no per-recipe `--help` flag — `--help` is reserved for just itself. `fox upgrade --help` passes `--help` through to `rpm-ostree upgrade` (which prints rpm-ostree's help). To see what silverfox's recipe does, run `fox` (no args) → `just --list` shows each recipe with its preceding doc comment. Documented as a known limitation; mitigation in v1.1 via `bin/fox` intercepting `fox <verb> --help` and translating to `just --show <verb>` (which prints recipe body).
- **Existing user on rebased system has OLD symlinked rc files**: `~/.bashrc` symlink dangles after rebase. Recovery: `fox home factory-reset` in one shot. Motd flags this.
- **Existing user customized old `~/.bashrc` by breaking the symlink**: real file survives until `fox home factory-reset` overwrites it. To preserve: back up first, or skip the reset.
- **User has custom files inside `~/.config/silverfox/stow/<pkg>/`**: wiped by `factory-reset`. Keep custom content OUTSIDE `~/.config/silverfox/`, `~/.config/mise/`, `~/.config/ghostty/`, `~/.config/zed/` — those four trees are silverfox-domain. Recommended pattern: `~/.config/dotfiles/` farmed with stow (see FOX-38).
- **User has files in non-silverfox `~/.config/` subdirs**: NOT touched by `factory-reset`. Scope is depth ≤ 2 under `/etc/skel/`.
- **Fedora-inherited `~/.bash_profile` / `~/.bash_logout` customizations**: reseeded to stock Fedora content by `factory-reset`. Accepted per "anything in /etc/skel is silverfox-managed".
- **Future image upgrade adds new tooling**: existing users don't see it automatically. Pick up via `fox home factory-reset` or manual cp from skel.
- **`tv` removed** via `rpm-ostree override remove tv`: `chsh.sh` falls back to `read -p` prompt.
- **`rpm-ostree` not present** (e.g. distrobox): `upgrade`/`status`/`cleanup`/`rollback`/`changelog` exit non-zero with rpm-ostree's own error.
- **`just` not installed** (e.g., `rpm-ostree override remove just`): `fox` exits 1 with `exec: just: not found`. Recoverable via `rpm-ostree install just`. `silverfox-fox.spec`'s `Requires: just` prevents this in standard flow.
- **`fox home factory-reset` when subtree partially missing**: `rm -rf` no-op on missing paths; `cp -a` recreates. Useful recovery path.
- **`fox home factory-reset` in non-interactive context without `--yes`**: exits 1 with `no TTY`. Prevents silent runs in pipelines/CI/cron.
- **User on fish before rebase**: dangling `/usr/bin/fish` login shell. Recovery: TTY login + `usermod -s /usr/bin/zsh $USER`, then `fox chsh zsh`.
- **`useradd` invoked with `-M`**: skel skipped; manual `cp -a /etc/skel/. ~/` or `fox home factory-reset --yes` after `$HOME` exists.
- **`/etc/os-release` `VERSION_ID` missing or malformed**: `fox --version` prints empty string. Not a silverfox concern — `/etc/os-release` is owned by the base; if it's broken many other things are too.

---

## Requirement Traceability

| Story | Requirement IDs | Count |
|---|---|---|
| P1: Dispatcher present | FOX-01 … FOX-05 | 5 |
| P1: Lifecycle commands | FOX-06 … FOX-14 | 9 |
| P1: Build pipeline | FOX-15 … FOX-20 | 6 |
| P2: Module reorg | FOX-21 … FOX-24 | 4 |
| P2: /etc/skel content | FOX-25 … FOX-30 | 6 |
| P2: home factory-reset | FOX-31 … FOX-33 | 3 |
| P2: gdrive retired | FOX-34 … FOX-36 | 3 |
| P2: Legacy stow retired | FOX-37 … FOX-38 | 2 |
| P2: ujust artifacts removed | FOX-39 … FOX-42 | 4 |
| P2: Test coverage | FOX-43 … FOX-45 | 3 |
| P3: motd + manpage | FOX-46 … FOX-47 | 2 |

**Total**: 47 testable requirements.

---

## Supersedes

| Artifact | Disposition |
|---|---|
| `os/modules/dotfiles/` entire module | Deleted (FOX-24) |
| `silverfox-stow-defaults` RPM | Retired (not renamed) (FOX-24) |
| `/etc/profile.d/silverfox-stow-defaults.sh` + marker | Deleted (FOX-37) |
| `/usr/share/silverfox/stow/` | Deleted from image (FOX-37) |
| `os/modules/shell-ux/src/etc/profile.d/silverfox-cli-init.sh` | Deleted; content moves to `/etc/skel/.config/silverfox/stow/bash/.bashrc` (FOX-23, FOX-25) |
| `os/modules/shell-ux/src/etc/zsh/silverfox-cli-init.zsh` + customized `/etc/zshrc` | Deleted; content moves to `/etc/skel/.config/silverfox/stow/zsh/.zshrc` (FOX-23, FOX-26). Stock Fedora `/etc/zshrc` returns |
| `os/modules/shell-ux/src/etc/fish/conf.d/silverfox-cli-init.fish` | Deleted; fish dropped entirely (FOX-23) |
| `os/modules/shell-ux/src/usr/share/ublue-os/just/60-custom.just` | Deleted (FOX-23, FOX-39) |
| `rclone`, `fuse3` from `silverfox-cli-tools` Requires | Removed (FOX-35) |
| `fish` from `silverfox-cli-tools` Requires | Removed |
| `rclone-gdrive.service` | Deleted (FOX-34) |
| `/etc/user-motd` (old) | Rewritten (FOX-23, FOX-40, FOX-46) |
| JVM toolchains in user mise config | Dropped (FOX-27) |
| `/etc/silverfox/` reserved as v2 config root (former D-05) | Reservation retired — all declarative config moves to `~/.config/silverfox/manifests/` in v2 (FOX-33) |
| `starship` precedent for non-RPM binary | No longer applies — starship migrated to Terra-RPM at F44 bump; fox follows the RPM-tracked pattern (D-04) |
| Intermediate `fox home reset` design (`--dry-run`/`--diff`/per-pkg/SyncCommand impl) | Superseded by `fox home factory-reset` (D-16) |
| Heavy TS-native CLI design (gunshi + consola + @iarna/toml + lib/skel.ts) | Superseded by thin wrapper around `just` + libexec bash scripts (D-18) |
| Thin Bun-compiled wrapper around `just` (intermediate design) | Superseded by tiny bash dispatcher (~20 lines). Bun's value-add at the dispatch layer (compile-time types, embedded runtime) was overhead for v1; bash + just suffices. v2 may reintroduce a typed runtime when `fox home sync` needs real substrate (D-02 reversed, D-18 sharpened) |

**RPMs introduced:** `silverfox-home`, `silverfox-fox`. **RPMs retired:** `silverfox-stow-defaults`.

STATE.md "Dotfile seeding (2026-05-10 — chezmoi → GNU stow)" gets a follow-up: "2026-05-NN — stow seeding → /etc/skel user-domain via fox feature". "Shells (2026-05-02)" three-shell entry → two-shell.

---

## Success Criteria

- [ ] `just build` succeeds end-to-end with fox-enabled Containerfile (FOX-01..20).
- [ ] CI matrix: `shellcheck` + bash integration tests pre-flight passes; both image variants build; `bootc container lint` passes as final RUN.
- [ ] Image size delta: negligible from fox itself (~6KB total: 1KB fox + 2KB libexec + 1KB recipes + 2KB manpage). Net: roughly −35MB from deleted `rclone` (~30MB), `fuse3` (~1MB), and `fish` (~5MB); precise number TBD at build time.
- [ ] On a fresh VM rebased + `useradd testuser`: 5 symlinks resolve; `~testuser/.config/silverfox/stow/{bash,zsh,mise,ghostty,zed}/` populated; login bash activates pre-feature wiring; `fox` lists 9 recipes; `fox cheatsheet` opens manpage; `mise ls` shows 9 toolchains (no JVM); `grep -F '"default_mode": "helix_normal"' ~testuser/.config/zed/settings.json` matches.
- [ ] `fox home factory-reset` on a user with edited `~/.config/silverfox/stow/bash/.bashrc` prompts; on `y`, overwrites; `diff -q` returns identical to skel source.
- [ ] `fox home factory-reset --yes` skips the prompt and applies.
- [ ] `fox home factory-reset </dev/null` (non-TTY) without `--yes` exits 1 with `no TTY` in stderr.
- [ ] After `fox home factory-reset --yes`: user-added `~/.config/silverfox/stow/bash/custom.sh` is gone; `~/.config/firefox/` is preserved.
- [ ] `systemctl --user list-unit-files | grep gdrive` returns nothing.
- [ ] `rpm -q rclone fuse3 fish` reports all three "not installed".
- [ ] `rpm -q stow just` reports both "installed". (`tv` dropped — D-07 resolved 2026-05-11.)
- [ ] `rpm -q silverfox-stow-defaults` reports "not installed".
- [ ] `rpm -q silverfox-home silverfox-fox` reports both "installed"; `rpm -qf /usr/bin/fox /usr/share/man/man7/silverfox.7.gz /usr/share/silverfox/silverfox.justfile /usr/share/silverfox/home.just /usr/libexec/silverfox/home-factory-reset.sh /usr/libexec/silverfox/chsh.sh` all return `silverfox-fox`.
- [ ] `ujust chsh` returns "recipe not found".
- [ ] `grep -rn 'ujust\|60-custom\.just\|gdrive\|rclone-gdrive\|fish' README.md Justfile $(find os -type f \( -name '*.sh' -o -name '*.md' -o -name 'user-motd' -o -name '*.just' \) -not -path '*/fox/*')` returns zero matches outside `%changelog`.
- [ ] STATE.md "Current focus" reflects `fox` as in-flight; ROADMAP.md updated; `fox-home-sync` backlog entry queues v2 manifest path under `~/.config/silverfox/manifests/` (substrate + contract TBD at v2 time); "Shells" section updated to two-shell.
- [ ] CI run time regression: +10-20s (shellcheck + bash integration + man-build pandoc stage). Smaller than the original Bun-based estimate.
