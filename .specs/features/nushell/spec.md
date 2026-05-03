# nushell Specification

## Problem Statement

Fish is being replaced with nushell as sideral's third interactive shell. The migration also ships carapace (native multi-shell tab completions for 839+ CLIs), a curated set of 7 nushell plugins installed via nupm, and a boot-time seeding service that guarantees user shell profiles exist for all three shells (bash, zsh, nushell) and auto-migrates users away from removed shells.

## Goals

- [ ] Fish fully removed; nushell installed and wired with the same tool suite (starship, atuin, zoxide, mise, fzf, `view` command, keybindings, agent detection)
- [ ] Shell profiles (`~/.bashrc`, `~/.zshrc`, `~/.config/nushell/{env.nu,config.nu}`, `~/.config/mise/config.toml`) guaranteed to exist — seeded on each session start if missing, never overwritten
- [ ] carapace available system-wide and wired into bash, zsh, and nushell for native tab completions
- [ ] 7 curated plugins installed and registered via nupm: query, formats, gstat, file, highlight, rpm, explore

## Out of Scope

| Feature | Reason |
|---|---|
| inshellisense | Conflicts with starship in nushell (documented open issue); still pre-1.0 after 2+ years; requires Node.js runtime |
| Nushell as default shell | zsh stays default; nushell is opt-in via `ujust chsh nu` |
| Per-user nushell config customisation | Chezmoi-managed; sideral seeds the minimum skeleton only |
| nupm as a user-facing tool | Used only at image build time, not shipped to users |
| `nu_plugin_polars` | ~50–100 MB binary — bloat, DataFrames overkill for a daily shell |
| `nu_plugin_dns` | Makes network requests — attack surface; `dig`/`host` already available |
| `nu_plugin_dbus` | D-Bus access from shell — elevated attack surface, niche use |
| `nu_plugin_compress` | Redundant — `tar`/`gzip`/`zstd` work fine as external commands |
| `nu_plugin_skim` | Redundant — fzf already wired in all three shells |
| `nu_plugin_semver` | `nu_plugin_inc` (from nushell tarball) covers the core semver case |

---

## User Stories

### P1: Fish → Nushell migration ⭐ MVP

**User Story**: As a sideral user, I want to switch to nushell as my interactive shell so that I get a structured-data-first shell with the same sideral tooling I already have.

**Why P1**: Core of the feature. Everything else depends on nushell being present and wired correctly.

**Acceptance Criteria**:

1. WHEN the image builds THEN `fish` SHALL NOT be present in `packages.txt` or in `sideral-cli-tools.spec Requires`
2. WHEN the image builds THEN `/etc/fish/conf.d/sideral-cli-init.fish` SHALL NOT be shipped; `sideral-shell-ux.spec` SHALL NOT list it
3. WHEN the image builds THEN `nu` (Fedora main `nushell` package) SHALL be in `packages.txt` and `sideral-cli-tools.spec Requires`
4. WHEN nushell starts interactively THEN `/usr/share/nushell/vendor/autoload/sideral-cli-init.nu` SHALL auto-load and wire (env-phase safe): starship, atuin (`--disable-up-arrow`), zoxide, `view` command, agent detection, `$env.EDITOR`/`$env.VISUAL` — **no eza/bat aliases** (see D-07); **mise, keybindings, and carapace external completer are excluded from vendor autoload** (see D-01, D-03)
5. WHEN nushell starts and any agent env-var marker is set (same 14-marker list as bash/zsh) THEN `view` SHALL still be available — no aliases to suppress in nushell (see D-07)
6. WHEN `ujust chsh` is invoked without arguments THEN the interactive picker SHALL offer `{bash, zsh, nu}` — not `fish`
7. WHEN `ujust chsh nu` is invoked THEN the login shell SHALL be set to `/usr/bin/nu`
8. WHEN `ujust tools` is invoked THEN the motd/cheatsheet SHALL reference `nu` not `fish`

**Independent Test**: `ujust chsh nu` → open new terminal → starship prompt renders, `z <dir>` works, `view file.rs` shows syntax-highlighted output, `which fish` returns empty.

---

### P1: Boot-time shell profile seeding ⭐ MVP

**User Story**: As a sideral user, I want my shell config files to exist automatically so that every shell works correctly on first launch with no manual setup.

**Why P1**: Nushell requires user-level `config.nu` for config-phase constructs (mise hooks, keybindings, carapace — see D-01, D-03). Bash and zsh user profiles (`~/.bashrc`, `~/.zshrc`) may be absent on upgraded installs. All three must be guaranteed present. Seeding must ship with the migration.

**Acceptance Criteria**:

