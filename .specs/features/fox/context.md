# fox — Locked Decisions

Decisions recorded during `/spec-create` 2026-05-10, revised 2026-05-11. Reference the decision ID in commits/PRs when revisiting.

---

## D-01 · Build a silverfox-owned CLI, not switch to another upstream tool

**Chose**: Ship `/usr/bin/fox` as a silverfox-owned operator CLI. v1 substrate: a tiny bash dispatcher around `just` + libexec bash scripts (substrate locked by D-02 + D-18; D-01 itself is only about owning the CLI surface, not the substrate).

**Considered**: an upstream operator-CLI as the canonical entry point (`task`, `mise tasks`, `direnv`); plain `just` invoked directly with no `fox` wrapper; doing nothing (keep `ujust`).

**Why**:
- **Upstream operator-CLIs bring opinions sideways to silverfox's needs.** `task` and `mise tasks` are project-task runners; silverfox wants system-lifecycle verbs (`upgrade`, `rollback`, `update`, `status`) plus a `home` namespace. The fit is awkward.
- **Plain `just` with no wrapper** forces users to type `just -f /usr/share/silverfox/silverfox.justfile <verb>`. Worse ergonomics than `ujust`; long enough that muscle memory fights it.
- **Doing nothing (keep `ujust`)** binds silverfox to the uBlue tooling graph (`libformatting.sh`, `ugum`, `Urllink`, the `/usr/share/ublue-os/justfile` import slot). The deferred `post-ublue` feature will drop all of that. Owning the dispatch surface beforehand decouples the two migrations.
- **Owning the binary name + Justfile** lets v2 grow `fox home sync` (declarative manifests + backend drivers) without renegotiating where the entry point lives. The substrate inside the wrapper is free to change (D-16 implementation note); the user-facing `fox <verb>` is the stable contract.
- **Cost paid.** A ~20-line bash dispatcher + a Justfile + libexec scripts. Less than 200 lines of bash total across the whole v1 feature.

**Supersedes**: prior version of D-01 (2026-05-10) and its 2026-05-11 update, both of which read "Chose: Write fox in TypeScript + Bun, ship a compiled standalone binary". The substrate choice was reversed in D-02 (Bun → bash). D-01 was reshaped to be about CLI ownership only; substrate lives in D-02 + D-18.

---

## D-02 · Bash dispatcher, not Bun / Rust / Go (reversed)

**Chose**: Plain bash for `/usr/bin/fox` — ~20 lines, no compilation, no embedded runtime. `case`-statement on `$1` + `exec just -f ${JUSTFILE} "$@"` (with one transform for `fox home <sub>` → `just home::<sub>`).

**Considered**: Bun + `bun build --compile` (originally chosen 2026-05-10, then narrowed to thin wrapper 2026-05-11, now reversed), Rust + clap, Go + cobra, Node + pkg/nexe.

**Why**:
- v1's dispatch logic is **20 lines of argv routing**. Embedding a 50–80MB language runtime in `/usr/bin/fox` to host 20 lines is pure overhead. Bash + `just` covers it natively.
- The "v2 evolution path" argument for Bun (per the prior version of this decision) was anticipatory: when v2's `fox home sync` parses TOML manifests + drives backends, *then* a typed runtime earns its keep. Pre-paying that cost in v1 means shipping 50MB of unused Bun runtime per image build. v2 reintroduces a compiled runtime if/when the substrate genuinely needs one (the Justfile recipe for `home::sync` can swap from `bash /usr/libexec/silverfox/sync.sh` to a compiled binary without changing the `fox` dispatch layer).
- Bash is universal: every Fedora image has `/bin/bash`, no extra `Requires`, no version pinning, no Renovate edge.
- No build-time substitution: `fox --version` reads `/etc/os-release` `VERSION_ID` at runtime via `awk`. Same answer as compile-time `--define`, simpler pipeline.
- Containerfile is dramatically simpler: dropped the `oven/bun:<pinned> AS fox-build` stage entirely. Only one tiny build-side stage remains (`fedora-minimal:44 AS man-build` for pandoc); everything else is direct `COPY` from build context.
- Testing simplifies: bash integration tests + shellcheck. No `bun test`, no `bun.lock`, no `@types/bun`, no `tsconfig.json`.

**Supersedes** the prior version of D-02 (2026-05-11) which chose Bun-compile for the thin wrapper layer. Reversed 2026-05-11 (same-day correction) after the wrapper layer's role narrowed to pure dispatch — at which point Bun no longer earns its 50MB+ cost in v1. The reversal is reversible itself: v2 may bring back a compiled runtime when there's substance to host.

---

## D-03 · Multi-stage Containerfile — only `man-build` stage (pandoc)

