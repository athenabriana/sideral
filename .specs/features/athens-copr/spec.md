# athens-copr Specification

## Problem Statement

athens-os currently ships its system customizations as loose files under `system_files/` that the Containerfile `COPY`s into the image at build time. System-integration RPMs come from two separate external sources: `ublue-os/packages` COPR (for bazaar) and Docker Inc's `docker-ce-stable` repo file. This works, but it's architecturally unclear — users can't enumerate "what does athens-os add to silverblue-main?" as a set of versioned artifacts; rollback is "re-image or edit loose files"; and users who want to strip the athens-os brand from a deployment have to manually hunt files across `/etc` and `/usr`.

Goal: consolidate all athens-os-authored customizations into a set of RPMs published from our own Copr project, signed by our CI via cosign keyless OIDC. Two upstream community repos (`ublue-os/packages` for bazaar + future ublue adoptions, and Docker Inc's official dnf repo) are aggregated as Copr "external repos" so users enable **one** COPR and get the full transitively-resolvable athens-os deployment.

The feature is scoped narrowly: **we package what we author**. We do not rebuild docker-ce or bazaar — both are well-maintained upstream and we have no patches to carry. They're aggregated via Copr's external-repo feature.

## Goals

- [ ] Copr project `athenabriana/athens-os` exists (public), accepts builds from GHA, and is enabled by `dnf5 copr enable athenabriana/athens-os` in `build.sh`
- [ ] Seven sub-packages built from `packages/<name>/<name>.spec` specs in our repo: `athens-os-base`, `athens-os-services`, `athens-os-flatpaks`, `athens-os-dconf`, `athens-os-selinux`, `athens-os-shell-ux`, `athens-os-user`
- [ ] `athens-os-base` is a meta-package with `Requires:` on every other `athens-os-*` sub-package plus the transitive third-party deps (`docker-ce`, `containerd.io`, `bazaar`, `ublue-os-signing`)
- [ ] Single `dnf5 install -y athens-os-base` in `build.sh` replaces the current per-feature `dnf5 install` loop + `COPY system_files /etc`
- [ ] Copr project has two external repos configured: `ublue-os/packages` (provides `bazaar`, `ublue-os-signing`, future ublue adoptions) and `docker-ce-stable` (Docker Inc's official dnf repo, provides `docker-ce` + `containerd.io`)
- [ ] **No bazaar fork**: bazaar resolves transitively from the aggregated `ublue-os/packages` external repo — we don't host or maintain a `packages/bazaar/bazaar.spec`
- [ ] Every RPM we build is signed via cosign keyless OIDC through GitHub Actions; verification uses Sigstore's transparency log + Fulcio CA (no pre-shared pub key)
- [ ] GHA workflow `copr.yml` triggers on push to `main` touching `packages/**` or `system_files/**` or `home/**`; builds spec files via `copr-cli`; blocks merge on build failure
- [ ] `system_files/` stays in the repo as the authoring source (hybrid mode); spec files reference it via relative paths; dir is NOT renamed

## Out of Scope

| Feature | Reason |
|---|---|
| Rebuilding docker-ce in our Copr | Docker Inc maintains it; we aggregate via external-repo |
| Rebuilding bazaar in our Copr | `ublue-os/packages` maintains it (used by Bluefin/Bazzite/Aurora); we aggregate via external-repo. We have no patches to carry. |
| Re-adding a browser to the RPM layer | Browser ships via flatpak (`app.zen_browser.zen`); RPM layer stays browser-free |
| Forking other ublue-os/packages specs (e.g. `ublue-os-just`) | When we have actual recipes/usage, pull them via the same external-repo aggregation — never fork without patches |
| Copr API token management via 1Password / Vault | GitHub secret is fine for personal use |
| Multi-arch builds (aarch64) | x86_64 only, same as image itself |
| Fedora versions other than 43 | Add fedora-44 chroot when F44 drops |
| Renaming `system_files/` directory | Deferred; ublue convention is kept (see decision D-06) |
| Deleting `system_files/` entirely after migration | Phase-C work, out of this spec's scope |

---

## User Stories

### P1: Single-COPR enablement ⭐ MVP

**Story**: A downstream user (or our own CI) enables one Copr project and can install the entire athens-os system layer with a single `dnf5` command. All third-party dependencies resolve transitively through aggregated external repos.

**Acceptance**:

1. **ACR-01** — `athenabriana/athens-os` Copr project exists, is public, has `fedora-43-x86_64` as its only enabled chroot.
2. **ACR-02** — The Copr project lists exactly two external repos: `https://copr.fedorainfracloud.org/coprs/ublue-os/packages/repo/fedora-43/ublue-os-packages-fedora-43.repo` and `https://download.docker.com/linux/fedora/docker-ce.repo`.
3. **ACR-03** — `dnf5 repoquery athens-os-base` (with our COPR enabled) resolves and shows `Requires:` on `athens-os-services`, `athens-os-flatpaks`, `athens-os-dconf`, `athens-os-selinux`, `athens-os-shell-ux`, `athens-os-user`, plus transitive third-party deps `bazaar`, `ublue-os-signing`, `docker-ce`, `containerd.io`.
4. **ACR-04** — `dnf5 install -y athens-os-base` on a vanilla silverblue-main:43 with only our Copr enabled succeeds — dnf resolves everything transitively via external repos, no additional `.repo` files needed on the user's host.
5. **ACR-05** — `rpm -q athens-os-base` on the installed system shows `athens-os-base-YYYYMMDD.<N>` with a version tied to the image release.

**Test**: Fresh silverblue-main:43 VM → `rpm-ostree install` with ONLY `athenabriana/athens-os` enabled → reboot → all 7 sub-packages present, `bazaar` + `ublue-os-signing` + `docker-ce` + `containerd.io` present, no stray `.repo` files from removed sources.

---

### P1: Image build uses the COPR ⭐ MVP

**Story**: `build.sh` installs our meta-package instead of per-feature `dnf5` loops + `COPY system_files /etc`. The image is smaller, reproducible via the Copr artifact registry, and one line replaces dozens.

**Acceptance**:

1. **ACR-06** — `build.sh` contains exactly one `dnf5 copr enable athenabriana/athens-os` + one `dnf5 install -y athens-os-base` after the persistent COPR enablement block.
2. **ACR-07** — The per-feature RPM install loop in `build.sh` keeps only the entries for non-athens RPMs (GNOME shell extensions, docker-ce stack, fonts); all athens-os-shipped files now come via the meta-package install.
3. **ACR-08** — `build.sh` still installs Fedora-main + non-athens RPMs via per-feature `packages.txt` (GNOME shell extensions, docker-ce stack, fonts — RPMs that are NOT in our Copr and don't fit home-manager).
4. **ACR-09** — The **production** `Containerfile` no longer has `COPY system_files /etc` or `COPY home /etc/skel` — the files are owned by the RPMs. A separate dev-mode path (`Containerfile.dev` or a pre-build rsync) handles local iteration per ACR-30.
5. **ACR-10** — `bootc container lint` passes on the built image.
6. **ACR-11** — Image layer count does not increase by more than 2 vs. the pre-migration count (one new layer from the meta-package install is expected; nothing else).

**Test**: `just build` succeeds end-to-end; `podman image inspect athens-os:latest` shows the new meta-package layered; `rpm -qa | grep athens-os` lists all 7 packages.

---

### P2: Packages are sub-divided by concern

**Story**: Each sub-package owns a coherent slice of athens-os functionality. A user can remove a single sub-package (e.g., `rpm-ostree override remove athens-os-shell-ux`) and get just the behavior change for that concern.

**Acceptance**:

1. **ACR-12** — `athens-os-base` is a meta-package (no files, only `Requires:`), owns only `/etc/os-release`. Does NOT own `/etc/flatpak-manifest` (moved to `athens-os-flatpaks` per ACR-19).
2. **ACR-13** — `athens-os-services` owns the **non-flatpak** systemd units only: `/etc/systemd/system/athens-nix-install.service`, `athens-nix-relabel.service`, `athens-nix-relabel.path`, their `multi-user.target.wants/` enablement symlinks, plus `/usr/lib/systemd/user/athens-home-manager-setup.service` + its `default.target.wants/` symlink. The flatpak install service is owned by `athens-os-flatpaks` (ACR-19).
3. **ACR-14** — `athens-os-dconf` owns every file under `/etc/dconf/db/local.d/` and the `/etc/dconf/profile/user` file; its `%post` scriptlet runs `dconf update`.
4. **ACR-15** — `athens-os-selinux` owns `/etc/selinux/targeted/contexts/files/file_contexts.local` and runs `restorecon -R /nix` in `%posttrans` (no-op if `/nix` does not exist).
5. **ACR-16** — `athens-os-shell-ux` owns `/etc/profile.d/athens-hm-status.sh` and any future interactive shell hooks.
6. **ACR-17** — `athens-os-user` owns `/etc/skel/.config/home-manager/home.nix` and any future user-default dotfiles shipped via `/etc/skel`.
7. **ACR-18** — `rpm -qf /etc/systemd/system/athens-nix-install.service` returns exactly `athens-os-services`. Every file shipped by athens-os is owned by exactly one sub-package.

**Test**: `rpm-ostree override remove athens-os-shell-ux` on a deployed system → next reboot → `/etc/profile.d/athens-hm-status.sh` is gone, rest of athens-os still works.

---

### P2: Flatpak preinstall as own sub-package

**Story**: Flatpak auto-install machinery (the manifest + the systemd service that reads it + the enablement symlink) lives in its own sub-package. A user who wants their own flatpak set can `rpm-ostree override remove athens-os-flatpaks` and ship their own — without losing the rest of athens-os.

**Acceptance**:

1. **ACR-19** — `athens-os-flatpaks` owns `/etc/flatpak-manifest`, `/etc/systemd/system/athens-flatpak-install.service`, and the `multi-user.target.wants/athens-flatpak-install.service` enablement symlink. All three coupled files live in one package — no cross-package dependency between manifest and reader.
2. **ACR-20** — `rpm-ostree override remove athens-os-flatpaks` cleanly removes the curated flatpak set's auto-install path: next boot the service is absent and `/etc/flatpak-manifest` is gone. Flatpaks already installed at `/var/lib/flatpak` are NOT removed (that's the user's `flatpak uninstall` job — RPM removal doesn't touch deployed flatpak state).
3. **ACR-21** — `athens-os-base` declares `Requires: athens-os-flatpaks` (default install pulls the curated set); a user wanting to opt out replaces base's dependency closure via `rpm-ostree override remove athens-os-flatpaks` after install.
4. **ACR-22** — The current 8-ref manifest (Zen Browser + 7 GUI apps) ships in this package; future additions/removals to the curated flatpak set are made by editing `system_files/etc/flatpak-manifest` and rebuilding only `athens-os-flatpaks` (no rebuild of unrelated sub-packages).

**Test**: Fresh image with athens-os-base installed → reboot → `flatpak list --app` shows 8 refs. `rpm-ostree override remove athens-os-flatpaks` → next reboot → `/etc/flatpak-manifest` absent, but already-installed flatpaks remain in `/var/lib/flatpak`.

---

### P2: Cosign-signed RPMs with keyless OIDC

**Story**: Every RPM built by our GHA workflow is signed by cosign via GitHub OIDC, and the signature can be verified on any host with `cosign` and the documented identity flags.

**Acceptance**:

1. **ACR-23** — The `copr.yml` workflow runs `cosign sign-blob --yes` on every produced `.rpm` and `.src.rpm` using GitHub's OIDC identity token (Sigstore keyless flow — no pre-shared private key); signatures land in the Copr results directory alongside the binaries.
2. **ACR-24** — `cosign verify-blob --certificate-identity "https://github.com/athenabriana/athens-os/.github/workflows/copr.yml@refs/heads/main" --certificate-oidc-issuer "https://token.actions.githubusercontent.com" --signature <sig> --certificate <cert> <rpm>` succeeds for every published RPM (verifies against Sigstore Rekor transparency log + Fulcio CA; no local pub key needed).
3. **ACR-25** — README documents the full `cosign verify-blob` command with the correct `--certificate-identity` and `--certificate-oidc-issuer` flags so users can verify on a clean machine without cloning the repo first.

**Test**: On a host with only `cosign` installed, run the command from ACR-25 against a fresh published RPM — exit code 0.

---

### P2: GHA → Copr automation

**Story**: Pushing changes to packaging-relevant paths on `main` triggers a GHA workflow that rebuilds the affected spec files in Copr and pushes fresh RPMs. Merge is blocked if the Copr build fails.

**Acceptance**:

1. **ACR-26** — `.github/workflows/copr.yml` exists and triggers on push to `main` touching `packages/**`, `system_files/**`, or `home/**`.
2. **ACR-27** — The workflow authenticates to Copr via an API token stored in GitHub secret `COPR_API_TOKEN`.
3. **ACR-28** — The workflow runs `copr-cli build athens-os packages/<name>/<name>.spec` for each changed spec file (or, simpler, for all specs on every relevant push).
4. **ACR-29** — A failed Copr build causes the workflow to exit non-zero; the main branch protection rule (when configured) blocks further merges until fixed.
5. **ACR-30** — Successful builds publish to `https://download.copr.fedorainfracloud.org/results/athenabriana/athens-os/` within 5 minutes of workflow completion.

**Test**: Edit a spec → push to a temporary branch → open PR → CI builds in Copr, workflow reports success → merge.

---

### P3: Hybrid authoring (system_files/ stays as source of truth)

**Story**: During and after the migration, developers edit files in `system_files/` and `home/` as before. Specs reference those paths via `Source0` and `%install` directives. Local `just build-local` can still use a `COPY`-based dev path for fast iterations without a Copr round-trip.

**Acceptance**:

1. **ACR-31** — Every `packages/<name>/<name>.spec` uses `Source0: %{name}-%{version}.tar.gz` and the `%install` section copies from a `system_files/`-shaped tree inside the tarball. The tarball is generated from our repo's `system_files/` + `home/` by a build script, not authored separately.
2. **ACR-32** — A script `scripts/build-srpm.sh` (new) creates the SRPM for each package by tarballing the relevant subset of `system_files/` and invoking `rpmbuild -bs`. (Lives under `scripts/`, not `packages/<name>/`, because it's shared across all sub-packages.)
3. **ACR-33** — `just build-local` produces a functioning image in under 30 seconds of incremental dev iteration (no Copr round-trip). Implementation: a `Containerfile.dev` that rsyncs `system_files/` + `home/` into the image at build time, skipping the RPM-install step for athens-os-* packages. `just build-release` runs the canonical `Containerfile` (installs from Copr). Both variants are documented in README.
4. **ACR-34** — Drift detection: CI job runs `rpm -ql athens-os-services` (etc. for each sub-package) and diffs the output against the expected file set derived from `find system_files/… -type f` scoped to that sub-package's ownership rules. Non-empty diff exits non-zero.

**Test**: Edit `system_files/etc/profile.d/athens-hm-status.sh`, run `just build-local` → script is in the image. Push → Copr rebuilds `athens-os-shell-ux` → `just build-release` → script comes from the RPM, same content.

---

### P3: Operations & versioning

**Story**: The packaging and release mechanics are specified — not left as "figure it out at implementation time" — so every build is reproducible and every systemd unit we ship actually activates when its RPM is installed.

**Acceptance**:

1. **ACR-35** — Package version is `YYYYMMDD.<run_number>` where `YYYYMMDD` is the GHA run date (UTC) and `run_number` is `${{ github.run_number }}`. The version is stamped identically on every sub-package produced by the same workflow run so they all `Requires:` each other by exact `=` match without drift.
2. **ACR-36** — Systemd unit enablement is handled by RPM `%files` listing the `multi-user.target.wants/` + `default.target.wants/` symlinks directly (not by `%post systemctl enable`). This makes `rpm-ostree override remove <pkg>` cleanly remove the symlinks along with the unit files — no orphaned enablement state. Exception: `athens-os-dconf` uses `%post dconf update` because that isn't a file-ownership operation.
3. **ACR-37** — Every push to `main` touching `packages/**` or `system_files/**` or `home/**` that the build succeeds on produces a new versioned tarball uploaded to GHA artifacts, retained 30 days; used as a build-cache fallback if Copr is unreachable on a later image build.

---

## Edge Cases

- **Copr build failure**: GHA workflow exits non-zero; main branch is "yellow" (build failed) until fixed. Image build is not affected until we switch `build.sh` to depend on the new Copr (gated behind ACR-06).
- **Copr is down during image build**: `dnf5 copr enable athenabriana/athens-os` or the subsequent `install` fails. Fallback path (per ACR-37): the image-build workflow falls back to a GHA-cached `athens-os-base-<version>.rpm` from a prior successful run. If no cache exists yet, image build fails loudly.
- **`ublue-os/packages` external repo outage**: `bazaar` and `ublue-os-signing` fail to resolve during `dnf install athens-os-base`. Image build fails. Same failure mode as the current `PERSISTENT_COPRS` setup; no regression. Fallback: temporarily inline-install bazaar from a known-good cached RPM.
- **External repo outage (docker-ce.repo)**: If Docker's repo is unreachable during `rpm-ostree rebase`, the rebase fails. Same failure mode as current `docker-ce.repo`-based setup; no regression.
- **Fedora version bump (43 → 44)**: When silverblue-main bumps base, Copr needs the new chroot added (`fedora-44-x86_64`) and `build.sh` needs the new enablement. Rollout plan: add the new chroot to Copr first, let builds succeed on both chroots in parallel, switch the image base, then drop the old chroot after one release cycle.
- **`ublue-os/packages` upstream removes a package we depend on** (e.g., bazaar deprecated): image build fails on `Requires: bazaar` resolution. Mitigation: pin `Requires: bazaar >= X.Y` on a known-stable version; if upstream drops it entirely, fall back to forking that one spec into our tree (the previously-rejected Plan A — a one-time emergency, not the steady state).
- **Sub-package rename collision with Fedora-main package**: All `athens-os-*` names are namespaced to prevent collision.
- **User modifies a file owned by `athens-os-shell-ux`**: `rpm-ostree upgrade` treats this as a conflict; `.rpmnew` file is created. Standard RPM behavior.
- **Copr API token leak**: Rotate token in Copr web UI, update GitHub secret, force-rebuild. No user-visible impact.
- **Cosign signature verification fails on a user's machine**: They can still install via `dnf5 --nogpgcheck` as an escape hatch, but the image-build workflow always verifies and never disables checks. Keyless OIDC failures typically mean upstream Sigstore is down (transient) — documentation points users at https://status.sigstore.dev.

---

## Requirement Traceability

| Story | Requirement IDs |
|---|---|
| P1: Single-COPR enablement | ACR-01 … ACR-05 (5) |
| P1: Image build uses the COPR | ACR-06 … ACR-11 (6) |
| P2: Sub-divided by concern | ACR-12 … ACR-18 (7) |
| P2: Flatpak preinstall sub-package | ACR-19 … ACR-22 (4) |
| P2: Cosign-signed RPMs | ACR-23 … ACR-25 (3) |
| P2: GHA → Copr automation | ACR-26 … ACR-30 (5) |
| P3: Hybrid authoring | ACR-31 … ACR-34 (4) |
| P3: Operations & versioning | ACR-35 … ACR-37 (3) |

**Total**: 37 testable requirements. Status values: Pending → In Tasks → Implementing → Verified.

---

## Supersedes

**From `.specs/features/athens-os/`**:

- **ATH-09 / ATH-10** (flatpak install oneshot — idempotent, sentinel-guarded) → packaged inside `athens-os-flatpaks` (no behavioral change; just relocated to its own sub-package per ACR-19)
- **ATH-13** (the manifest itself with 8 refs) → owned by `athens-os-flatpaks`
- **ATH-01** (CI push → build → tag → cosign image) → extended by ACR-01/06/26–30 (image build now also installs our Copr artifact; separate Copr workflow runs on packaging changes)
- **ATH-02** (`rpm-ostree rebase` succeeds) → `rpm-ostree rebase` + `rpm -qa | grep athens-os` showing all 7 sub-packages is the new success condition

**From `.specs/features/nix-home/`**:

- **Packaging of nix-home artifacts**: `athens-nix-install.service`, `athens-nix-relabel.{service,path}`, `file_contexts.local`, `athens-hm-status.sh`, `/etc/skel/.config/home-manager/home.nix` — all get sub-package homes per ACR-13/15/16/17. No nix-home **requirements** superseded; only their delivery mechanism changes (loose files → RPMs).

**Parent project (`STATE.md`)**:

- Locked decision *"Persistent COPR pattern — `ublue-os/packages` + `docker-ce.repo`"* → updated by this spec: both repos move from `PERSISTENT_COPRS` (build.sh enables them per-build) to Copr **external-repo aggregation** (configured once on our Copr project). User-facing experience: enable one Copr, get everything.

---

## Rollout Plan

Three phases, each a separate branch + merge cycle. Later phases depend on earlier ones being green.

### Phase A — Skeleton (~3 h)

Prove the plumbing works without changing image behavior.

1. Create Copr project `athenabriana/athens-os` (public, `fedora-43-x86_64` chroot). Configure two **external repos** in project settings: `ublue-os/packages` + `docker-ce-stable`. Record the Copr API token in GitHub secret `COPR_API_TOKEN`.
2. Write **empty** `athens-os-base.spec` — meta-package, `Requires: bazaar, ublue-os-signing, docker-ce, containerd.io`, no files.
3. Write `scripts/build-srpm.sh` — tarballs + runs `rpmbuild -bs`.
4. Write `.github/workflows/copr.yml` — triggers on `packages/**`, runs `copr-cli build` for every spec, signs outputs with cosign keyless.
5. Land: Copr project shows empty `athens-os-base`; `dnf5 install athens-os-base` on a clean VM with only our Copr enabled pulls bazaar + ublue-os-signing + docker-ce + containerd.io transitively from external repos. Image build still uses the old path.

**Exit criterion**: ACR-01, ACR-02, ACR-04 (transitive resolution proven), ACR-23–25 (signing pipeline proven), ACR-26–30 (workflow proven) pass.

### Phase B — Sub-package migration (~8 h, one per sitting)

Migrate concerns one at a time. Each lands as its own PR so CI can catch drift early.

Order (simplest first):
1. **`athens-os-selinux`** — one file (`file_contexts.local`), no `%post` beyond `restorecon`. Good first migration.
2. **`athens-os-shell-ux`** — one file (`athens-hm-status.sh`), `/etc/profile.d/` placement only.
3. **`athens-os-user`** — one file (`home.nix`), ships to `/etc/skel/.config/home-manager/`.
4. **`athens-os-flatpaks`** — manifest + service + symlink. Tightly coupled trio; migrate together. Validate with `rpm-ostree override remove athens-os-flatpaks` removal-roundtrip test.
5. **`athens-os-dconf`** — `/etc/dconf/db/local.d/*` + profile + `%post dconf update`.
6. **`athens-os-services`** — non-flatpak services: nix-install, nix-relabel, home-manager-setup + their enablement symlinks. Multiple file types, both system + user scopes.

Each migration: write spec → rebuild in Copr → verify file ownership via `rpm -qf` → land drift-detection CI.

**Exit criterion**: ACR-12–22 pass; ACR-31/32/34 operational; dev-loop via `just build-local` (ACR-33) works.

### Phase C — Cutover (~2 h)

Switch the image build to consume from Copr.

> **Pre-Phase-C state** (as of 2026-04-23, after the RPM cleanup): `build_files/features/` has only `gnome/`, `gnome-extensions/`, `container/`, `fonts/` left — the `devtools/` and `browser/` dirs were already deleted in earlier work. `PERSISTENT_COPRS` only contains `ublue-os/packages` (helium dropped). `system_files/etc/yum.repos.d/` only contains `docker-ce.repo` (vscode.repo deleted). This is what Phase C migrates _from_, not the original "many features + many repos" assumption made when the spec was first drafted.

1. Edit `build.sh`:
   ```diff
   + dnf5 -y copr enable athenabriana/athens-os
   + dnf5 -y install --setopt=install_weak_deps=False athens-os-base
   ```
   The existing per-feature loop stays for the non-athens RPMs (GNOME extensions, docker-ce stack, fonts). Only `system_files/`-shipping responsibilities move into the meta-package.
2. Remove `ublue-os/packages` from `PERSISTENT_COPRS` (our own Copr's external-repo aggregation handles bazaar + ublue-os-signing transitively).
3. Delete `system_files/etc/yum.repos.d/docker-ce.repo` (external-repo aggregation in our Copr makes it redundant).
4. Delete the Containerfile's `COPY system_files /etc` and `COPY home /etc/skel` — RPMs own those files now.
5. Add a new `Containerfile.dev` that DOES use `COPY` for fast local iteration without Copr round-trips (per ACR-33).
6. Update `Justfile`: rename existing `just build` → `just build-release`; add new `just build-local` that uses `Containerfile.dev`.
7. Confirm CI goes green with the new flow.
8. Update README with the new architecture narrative + verification commands.

**Exit criterion**: ACR-03, ACR-05, ACR-07, ACR-09, ACR-10, ACR-11 all pass; existing image users can `rpm-ostree upgrade` to the new base without losing any files.

**Deferred from Phase C** (separate future feature): delete `system_files/` entirely (would force every dev iteration through Copr — too much friction). Hybrid mode is the steady state.

---

## Prerequisites (to validate during Phase A)

Unverified assumptions that must hold for this spec to be implementable as written:

1. **Copr's "external repos" feature accepts both Copr-native URLs AND arbitrary dnf `.repo` URLs.** Specifically: can both `https://copr.fedorainfracloud.org/coprs/ublue-os/packages/repo/fedora-43/...` AND `https://download.docker.com/linux/fedora/docker-ce.repo` be added as external repos via web UI or `copr-cli modify`? (Likely yes per Copr docs, but unverified against our actual setup.)
2. **`copr-cli` supports signing via cosign keyless OIDC** or we can run cosign on the built RPM as a post-build step and upload the `.sig` + `.crt` separately. (Cosign against arbitrary blobs is standard; integration path just needs to be confirmed.)
3. **GitHub OIDC identity tokens** authenticate `cosign sign-blob` from within a GHA workflow without additional setup beyond `permissions: id-token: write`. (Standard Sigstore keyless flow.)
4. **Running `dnf5 install athens-os-base` inside a Containerfile RUN step** does not require the build environment to have an active systemd (no `%post systemctl enable` execution at build time — deferred until first boot). ACR-36's symlink approach sidesteps this, but worth verifying.

Any assumption that breaks requires a spec revision before Phase A can proceed.

---

## Success Criteria

- [ ] Fresh VM rebase → `rpm-ostree status` lists `athens-os-base-<version>` alongside `silverblue-main-<version>`
- [ ] `rpm -qa | grep athens-os` shows all 7 sub-packages with matching versions (same `YYYYMMDD.<run>`)
- [ ] `rpm -qf` on any shipped path (`/etc/systemd/system/athens-nix-install.service`, `/etc/skel/.config/home-manager/home.nix`, `/etc/selinux/targeted/contexts/files/file_contexts.local`, `/etc/profile.d/athens-hm-status.sh`, `/etc/flatpak-manifest`) returns exactly one `athens-os-*` package
- [ ] `cosign verify-blob` against every published RPM succeeds using only the cert-identity + OIDC-issuer flags (no pre-shared pub key)
- [ ] CI image-build time does not regress more than 2 minutes vs. pre-migration (Copr build happens in a separate workflow; image build just installs pre-built RPMs)
- [ ] Copr build failures block merges to `main` (via branch protection, once configured)
- [ ] `just build-local` produces a working image in < 30 seconds of incremental iteration (no Copr round-trip)
- [ ] Drift-detection CI job is green on every merge
- [ ] `rpm-ostree override remove athens-os-shell-ux` cleanly removes `/etc/profile.d/athens-hm-status.sh` (including enablement state) — proves sub-packaging granularity works
- [ ] `rpm-ostree override remove athens-os-flatpaks` cleanly removes the flatpak auto-install path (manifest + service + symlink) — proves the new sub-package boundary