1. WHEN a user session starts THEN `sideral-shell-seed.service` (systemd **user** unit, `Type=oneshot`, `WantedBy=default.target`) SHALL run
2. WHEN the user's login shell binary does not exist on disk THEN the service SHALL switch the login shell to `/usr/bin/zsh` via `usermod -s /usr/bin/zsh $USER` — covers fish→nushell upgrade path where `/usr/bin/fish` is removed from the image
3. WHEN `~/.bashrc` does not exist THEN the service SHALL create a minimal skeleton (sources `/etc/bashrc` if present; placeholder comment inviting user customisation)
4. WHEN `~/.zshrc` does not exist THEN the service SHALL create a minimal skeleton (placeholder comment only — `/etc/zshrc` already sources `sideral-cli-init.zsh`; sourcing it again from `~/.zshrc` would double-load)
5. WHEN `~/.config/nushell/env.nu` does not exist THEN the service SHALL create it with a skeleton containing:
   - mise shims prepended to `$env.PATH` (guarded by path existence check) — ensures mise-managed tools are on PATH before hooks fire and in non-interactive contexts (see D-01)
6. WHEN `~/.config/nushell/config.nu` does not exist THEN the service SHALL create it with a skeleton containing:
   - `mise activate nu` → save + source pattern (directory-switching hook, config-phase only — see D-01)
   - carapace external completer block (`$env.config.completions.external.completer`) guarded by `(which carapace | is-not-empty)` (see D-03)
   - `$env.config.keybindings` entry: Ctrl-P fzf quick-open — guarded by `(which fzf | is-not-empty)` (see D-03). Ctrl-R is handled by atuin. Alt-S and Ctrl-G dropped.
7. WHEN `~/.config/mise/config.toml` does not exist THEN the service SHALL create a skeleton containing the full default toolchain (node/bun/pnpm, python/uv, java/kotlin/gradle, go/rust/zig, act) so chezmoi has a user-level file to track and back up; `/etc/mise/config.toml` is settings-only and does not declare tools
8. WHEN any profile already exists THEN the service SHALL NOT overwrite or modify it
9. WHEN the service runs THEN it SHALL be idempotent — 100 runs produce the same result as one

**Independent Test**: Delete `~/.bashrc`, `~/.zshrc`, `~/.config/nushell/`, `~/.config/mise/config.toml`; run `systemctl --user start sideral-shell-seed`; confirm all five files exist with correct content; run service again; confirm files unchanged; open nushell → `git <TAB>` shows carapace completions.

---

### P2: Curated plugin set

**User Story**: As a sideral nushell user, I want a curated set of plugins pre-installed and registered so that structured data superpowers (syntax highlighting, git status, file detection, RPM inspection, data exploration, format parsing) are available immediately.

**Why P2**: Requires nupm + Rust toolchain at build time (teardown after). Core migration ships independently.

**Acceptance Criteria**:

1. WHEN the image builds THEN the following plugins SHALL be installed to `/usr/lib/nushell/plugins/` via nupm (see D-04):

   | Plugin | Repo | nupm method |
   |---|---|---|
   | `nu_plugin_query` | nushell/nushell | `nupm install --git` or tarball fallback |
   | `nu_plugin_formats` | nushell/nushell | `nupm install --git` or tarball fallback |
   | `nu_plugin_gstat` | nushell/nushell | `nupm install --git` or tarball fallback |
   | `nu_plugin_file` | fdncred/nu_plugin_file | `nupm install --git` or pre-built binary fallback |
   | `nu_plugin_highlight` | cptpiepmatz/nu-plugin-highlight | `nupm install --git` or cargo fallback |
   | `nu_plugin_rpm` | yybit/nu_plugin_rpm | `nupm install --git` or cargo fallback |
   | `nu_plugin_explore` | amtoine/nu_plugin_explore | `nupm install --git` or cargo fallback |

2. WHEN the seeding service runs THEN it SHALL register each plugin not yet in `~/.config/nushell/plugin.msgpackz` via `nu --commands "plugin add /usr/lib/nushell/plugins/<name>"`
3. WHEN any plugin fails to load THEN nushell SHALL still start cleanly — plugin errors are non-fatal
4. WHEN the image builds THEN one RUN layer SHALL: install nupm + Rust toolchain, build all plugins requiring compilation, move binaries to `/usr/lib/nushell/plugins/`, tear down toolchain and nupm

**Independent Test**: `plugin list` shows all 7 registered; `view file.rs` renders syntax-highlighted Rust; `gstat` in a git repo returns a record; `^rpm -q nushell | nu_plugin_rpm` returns structured data.

---

### P2: carapace native completions

**User Story**: As a sideral user, I want context-aware tab completions for all my CLIs (git, kubectl, gh, podman, helm, mise, rg, etc.) across bash, zsh, and nushell so I don't have to remember flags and subcommands.

**Why P2**: Requires fetching a binary at build time. Completions are additive — core migration ships independently.