**Chose**: One tiny build-side stage: `FROM registry.fedoraproject.org/fedora-minimal:44 AS man-build` runs `microdnf install -y pandoc gzip && pandoc -s -t man /workspace/silverfox.md -o /out/silverfox.7 && gzip -9 /out/silverfox.7`. Final stage `COPY --from=man-build /out/silverfox.7.gz` plus direct `COPY` of `bin/`, `recipes/`, `libexec/` from build context.

**Considered**:
- Pandoc inline in Layer 2 (install pandoc → render → uninstall): bloats Layer 2's RUN block; rpm-ostree cleanup risk.
- Commit pre-rendered `silverfox.7.gz` to git: simplest container, but binary diff churn on every `.md` edit; CI must check drift.
- Drop manpage entirely: loses `man silverfox`; not aligned with the "Unix-native discovery" goal (D-14).

**Why**:
- Single source of truth for the manpage stays in `.md` (no git binary diffs).
- `fedora-minimal:44 + pandoc` is small (~150MB stage, ~30s download+install); cached on `silverfox.md` content alone via BuildKit.
- Same multi-stage pattern as the prior Bun design, just one stage instead of two and using a smaller base image.
- Bash dispatcher + Justfiles + libexec scripts need no compilation — direct `COPY` from build context to `/var/tmp/fox-prebuilt/`.

**Supersedes**: prior version of D-03 (2026-05-11) which had `FROM oven/bun:<pinned> AS fox-build` compiling the Bun binary + the manpage. With Bun dropped (D-02 reversed), the `fox-build` stage isn't needed; only the pandoc step survives, in its own much smaller stage.

---

## D-04 · `silverfox-fox` RPM owns `/usr/bin/fox` + manpage — bridge from multi-stage to rpmbuild

**Chose**: Ship `silverfox-fox.spec` at `os/modules/fox/rpm/silverfox-fox.spec`. The bash dispatcher, Justfiles, and libexec scripts are `COPY`'d **directly from the build context** into `/var/tmp/fox-prebuilt/`. The manpage is rendered in a tiny `man-build` stage (`fedora-minimal:44 + pandoc`) and bridged via `COPY --from=man-build /out/silverfox.7.gz /var/tmp/fox-prebuilt/`. `silverfox-fox.spec`'s `%install` reads from `/var/tmp/fox-prebuilt/` and writes to `%{buildroot}/usr/bin/fox` + manpage + recipes + libexec. `Source0:` is the empty synthesized tarball (no `src/` tree as source — `src/` is consumed by the `man-build` stage and direct `COPY`s instead).

**Considered**:
- Non-RPM-tracked binary placed via `COPY --from` directly to `/usr/bin/fox` (no spec).
- Build the binary outside the Containerfile in a CI step, upload as release artifact, fetch via curl in the build (matches an earlier starship pattern).

**Why**:
- **The starship precedent is gone.** When the current spec draft was first written, STATE.md described starship as "binary-in-`/usr/bin` without an RPM" — used as the anchor for "silverfox has a pattern for non-RPM binaries." Reality: starship migrated to Terra-RPM at the F44 bump (`silverfox-cli-tools.spec` declares `Requires: starship`; Terra repo shipped via `/etc/yum.repos.d/terra.repo` is persistent so `rpm-ostree upgrade` pulls updates between rebuilds). Without that precedent, the "no-RPM exception" rationale loses its load-bearing example.
- **Consistency.** Every other silverfox-shipped artifact in `/usr/bin/` (and elsewhere) is RPM-owned. `rpm -qf <path>` returning the owning package is a mental model the entire image upholds. Making fox an exception means every reader has to remember "ah, except fox" — a corrosive special case.
- **Override-remove path.** `rpm-ostree override remove silverfox-fox` becomes the canonical way for someone deriving silverfox to ship a slimmer image without the CLI. Without an RPM, derivatives would have to fork the Containerfile to skip the `COPY --from`.
- **Cleanup unit.** Manpage + bash dispatcher + Justfiles + libexec scripts as a single RPM means removal is one operation; integrity check (`rpm -V silverfox-fox`) covers all six paths.
- **Cost paid.** The build pipeline gets one extra non-obvious wrinkle: the `/var/tmp/fox-prebuilt/` bridge between the multi-stage `man-build` output and the rpmbuild step. Documented in Containerfile comments. Same shape as Adobe / Microsoft vendor-binary-into-RPM patterns; not exotic. Adds ~30 lines of Containerfile + a spec file.
- **What "RPM ownership lets `rpm-ostree upgrade` pull updates" doesn't buy here.** Fox is silverfox-internal — no external repo for fox, image rebuild IS the upgrade. So the dynamic-update benefit of RPM ownership doesn't apply. But static-ownership benefits (rpm -qf, rpm -V, override-remove, cleanup unit) do, and they're enough to justify the wiring.

