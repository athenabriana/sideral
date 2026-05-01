# chezmoi-home — Locked Decisions

Decisions recorded during `/spec-create` 2026-05-01. Reference the decision ID in commits/PRs when revisiting.

---

## D-01 · Drop nix entirely from the user-config layer

**Chose**: Retire `nix-home` before VM verification. No nix-installer, no `/nix` store, no nix-daemon, no home-manager.

**Considered**:
- Ship `nix-home` as designed and discover frictions in production.
- Make `sideral-nix` a removable rpm-ostree sub-package so the user can opt out per-deployment if it bites.
- VM-test current `nix-home` for one hour first, then decide based on empirical signal.

**Why**:
- Three documented, still-unresolved frictions specifically affect Fedora atomic 42+:
  1. composefs vs nix-installer ostree planner — [`nix-installer#1445`](https://github.com/DeterminateSystems/nix-installer/issues/1445), [`nix#11689`](https://github.com/NixOS/nix/issues/11689). composefs makes `/` immutable; the planner can't `chattr -i /` to create `/nix`. Workaround: `root.transient=true` in `/etc/ostree/prepare-root.conf` or fstab surgery.
  2. SELinux mislabel of `/nix` store paths — [`nix-installer#1383`](https://github.com/DeterminateSystems/nix-installer/issues/1383), open since 2023, no upstream fix as of late 2025. Recurs after every `nix profile install`. Workaround: perpetual `restorecon -Rv /nix`.
  3. `/nix` and nix-daemon disappearing after `rpm-ostree upgrade` on F42+ — multiple Universal Blue forum reports ([`8500`](https://universal-blue.discourse.group/t/nix-installation-is-gone-after-getting-fedora-42/8500)). Some users abandoned nix entirely.
- silverblue-main:43 is in the impact zone for all three.
- Nix's unique value on atomic Fedora is per-user `nix profile install` for ad-hoc CLI tools — a workload sideral does not exercise heavily. The declarative-home-config benefit is recoverable via chezmoi.
- Cost of pivoting now is low: nix-home is implemented but not VM-verified — no shipping users to migrate. Cost of pivoting later (post-ship) compounds.
- User explicit fear ("issues and conflicts" + "lots of packages missing") aligned with the research findings; the empirical risk justified the decision without needing a confirmatory VM test.

---

## D-02 · chezmoi over yadm as the dotfile manager

**Chose**: chezmoi (Go binary, render-and-apply, separate source tree at `~/.local/share/chezmoi/`).

**Considered**:
- yadm (bash + bare git, worktree IS `$HOME`) — initially preferred for personal edit ergonomics ("`vim ~/.bashrc` *is* editing the source").
- stow / dotbot / rcm — surveyed and ruled out (symlink-era tools, no templating or weak templating, rcm stale since 2024-08).

**Why**:
- yadm wins on personal edit ergonomics (no source-tree round-trip).
- chezmoi wins on the axes that matter for sideral's long-term collaboration model:
  - **Agent-friendliness**: explicit source tree, filename-encoded intent (`encrypted_`, `private_`, `executable_`, `dot_`), `chezmoi diff` / `verify` / `--dry-run` give structured signal that AI agents can use safely.
  - **Community recognition**: 19.5k stars vs ~5k, monthly release cadence (v2.70.2 Apr 2026), 226 vs 58 contributors. The de-facto "standard answer" for dotfile management in 2026.
  - **Templating**: full Go `text/template` + sprig, vars including `.chezmoi.osRelease.variantId` (Silverblue/Bluefin/Aurora aware out of the box).
  - **Secrets**: 17 first-class backends including age, gpg, libsecret keyring, 1Password, Bitwarden — all as template funcs (per-file encryption with reviewable diffs vs yadm's opaque tar-archive).
  - **Atomicity**: per-file atomic write + dry-run/diff/status/verify primitives. yadm has only git.
- User explicitly weighed personal ergonomics against agent + community fit and let agent-fit override. Captured as a durable preference pattern in memory (`feedback_tool_choice_pattern.md`).

---

## D-03 · CLI tools as Fedora-layered RPMs (no flatpak, no nix)

**Chose**: All 14 CLI tools (`chezmoi mise starship atuin fzf bat eza ripgrep zoxide gh git-lfs gcc make cmake`) plus `code` installed as RPMs via Fedora's repos, `mise.jdx.dev/rpm/`, or `packages.microsoft.com`. Bundled into a `sideral-cli-tools` meta-package owned by sideral.

**Considered**:
- Flatpak — limited surface (CLI tools rarely have flatpaks; sandbox conflicts with shell-tool nature of these binaries).
- Distrobox-only (host stays clean) — breaks the "fresh shell after rebase has all tooling" UX that sideral has shipped since v1.

**Why**:
- All tools have first-party RPMs available (Fedora 43, mise.jdx.dev, packages.microsoft.com).
- Layered RPMs baked into the image are deterministic and rpm-ostree-native.
- `sideral-cli-tools` as a meta-package gives the same `rpm-ostree override remove sideral-cli-tools` opt-out path that `sideral-flatpaks` offers — useful for slimmer derivatives.
- mise + chezmoi together cover the "I want a per-user tool fast" gap that nix's `nix profile install` would have filled (mise for runtimes, chezmoi for config).

---

## D-04 · Manual chezmoi bootstrap, not auto-on-first-login

**Chose**: User runs `chezmoi init --apply <repo-url>` themselves on first login (one command). No systemd user oneshot. An onboarding hint surfaces the command once on first shell (CHM-21..22).

**Considered**:
- Auto-bootstrap via `sideral-chezmoi-bootstrap.service` (user oneshot reading `$CHEZMOI_REPO` from `~/.config/environment.d/chezmoi.conf` or a marker file).
- Interactive prompt on first shell.

**Why**:
- chezmoi's bootstrap is a single command, not a multi-step pipeline. Auto-running it requires the user to *also* configure where their dotfiles live (env var or marker file) — chicken-and-egg on first login since systemd user units don't see `~/.bash_profile` env vars by default.
- Manual invocation is one-line documentation; readable, debuggable, no service-failure mode to re-run.
- nix-home's `sideral-home-manager-setup.service` existed because home-manager bootstrap was heavyweight (channel add → install → switch, ~5 minutes). chezmoi doesn't need that ceremony.

---

## D-05 · Shell-init wiring centralized in `/etc/profile.d/sideral-cli-init.sh`

**Chose**: Single shipped script, `command -v` guarded for each integration, owned by `sideral-shell-ux`.

**Considered**:
- Each user's chezmoi'd `~/.bashrc` declares its own integrations.
- Static `/etc/skel/.bashrc` with the integrations baked in.
- `/etc/bashrc.d/` snippets per-tool.

**Why**:
- Replaces home-manager's `programs.X.enable = true` declarative wiring with a single image-shipped layer. User gets full integration without configuring anything.
- `command -v` guards make the script robust against any single tool being absent (e.g., user removed a sub-package).
- `/etc/profile.d/` is sourced by all login shells — survives even if the user's `~/.bashrc` is empty or hostile.
- One file, one owner (`sideral-shell-ux`), one place to edit when adding/removing integrations.

---

## D-06 · VS Code via Microsoft RPM repo, not flatpak or VSCodium

**Chose**: `vscode.repo` shipped at `/etc/yum.repos.d/vscode.repo`, `build.sh` registers it inline, `dnf install code`. Restores ATH-14/15.

**Considered**:
- Flatpak (`com.visualstudio.code`).
- VSCodium (open-source rebuild).
- Skip; user installs themselves.

**Why**:
- Dev workflow needs full filesystem + devcontainer + remote-ssh integration. Flatpak sandbox breaks all three.
- VSCodium is a fork without the proprietary marketplace; user's existing extensions (Remote SSH, Remote Containers) only work on the proprietary build.
- Image-baked (vs. user-installed) preserves the "fresh rebase = ready to code" UX.
- The `programs.vscode { extensions = [...] }` declarative-extension-install loss is real but minor: extensions can be chezmoi'd (settings.json + extensions.json) or installed manually once.

---

## D-07 · Bitwarden as user-side shell helpers, not first-class

**Chose**: User integrates Bitwarden CLI (`bw`) via shell helpers in their chezmoi'd `~/.bash_profile.d/` if needed. sideral does not ship `bw`-aware machinery.

**Considered**:
- chezmoi's first-class Bitwarden template func (`bitwarden`, `bitwardenSecrets`) — declare secrets in dotfile templates, chezmoi pulls them at apply time.
- Ship `bitwarden-cli` as part of `sideral-cli-tools`.

**Why**:
- chezmoi's bitwarden func is built-in to the binary — no extra package needed; user opts in by editing their chezmoi source tree.
- `bw login` + session-token lifecycle adds setup ceremony that not every user wants from minute one.
- Keeping sideral neutral on the secrets-source choice (Bitwarden, 1Password, age, gpg, pass, sops) means the image doesn't impose a vault. User picks what they have.

---

## D-08 · `/var/lib/nix` cleanup is user-side, not image-driven

**Chose**: README documents `sudo rm -rf /var/lib/nix /nix` for users rebasing from a `nix-home` image. Image does not auto-purge.

**Considered**: One-shot cleanup unit that runs once on the first chezmoi-home boot if `/var/lib/nix` exists.

**Why**:
- A cleanup service that auto-deletes user data is a footgun: if the user rebased mid-experiment and wanted to keep a nix profile (e.g., to migrate `nix profile list` packages elsewhere first), automatic purge would destroy that.
- Manual cleanup is one-line documentation. Trusts the user.
- Image stays smaller and simpler.

---

## D-09 · `nix-index` / `comma` not replaced

**Chose**: Drop `nix-index` (had `programs.nix-index.enable = true` in nix-home). No replacement.

**Considered**: `dnf provides` (Fedora's native equivalent).

**Why**:
- `dnf provides /usr/bin/foo` resolves binary-to-package on Fedora — same workflow.
- `comma` (the `,` wrapper that runs a binary in an ephemeral nix shell) is nix-specific and obviously gone with nix.
- Distrobox covers the "I want to try a tool without committing" workflow.

---

## Open implementation concerns (not blocking spec)

- **vscode-extensions previously declared in home.nix** (`ms-vscode-remote.remote-ssh`, `ms-vscode-remote.remote-containers`): user installs from marketplace on first VS Code launch, or chezmoi's their `~/.config/Code/User/extensions/` tree. Documented in README as a one-time setup step.
- **mise toolchain config** (the 12-tool list previously inlined in home.nix's `home.file.".config/mise/config.toml".text`): user owns `~/.config/mise/config.toml` via chezmoi. README provides a starter template snippet for users who want sideral's previous defaults.
- **atuin sync server** (atuin's optional cloud sync): user opts in via `atuin login` and chezmoi'd `~/.config/atuin/config.toml`. Image stays neutral.
- **Image size**: rough estimate +100 to +120 MB net (VS Code +115 MB + 13 small RPMs ~30 MB − nix-installer ~25 MB − nix-related infra). If this proves too heavy, consider splitting `code` into a separate `sideral-vscode` sub-package the user can opt out of.