**Acceptance Criteria**:

1. WHEN the image builds THEN carapace x86_64 Linux binary SHALL be downloaded from the carapace-sh/carapace-bin GitHub release, sha256-verified, and installed to `/usr/bin/carapace` — same fetch+verify pattern as starship and nu_plugin_file (see D-05)
2. WHEN a bash interactive session starts THEN `sideral-cli-init.sh` SHALL source `<(carapace _carapace bash)` as the **sole** completion backend — any explicit `bash-completion` sourcing in the init chain SHALL be removed (guarded by `command -v carapace`)
3. WHEN a zsh interactive session starts THEN `sideral-cli-init.zsh` SHALL source `<(carapace _carapace zsh)` as the **sole** completion backend — any existing `compinit` call in `/etc/zshrc` SHALL be removed or replaced by carapace's init (guarded by `command -v carapace`)
4. WHEN nushell starts THEN the seeded `config.nu` SHALL contain the carapace external completer block wired to `$env.config.completions.external.completer` (guarded by `which carapace | is-not-empty`)
5. WHEN `carapace` is absent THEN all three shell inits SHALL load without error

**Independent Test**: In bash → `git <TAB>` → carapace completions appear; same in zsh; in nushell → `kubectl <TAB>` → completions; remove carapace binary → all three shells open without error.

---

## Locked Decisions

**D-01 — mise activate belongs in config.nu; mise shims belong in env.nu.**
Nushell's `mise activate nu` emits a `hooks.env_change.PWD` callback — nushell's per-directory version-switch hook. Hooks are config-phase; vendor autoload files run in env-phase and silently drop hook registrations. Additionally, `mise activate` only updates PATH when the hook fires (i.e., after first prompt render). Before that — and in any non-interactive context — mise-managed tools are unreachable. Fix: seeded `env.nu` prepends `~/.local/share/mise/shims` to PATH (guarded by path existence); seeded `config.nu` runs `mise activate nu` for hook-driven per-directory switching. Same two-layer fix applied to bash and zsh inits.

**D-02 — carapace replaces inshellisense.**
inshellisense conflicts with starship in nushell (documented open issue — integration requires being the last line in the init file, which the vendor autoload architecture breaks). inshellisense is also pre-1.0 after 2+ years. carapace: static Go binary (no runtime dep), 839+ CLIs, native tab-completion integration, actively maintained (v1.6.5), no known starship conflict. Delivery: pre-built x86_64 binary + sha256, same as starship.

**D-03 — all nushell config-phase constructs belong in config.nu, not vendor autoload.**
Three constructs require config-phase: (1) mise `hooks.env_change.PWD`, (2) `$env.config.keybindings` (Ctrl-P only — atuin owns Ctrl-R, Alt-S and Ctrl-G dropped as not worth dedicated bindings), (3) `$env.config.completions.external.completer` (carapace). fzf has no `--nushell` init — Ctrl-P must be hand-written in nushell keybinding syntax. All three live in the seeded `config.nu`.

**D-04 — nupm is the default plugin install method; per-plugin fallbacks apply.**
nupm `install --git` is the standard approach for all 7 plugins. nupm requires a `nupm.nuon` metadata file in the target repo — availability must be verified per-plugin at task time. Fallbacks: official nushell plugins (query/formats/gstat) fall back to extraction from the matching nushell release tarball; nu_plugin_file falls back to pre-built GitHub release binary + sha256; highlight/rpm/explore fall back to direct `cargo install`. All cargo builds happen in one RUN layer with toolchain teardown.

**D-05 — carapace delivered as pre-built binary, same pattern as starship.**
carapace-sh/carapace-bin publishes x86_64 Linux static Go binaries on GitHub releases. Fetch + sha256 verify at image build time, install to `/usr/bin/carapace`. No runtime dependency. Version pin in the install script.

**D-05a — for bash and zsh, carapace is the sole completion backend.**
bash: any explicit `bash-completion` sourcing in the init chain is removed; `source <(carapace _carapace bash)` takes over. zsh: `zsh-syntax-highlighting` (syntax coloring) and `zsh-autosuggestions` (history suggestions) are kept — they are not completion backends. Any `compinit` or `_comp_init` call in `/etc/zshrc` is removed; `source <(carapace _carapace zsh)` becomes the sole tab-completion driver. carapace calls compinit internally for zsh, so removing the explicit call avoids double-init slowdown. Both changes are guarded by `command -v carapace` so removing the binary degrades gracefully.

**D-06 — nu_plugin_explore version compatibility must be verified at task time.**
The nupm registry pins it to 0.93.0; nushell has had a built-in `explore` command since ~0.91. If the plugin is incompatible with the installed nushell version, drop it — the built-in covers the same functionality.