**Supersedes** the earlier version of D-04 (recorded 2026-05-10) that chose non-RPM-tracked under the assumption that the starship precedent was current. Reversed 2026-05-11 after the starship-on-Terra status was verified. Body further updated 2026-05-11 to reflect the bash-pivot (D-02 reversal): no `fox-build` stage, only `man-build`.

---

## D-05 · `/etc/silverfox/` system config root retired (was: reserved for v2 manifests)

**Chose**: No system-level reservation of `/etc/silverfox/`. All declarative config (v2 manifests for flatpaks/dconf) lives in `~/.config/silverfox/manifests/` — user-domain only.

**Considered**: Reserve `/etc/silverfox/` for image-level manifests + user manifests at `~/.config/silverfox/` overriding/extending. Two-source model.

**Why**:
- Two-source models reintroduce the drift+diff problem chezmoi was retired for.
- Single-user image: there's no value in image-level manifests separate from user-level. Whatever the user declares IS the image's runtime config.
- Single source of truth in `~/.config/silverfox/` mirrors the dotfile single-source-of-truth in `~/.config/silverfox/stow/`. Consistency.
- v2 manifest-load helpers (whatever substrate D-16 ends up picking) read from user paths only; no system path branch to maintain.

**Supersedes**: the prior version of this decision (recorded 2026-05-10) that reserved `/etc/silverfox/`.

---

## D-06 · No CLI framework in v1 (was: gunshi)

**Chose**: No CLI framework, no TS. `/usr/bin/fox` is ~20 lines of bash: a `case` statement on `$1` dispatching to `exec just -f $JUSTFILE "$@"`, with one transform for `fox home <sub>` → `just home::<sub>`. Help/listing delegated to `just --list`.

**Considered**: gunshi (originally chosen for the TS-native draft), citty, clipanion, cac, yargs — all moot once the dispatcher pivoted to bash (D-02 reversal + D-18 sharpening).

**Why**:
- With v1's bash-dispatch pivot (D-18), there is no command tree to model in code — every verb is a `just` recipe. A framework would parse argv only to immediately re-emit it for `just`. Pure ceremony.
- Help output is `just --list`'s output; no need for in-binary help generation.
- Subcommand namespacing (`fox home factory-reset` → `just home::factory-reset`) is a single `if [[ "$1" == "home" ]]` branch in `bin/fox`.
- v2 will re-evaluate: when `fox home sync` parses manifests and drives backends, a framework may re-enter for that subtree alongside whatever substrate v2 picks (bash + jq, TS, Rust). Decision deferred to that phase.

**Supersedes**: prior version of D-06 (recorded 2026-05-10) that chose gunshi as the v1 framework, plus the intermediate version (2026-05-11) that still framed the dispatcher as `cli.ts`. Final reversal 2026-05-11 with the bash pivot (D-02 reversed, D-18 sharpened).

---

## D-07 · `read -p` fallback only — `tv` deferred (was: `tv` as the fox-CLI picker)

**Chose**: `libexec/chsh.sh` uses bash `read -p` for the no-arg prompt. It probes `command -v tv` first so that if `tv` ever lands on `$PATH` (user-installed, future Terra package, etc.) it auto-upgrades the prompt; no code change needed when that day comes. `tv` is NOT in silverfox's package list and NOT a Requires of any silverfox RPM.

**Considered (and originally chosen)**: ship `tv` (television, Rust fuzzy picker) as a `silverfox-cli-tools` package and use it as the canonical picker for fox prompts. Verified open concern in this section — confirmed 2026-05-11 that `tv`/`television` is NOT in `terrapkg/packages` under `anda/{tools,apps,misc,devs,desktops,system}` (6 categories scanned). Also not in Fedora 44 main.