**D-07 — nushell aliases: drop ls/cat aliases; add `view` command via nu_plugin_highlight.**
nushell's built-in `ls` returns structured data — aliasing it to eza discards that. `cat` → `bat` doesn't translate to nushell idioms. Instead: keep built-in `ls`; add `def view [file: path] { open --raw $file | highlight }` in the vendor autoload file (guarded by `plugin list | where name == "highlight" | is-not-empty`). eza stays in the image for bash/zsh. bat stays for bash/zsh.

---

## Edge Cases

- WHEN a user has an existing `config.nu` THEN the seeding service SHALL leave it untouched
- WHEN `nu` binary is absent (user ran `rpm-ostree override remove nushell`) THEN `ujust chsh nu` SHALL document the risk — `usermod -s` will set the shell but login will fail
- WHEN a nupm build fails at image build time THEN the Containerfile RUN step SHALL fail the build (no silent skip)
- WHEN the agent detection guard fires in nushell THEN `view` SHALL remain available — nushell has no eza/bat aliases to suppress (see D-07)
- WHEN a user's login shell binary is absent (e.g., `/usr/bin/fish` removed on upgrade) THEN the seeding service SHALL auto-migrate them to `/usr/bin/zsh` — no manual intervention required

---

## Requirement Traceability

| Requirement ID | Story | Phase | Status |
|---|---|---|---|
| NSH-01 | P1: fish removal — packages.txt | Tasks | Pending |
| NSH-02 | P1: fish removal — sideral-cli-tools.spec Requires | Tasks | Pending |
| NSH-03 | P1: fish removal — sideral-shell-ux.spec + source file | Tasks | Pending |
| NSH-04 | P1: nushell package — packages.txt + sideral-cli-tools.spec | Tasks | Pending |
| NSH-05 | P1: vendor autoload (starship/atuin/zoxide/view/agent/EDITOR — no eza/bat aliases, no mise, no keybindings, no carapace) | Tasks | Pending |
| NSH-06 | P1: ujust chsh — replace fish with nu | Tasks | Pending |
| NSH-07 | P1: ujust tools motd update | Tasks | Pending |
| NSH-08 | P1: sideral-shell-ux.spec — add nushell init, remove fish init | Tasks | Pending |
| NSH-09 | P1: sideral-cli-tools.spec description/changelog update | Tasks | Pending |
| NSH-10 | P1 seed: sideral-shell-seed.service unit file | Tasks | Pending |
| NSH-11 | P1 seed: seed script — broken shell migration + ~/.bashrc + ~/.zshrc + nushell env.nu/config.nu + ~/.config/mise/config.toml | Tasks | Pending |
| NSH-12 | P1 seed: packaging in sideral-shell-ux.spec | Tasks | Pending |
| NSH-13 | P1 seed: WantedBy=default.target wiring | Tasks | Pending |
| NSH-14 | P2 plugins: nupm install for all 7 (per-plugin fallback strategy per D-04) | Tasks | Pending |
| NSH-15 | P2 plugins: install binaries to /usr/lib/nushell/plugins/ | Tasks | Pending |
| NSH-16 | P2 plugins: seeding service — plugin add registration for all 7 | Tasks | Pending |
| NSH-17 | P2 carapace: fetch binary + sha256 + install to /usr/bin/carapace | Tasks | Pending |
| NSH-18 | P2 carapace: bash — remove bash-completion sourcing, source carapace as sole backend | Tasks | Pending |
| NSH-19 | P2 carapace: zsh — remove compinit from /etc/zshrc, source carapace as sole backend | Tasks | Pending |
| NSH-20 | P2 carapace: external completer in seeded config.nu | Tasks | Pending |
| NSH-21 | P1 fix: bash/zsh inits — add mise shims to PATH unconditionally; guard `mise activate` for interactive shells only | Tasks | Implemented |
| NSH-22 | P1 seed: auto-migrate broken login shell — if binary absent, switch to /usr/bin/zsh | Tasks | Pending |

**Coverage**: 22 total, 0 mapped to tasks, 21 unmapped ⚠️ (NSH-21 already implemented)

> **Key interaction**: NSH-05 (vendor autoload) intentionally omits mise, keybindings, and carapace. NSH-11 (seeded config.nu) carries all three. This split is load-bearing — do not move config-phase constructs into vendor autoload.

---

## Success Criteria

- [ ] `ujust chsh nu` → nushell opens with starship prompt, all sideral tools wired, no errors
- [ ] Fresh user: nushell starts cleanly after first session; `git <TAB>` shows carapace completions immediately
- [ ] `fish` binary absent from the built image
- [ ] `view file.rs` renders syntax-highlighted Rust source
- [ ] `plugin list` shows all 7 plugins registered
- [ ] `just build` passes (bootc container lint) with carapace + plugins baked