**Why the reversal**:
- Sources don't exist: Terra COPR-layering or upstream-binary-fetch would resurrect a pattern STATE.md just retired (starship was the lone non-RPM binary precedent and migrated to Terra-RPM at the F44 bump per `os/modules/cli-tools/rpm/silverfox-cli-tools.spec` 0.0.0-10). Re-establishing that exception for one shell prompt is corrosive cost.
- v1 has exactly one fox prompt today (`chsh` shell-pick). `read -p` is universal — works in every TTY without an extra binary on disk. The "two pickers, two surfaces" framing was speculative; v1 has one surface.
- fzf stays in cli-tools for shell-level bindings (Ctrl-P, Ctrl-G, Alt-C, atuin's picker) — unchanged.
- The `command -v tv` probe in `chsh.sh` is one line of bash. Cost of leaving it is ~zero; gain is future-proofing — when/if `tv` lands as a Fedora/Terra RPM (or the user installs it), fox automatically upgrades the UX.

**Supersedes**: the prior version of D-07 (2026-05-11) that picked `tv` pending repo verification. Reversed same-day when the verification showed no source.

---

## D-08 · CI gates `shellcheck` + bash integration tests before image build

**Chose**: GH Actions runs `just fox-lint && just fox-test` as a pre-flight job on a stock Ubuntu/Fedora runner (no language toolchain setup — bash + shellcheck are pre-installed). Image-build matrix runs only on green.

**Why**:
- Pre-flight catches obvious regressions in <5s before burning the 10-12min image build matrix (smaller window than the original Bun-based estimate; bash + shellcheck is faster than a TS toolchain bootstrap).
- No defensive in-Containerfile re-run: the `man-build` stage runs pandoc only; there's no `fox-build` stage anymore (D-02 reversal). The pre-flight job is the sole gate.
- Two-layer testing (pre-flight + `bootc container lint` at the end of image build) matches the "fail fast, fail loud" pattern already used elsewhere.

**Supersedes**: prior version of D-08 (2026-05-11) that gated `bun test` via `oven/setup-bun@v2` with a pinned Bun version. With Bun gone, the toolchain bootstrap step goes too — runs are bash-native and faster.

---

## D-09 · No bash/zsh completions for `fox` in v1

**Chose**: No shipped completions.

**Why**: Nine commands fit motd-recall. Retrofit is low-effort when v2 surface grows — `just --list` already enumerates recipes, so a hand-rolled bash completion that calls `just --list` and parses verbs is ~20 lines. carapace (silverfox's existing tab-completion backend) covers many CLIs; user adds a carapace spec for fox there if motivated. Deferred to v1.1.

---

## D-10 · Drop ujust + legacy artifacts in the same PR as fox introduction

**Chose**: `60-custom.just`, `silverfox-cli-init.sh` family, `silverfox-stow-defaults` RPM, `rclone-gdrive.service`, `/usr/share/silverfox/stow/` all deleted in the same atomic image change that ships `fox`.

**Considered**: stage rollout (ship fox first; remove ujust later); stub redirects (`ujust chsh` → "use `fox chsh`").

**Why**:
- Atomic images make staged rollouts costly: each image release is fully replaced.
- One-person user base — no community to migrate gradually.
- Brief friction window (`ujust chsh` → "recipe not found") acceptable, documented in Edge Cases.
- Stub redirects still depend on uBlue helpers (`libformatting.sh`, `ugum`) which `post-ublue` will drop. Clean break now.

---

## D-11 · `/etc/skel` as user-config seam — Model C over Models A / B / D

**Chose**: Ship the full stow source tree at `/etc/skel/.config/silverfox/stow/{bash,zsh,mise,ghostty,zed}/` with pre-farmed relative symlinks at `/etc/skel/{.bashrc,.zshrc,.config/mise/config.toml,.config/ghostty/config,.config/zed/settings.json}`. `useradd` copies the whole skel tree (symlinks preserved via cp -a). Dotfiles are user-domain from then on — silverfox never touches them again.

**Considered**:
- **Model A** (stow-pull): image seed at `/usr/share/silverfox/stow/` + `fox stow pull` overrides home destructively.
- **Model B** (system configs + opt-in source): silverfox config at `/etc/silverfox/<shell>/<rc>`, user's rc has a one-line source statement; `fox source <shell>` writes the line.
- **Model D** (chezmoi-style state machine): user-writable copy of seed with diff/merge on image upgrade.

**Why**:
- **Model A** keeps the seed at `/usr/share/silverfox/stow/` (read-only ostree) — user edits via copy-out (the "break symlink" dance) which is the ergonomics problem the current setup has.
- **Model B** still implicit-injects via auto-sourcing `/etc/silverfox/<shell>/<rc>`. User's `~/.bashrc` is empty plus one source line; the real config is invisible at `/etc/`. Adds `fox source <shell>` for migration only.
- **Model D** reintroduces a state machine for drift (which silverfox retired with chezmoi 2026-05-10).
- **Model C** wins because:
  - Dotfiles are real, user-visible, user-editable from day 1. `cat ~/.bashrc` shows actual content.
  - "What is silverfox doing in my shell?" is answered by `ls ~/.config/silverfox/stow/`.
  - The "no auto-update for existing users" cost is acceptable on a one-person image. `fox home factory-reset` (v1) and per-pkg / `fox home sync` (v2) give explicit re-seeding when wanted.
  - Symlinks-into-stow-tree preserves stow ergonomics. **User-added stow packages live OUTSIDE the silverfox subtree** — recommended layout `~/.config/dotfiles/<pkg>/`, applied with `stow --target=$HOME --dir=$HOME/.config/dotfiles <pkg>`. This matches FOX-38 and survives `fox home factory-reset` (which wipes only `~/.config/silverfox/`, `~/.config/mise/`, `~/.config/ghostty/`, `~/.config/zed/` — see FOX-08 scope). An earlier draft of this decision suggested adding user packages under `~/.config/silverfox/stow/` itself; that path is destructive on factory-reset and should not be used.
  - Aligns with the project's simplification arc (nix retired, niri retired, chezmoi → stow, nushell removed, fish removed).

---

## D-12 · bash + zsh only — fish dropped

**Chose**: Two shells: bash (default) and zsh. Fish removed from `silverfox-cli-tools` Requires, `chsh` allowlist, `/etc/skel`, and `os/modules/cli-tools/packages.txt`.

**Considered**: keep fish (status quo); drop fish from cli-tools but keep its config in /etc/skel for users who install fish themselves.

**Why**:
- One person uses silverfox. They use bash + zsh. Three-shell parity was speculative.
- Fish requires its own init wiring (different syntax for everything), AI-agent guard duplication, separate config.fish, test coverage. Maintenance tax meaningful.
- Nushell was dropped 2026-05-10 for similar reasoning (per ROADMAP). Fish drop completes the simplification.
- Users wanting fish `rpm-ostree install fish` and manage their own dotfiles.
- `chsh` allowlist hardened: FOX-06 refuses `fish` with "try: bash, zsh" — prevents accidental switch to a shell silverfox no longer wires.

---

## D-13 · gdrive integration retired entirely

**Chose**: Delete `rclone-gdrive.service`, remove `rclone` + `fuse3` from `silverfox-cli-tools`, remove all motd/README/spec references.

**Considered**: keep `rclone` + `fuse3` packages; only remove systemd unit (user mounts manually).

**Why**:
- Auto-mount-on-login UX was load-bearing for one workflow; removing the unit removes the value.
- `rclone` + `fuse3` are large deps (FUSE userspace + rclone's full backend matrix) that serve only this one workflow when shipped by silverfox.
- Users wanting Google Drive `rpm-ostree install rclone fuse3` and write their own user unit. 10-line README appendix; silverfox doesn't need to own it.

---

## D-14 · Cheatsheet via `man 7 silverfox` + thin `fox cheatsheet` wrapper

**Chose**: Move cheatsheet content to `/usr/share/man/man7/silverfox.7.gz`, generated from `os/modules/fox/src/man/silverfox.md` via pandoc in the `man-build` Containerfile stage. `fox cheatsheet` execs `man 7 silverfox`.

**Considered**: keep `fox tools` printing motd-style dump; multiple `fox help shell` / `fox help containers` subcommands.

**Why**:
- Unix-native discovery: `apropos silverfox`, `whatis silverfox`, `man -k <topic>`.
- Paginated by default via man's `less` integration.
- Searchable in-page (`/zoxide`).
- No code duplication in the binary; cheatsheet text is one Markdown file.
- Discoverability inside fox preserved: `fox cheatsheet` for the obvious-from-fox path; both routes reach the same artifact.

---

## D-15 · Module reorg: `home/` + `fox/` new, `shell-ux/` narrows, `dotfiles/` retires

**Chose**:
- **`home/`** — new module, RPM `silverfox-home`. Owns `/etc/skel/.config/silverfox/stow/*` (five packages: bash, zsh, mise, ghostty, zed) + the five pre-farmed symlinks at `/etc/skel/*`.
- **`fox/`** — new module, RPM `silverfox-fox`. Bash dispatcher (`bin/fox`) + Justfiles (`recipes/*.just*`) + libexec scripts (`libexec/*.sh`) + manpage source (`man/silverfox.md`) + tests (`tests/*.sh`) + `rpm/silverfox-fox.spec`. The `man-build` Containerfile stage runs pandoc to render the manpage; everything else is `COPY`'d directly from build context. `COPY --from=man-build /out /var/tmp/fox-prebuilt/` (manpage only) plus direct `COPY os/modules/fox/src/{bin,recipes,libexec} /var/tmp/fox-prebuilt/` bridges artifacts into a mutable path; `silverfox-fox.spec` `%install` reads from there. See D-04.
- **`shell-ux/`** — narrows. RPM name `silverfox-shell-ux` stays (per stable-RPM-name policy from STATE.md "Sub-package names kept stable across the refactor for upgrade safety"). Content shrinks to `/etc/user-motd` + `/etc/mise/config.toml` + `/etc/profile.d/silverfox-shell-migrate.sh` (login-shell rescue, retained through v1.0 minimum).
- **`dotfiles/`** — entire module deleted. `silverfox-stow-defaults` RPM retired (not renamed).

**Considered**:
- **Minimal reorg**: keep `shell-ux/` grab-baggy (motd + skel + mise config + everything). Only add `fox/` and delete `dotfiles/`.
- **Conceptual split with single RPM**: still one `silverfox-shell-ux` but with sub-dirs for skel/motd/system. Requires build.sh changes.

**Why**:
- "Defaults raiz vs defaults stow" is a real conceptual split — system-level configs (motd, mise system behavior, yum repos) vs user-domain seed (`/etc/skel`'s stow tree + symlinks). Splitting modules tracks the split.
- `silverfox-home` makes "what does silverfox put in my home?" answerable via `rpm -ql silverfox-home` — one command, one canonical answer.
- `silverfox-home` may grow to `Requires: stow` semantically (capturing that the stow binary is meaningful tooling for the seeded source tree); v1 keeps stow in cli-tools globally but the dependency can move later without breaking compatibility.
- `shell-ux/` narrows to coherent scope: configs that NEVER touch user home.
- `post-ublue` (next feature) will mostly touch `shell-ux/` (motd, system-level shell concerns); `home/` stays intact. Module boundaries help the next refactor.
- Adding 2 RPMs / 2 modules is cheap (build-rpms.sh autodiscovers `os/modules/*/rpm/`).

---

## D-16 · `fox home` modeled after nix's home-manager — `factory-reset` in v1, `sync` (with contract) in v2

**Chose**: Frame `fox home` as the silverfox equivalent of home-manager. v1 ships **exactly one verb**: `home factory-reset` (imperative hard wipe + reseed from `/etc/skel/`, scope-limited to depth ≤ 2 under skel). v2 will introduce `home sync` reading TOML manifests from `~/.config/silverfox/manifests/` and reconciling via backend-specific drivers. The `SyncCommand<T>` contract for v2 reconciliation is **deferred** — NOT shipped as an empty interface in v1.

**Considered**:
- Name the namespace `defaults` (narrower semantic — captures dotfile defaults only, no future sync surface).
- Name the namespace `stow` (ties to the underlying tool — `fox stow reset` reads ambiguously).
- Name the namespace `skel` (ties to the seed location — ignores the CLI verb surface).
- Name the verb `reset` (intermediate design with `--dry-run` / `--diff` / per-package / SyncCommand impl). Rejected during iteration: factory-reset's hard semantic (rm + cp) does not meaningfully exercise diff/apply separation, and per-package complicates the mental model. "Factory reset" is universally understood; the flag surface collapses to `--yes` only.
- Replicate home-manager generations + native rollback inside fox.
- Ship the `SyncCommand<T>` interface in v1 with `home factory-reset` as the concrete impl. Rejected: the contract would be theater (the only impl uses no real diff/apply distinction), and locking the type shape without a real reconciliation backend (v2's flatpak/dconf drivers) risks getting `T`'s constraints wrong.

**Why**:
- `home` captures intent (user-rooted config), not mechanism (stow / file copy). Extends cleanly to future surface.
- The home-manager comparison is intentional and load-bearing: nix-home failed on Fedora atomic 42+ for substrate reasons (composefs/SELinux/post-upgrade), not because the home-manager UX was wrong. `fox home` recovers the UX (declare → reconcile) with a substrate chosen at v2 time alongside the first real backend — but only when the substrate actually warrants the cost.
- Generations / rollback NOT replicated: users `git init` in `~/.config/silverfox/`; selective rollback is `git checkout <path>`; full revert to image defaults is `fox home factory-reset`. Avoids a state machine inside fox.
- **`factory-reset` is intentionally NOT a `SyncCommand<T>` impl.** The flag set is `--yes` only (no `--dry-run`, no `--diff`). The 4-method contract (readCurrent/readDesired/diff/apply) maps poorly onto an unconditional `rm -rf + cp -a`. Shipping the interface in v1 with no real consumer would be premature abstraction; designing it without exercising it against a real reconciliation backend risks getting the type-parameter shape wrong. Deferring to v2 keeps v1 lean and lets the contract emerge from real use.
- The `factory-reset` name (vs `reset`) is self-documenting: matches phones/routers/etc. ergonomics, signals "destructive, image-default revert" at first read. No one runs `factory-reset` thinking it's selective.

**Supersedes**: the prior version of D-16 (recorded 2026-05-10) that framed v1's `home reset` as the first `SyncCommand<T>` implementation with `--dry-run`/`--diff`/`apply` flag set. Reversed 2026-05-11 after iteration on the user-facing surface concluded that (a) a hard reset is the correct v1 shape and (b) the contract has no v1 consumer that meaningfully exercises it.

**Implementation note** (per D-18): `factory-reset` lives in `/usr/libexec/silverfox/home-factory-reset.sh` (bash, ~40 lines), invoked by a one-line Justfile recipe in `home.just`. v2 may re-host this and the future `sync` backends in whatever substrate the `fox home sync` work picks at that time (bash + jq, Rust, Go, or — if real complexity emerges — a typed runtime); the substrate choice is genuinely open after D-02 reversed Bun. The Justfile recipe for `home::sync` can swap from `bash /usr/libexec/silverfox/sync.sh` to a compiled binary without touching the `fox` dispatcher.

---

## D-17 · Manifests in `~/.config/silverfox/manifests/`, not `/etc/silverfox/`

**Chose**: v2 declarative manifests live in `~/.config/silverfox/manifests/<thing>.toml` only. No system-level manifest path; no two-source merge.

**Considered**: system manifests at `/etc/silverfox/<thing>.toml` overridden/extended by user manifests; image ships defaults under `/etc/skel/.config/silverfox/manifests/`.

**Why**:
- Two-source models reintroduce drift + diff complexity (chezmoi territory).
- Single-user image: user manifests ARE the system intent. No layering needed.
- v1 ships no manifests at all (out of scope per spec). v2 adds the first manifest type (flatpaks) and the corresponding `fox home sync` backend.
- `/etc/skel` may eventually ship example manifests as seeds, copied to user home at useradd time — same model as the stow tree. But this is v2 detail, not v1.

---

## D-18 · v1 fox = tiny bash dispatcher around `just` + libexec bash scripts

**Chose**: `/usr/bin/fox` is ~20 lines of bash. Reads `SILVERFOX_JUSTFILE` env (default `/usr/share/silverfox/silverfox.justfile`). `case` on `$1` handles `--help`/`--version`/no-arg/`home <sub>`/everything-else. All non-special verbs are dispatched via `exec just -f "$JUSTFILE" "$@"`. The `home <sub>` branch transforms argv to `just home::<sub>` (just's module syntax). Verb logic lives in Justfile recipes; non-trivial logic (factory-reset, chsh) shells out from recipes to `/usr/libexec/silverfox/*.sh` bash scripts.

**Considered**:
- **Heavy TS-native CLI** (specced 2026-05-10): gunshi + consola + @iarna/toml + `commands/<verb>.ts` + `lib/skel.ts`. Each verb implemented in TS, subprocess via `lib/exec.ts`.
- **Thin Bun wrapper** (specced 2026-05-11, since superseded): ~30-line `cli.ts` using `Bun.$`, compiled to 50–80MB binary. Same dispatch shape as the current bash design, but in TS.
- **Pure-bash with no `/usr/bin/fox`**: users run `just -f /usr/share/silverfox/silverfox.justfile <verb>` directly. No wrapper binary.
- **Bash fox without just** (cut out the just layer): `case` on verb in `fox` itself, each branch runs the underlying tool. No Justfile.

**Why**:
- **20 lines of dispatch don't need a runtime.** Bun-compile would have shipped a 50–80MB runtime to host 20 lines of routing — pure cost, no benefit.
- **`just` chosen vs no-just**: separating recipes from fox makes them inspectable (`just --list`), testable (run a recipe in isolation), and editable without touching the dispatcher. A Justfile is a better recipe format than a 9-arm bash `case` statement. Plus `just --list` gives free `fox --help` output.
- **`just` chosen vs `ujust`**: `ujust` is uBlue's wrapper around just adding `libformatting.sh`/`ugum`/`Urllink`. Silverfox wants plain just (standalone Rust binary, stock Fedora) without the uBlue tooling. `post-ublue` will drop ujust entirely; plain just stays.
- **Bash for the bash-shaped parts.** Factory-reset is a skel-walk + rm + cp + interactive prompt — bash's natural domain. ~40 lines of bash replaces ~80 lines of `Bun.spawn`/`readdir`/`unlink`/`copyFile` doing the same thing.
- **`/usr/bin/fox` keeps short-name UX.** Without it, users would type `just -f /usr/share/silverfox/silverfox.justfile <verb>` — worse than `ujust`. With it, `fox <verb>` is the dispatch surface and matches the motd guidance.
- **No CLI framework needed** (D-06): `just --list` does the help; `case` does the routing.

**Cost paid**:
- Process tree depth: three layers for direct-exec verbs (`fox (bash) → exec just → exec flatpak/rpm-ostree`), four for verbs that go through the recipe shell (`fox cheatsheet`: `fox (bash) → exec just → bash (recipe shell) → exec man`). `exec` at each layer collapses, so post-collapse the leaf tool is the only live process. Negligible perf; slight indirection when debugging exit codes — `set -x` traces stay readable because `exec` keeps the PID stable.
- Two artifact types in `os/modules/fox/src/` (bash + just recipes). Acceptable — each is the right shape for its layer.
- Runtime dep on `just` (declared via `Requires: just` in `silverfox-fox.spec`). just is stock Fedora; cost is one RPM dep edge.

**Reversal trigger**: if v1 fox ever grows substance beyond dispatch (e.g., real argv validation, structured output reformatting, typed reconciliation), absorb it into either a compiled runtime (Bun/Rust/Go) or into the libexec layer (more bash scripts). Don't try to make bash do too much; don't reach for Bun until there's substance to host. v2's `fox home sync` is the natural moment to revisit substrate choice.

**Supersedes**: the intermediate "thin Bun wrapper" version of D-18 (2026-05-11) which kept Bun for the dispatch layer. Sharpened same-day: with no v1 dispatch logic that benefits from a runtime, bash is the correct floor.

---

## Open implementation concerns (not blocking spec)

- **Existing fish users**: anyone whose login shell is `/usr/bin/fish` will have a dangling shell after rebase if fish is uninstalled. Detection in a pre-rebase script could help; probably overkill. README release-notes flag it.
- **`exec` chain through bash → just → underlying tool**: `fox cheatsheet` chain is `fox (bash) → exec just → bash (just's recipe shell) → exec man`. `exec` at each layer collapses the process tree; man becomes the only live process. Verify SIGINT/SIGTERM propagation in first PR (especially during man's pager).
- **Manpage section choice**: man 7 (miscellaneous — describes ENVIRONMENT) over man 1 (commands — describes a binary). `fox.1` would be a separate manpage for the binary itself (deferred per D-09).
- **`fox upgrade` reboot reminder timing** (resolved): keep the recipe's `@echo "Reboot to apply the staged deployment."` trailer even though rpm-ostree usually prints its own hint. Reasons: (a) symmetry with `fox rollback`'s identical trailer; (b) rpm-ostree's wording has changed across releases and may change again — silverfox's trailer is a stable contract; (c) overlap is harmless. Revisit only if rpm-ostree starts forcing its own output to stderr or if duplicate lines confuse parsers.
- **`home-factory-reset.sh` TTY detection**: bash `[[ -t 0 ]]` is the predicate. Verify reliability across local terminal, SSH, CI runners (GitHub Actions), and piped invocations in first PR. Edge case: stdin a regular file → `-t 0` is false → exit 1 (correct).
- **`cp -a` conflict semantics**: GNU coreutils `cp -a` does NOT unconditionally remove the destination before copying (it merges into existing dirs, fails on type mismatches). `home-factory-reset.sh` uses explicit `rm -rf` then `mkdir -p` then `cp -a`. Could alternatively use `cp -a --remove-destination`; first PR decides which reads cleaner.
- **What `rpm -V silverfox-home` does to symlinks**: needs verification that the spec preserves symlinks-as-symlinks (no auto-resolve on install). `%files` declaring relative symlink targets should work; sanity-test in first PR.
- **Fake-just stub for `fox.test.sh`**: stub script printing its args to stderr + exiting with caller-controlled code (via env var) is the cleanest mock pattern. First PR pins the exact stub interface used across tests.
- **PTY allocation in tests**: FOX-44's prompt-branch tests rely on `script -qc '<cmd>' /dev/null` (util-linux) to allocate a pseudo-terminal so the script's `[[ -t 0 ]]` check passes. Verify GH Actions runners ship `script(1)` (they do on stock Ubuntu/Fedora images); if a future runner lacks it, fall back to `expect` or `python -c 'import pty; pty.spawn(...)'`.
- **`bash` interpreter version**: `[[ -t 0 ]]`, `mapfile -t`, here-strings (`<<<`) require bash ≥ 4. Fedora ships bash 5; safe. Shebang `#!/usr/bin/env bash` (not `#!/bin/sh`) makes this explicit.
- **`Source0` empty-tarball pattern**: `silverfox-fox.spec` + `silverfox-home.spec` both claim "same synthesized empty tarball as other no-`src/`-as-source specs in silverfox". Verify this pattern actually exists in `os/lib/build-rpms.sh` or an existing spec. If not, the first PR establishes the convention (e.g., generate `/tmp/empty.tar.gz` once in build-rpms.sh, point all `Source0:` entries at it).
- **`rpm-ostree db diff` "no pending deployment" behavior**: FOX-14 asserts rpm-ostree handles this natively. Verify exact behavior: does it exit 0 with empty stdout, exit 0 with `No pending deployment.` message, or exit non-zero? Adjust the recipe trailer (e.g., grep + echo) only if rpm-ostree's native message is unsatisfying. First PR sanity check.
- **`tv` (television) package availability** — **resolved 2026-05-11**: not in Terra (verified across `anda/{tools,apps,misc,devs,desktops,system}`) and not in Fedora 44 main. Picked option (c) — drop the picker dep; `chsh.sh` falls back to `read -p` and keeps a `command -v tv` probe so a future user-installed `tv` upgrades the prompt automatically. See D-07.
- **`/etc/zshrc` reclaim after shell-ux narrowing**: FOX-23 deletes the silverfox-customized `/etc/zshrc` so the stock `zsh` package owns the path again. RPM file-ownership transfer can be sticky: if `silverfox-shell-ux`'s `%files` drops a path that `zsh` already claims, `rpm-ostree upgrade` may need `--allow-overwrite` (or the spec may need `%ghost /etc/zshrc` for one release as a soft handoff). Test on an existing rebased VM in the first PR; if upgrade balks, ship the `%ghost` workaround in the same release and remove it in the next.
