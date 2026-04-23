# athens-copr Specification

## Problem Statement

athens-os currently ships its system customizations as loose files under `system_files/` that the Containerfile `COPY`s into the image at build time. System-integration RPMs come from two separate external sources: `ublue-os/packages` COPR (for bazaar) and Docker Inc's `docker-ce-stable` repo file. This works, but it's architecturally unclear — users can't enumerate "what does athens-os add to silverblue-main?" as a set of versioned artifacts; rollback is "re-image or edit loose files"; and users who want to strip the athens-os brand from a deployment have to manually hunt files across `/etc` and `/usr`.

Goal: consolidate all athens-os-authored customizations into a set of RPMs published from our own Copr project, signed by our CI via cosign keyless OIDC, with Docker Inc's official dnf repo configured as a Copr "external repo" so users enable **one** COPR and get the full transitively-resolvable athens-os deployment. The `bazaar` RPM currently consumed from `ublue-os/packages` gets forked into our own `packages/bazaar/` spec so we control its release cadence and can rebrand without asking ublue for a release.

The feature is scoped narrowly: we package what **we author** and fork the **minimum subset** of upstream specs we use. We do not rebuild docker-ce — we aggregate it via Copr's external-repo feature.

## Goals

- [ ] Copr project `athenabriana/athens-os` exists (public), accepts builds from GHA, and is enabled by `dnf5 copr enable athenabriana/athens-os` in `build.sh`
- [ ] Six sub-packages built from `packages/<name>/<name>.spec` specs in our repo: `athens-os-base`, `athens-os-services`, `athens-os-dconf`, `athens-os-selinux`, `athens-os-shell-ux`, `athens-os-skel`
- [ ] `athens-os-base` is a meta-package with `Requires:` on every other `athens-os-*` sub-package plus the transitive third-party deps (docker-ce, containerd.io, bazaar)
- [ ] Single `dnf5 install -y athens-os-base` in `build.sh` replaces the current per-feature `dnf5 install` loop + `COPY system_files /etc`
- [ ] `bazaar.spec` lives at `packages/bazaar/bazaar.spec` in this repo, forked from `ublue-os/packages:staging/bazaar/bazaar.spec`; it builds in our Copr and replaces our consumption of `ublue-os/packages`
- [ ] Copr project has one external repo configured: `docker-ce-stable` (Docker Inc's official dnf repo). Users enabling `athenabriana/athens-os` get transitive resolution of docker-ce + containerd.io.
- [ ] Every RPM is signed via cosign keyless OIDC through GitHub Actions; `cosign.pub` is shipped alongside the Copr so users can verify
- [ ] GHA workflow `copr.yml` triggers on push to `main` touching `packages/**` or `system_files/**` or `home/**`; builds spec files via `copr-cli`; blocks merge on build failure
- [ ] `system_files/` stays in the repo as the authoring source (hybrid mode); spec files reference it via relative paths; dir is NOT renamed

## Out of Scope

| Feature | Reason |
|---|---|
| Rebuilding docker-ce in our Copr | Docker Inc maintains it; we aggregate via external-repo |
| Re-adding a browser to the RPM layer | Browser ships via flatpak (`app.zen_browser.zen`); RPM layer stays browser-free |
| Forking non-bazaar ublue-os/packages specs | Deferred — bazaar is the only one we currently use |
| Copr API token management via 1Password / Vault | GitHub secret is fine for personal use |
| Multi-arch builds (aarch64) | x86_64 only, same as image itself |
| Fedora versions other than 43 | Add fedora-44 chroot when F44 drops |
| Renaming `system_files/` directory | Deferred; ublue convention is kept (see decision D-11) |
| Deleting `system_files/` entirely after migration | Phase-C work, out of this spec's scope |
| Bumping upstream bazaar version beyond what we forked | Deferred; first fork pins current upstream version, later releases are separate tasks |

---

## User Stories

### P1: Single-COPR enablement ⭐ MVP

**Story**: A downstream user (or our own CI) enables one Copr project and can install the entire athens-os system layer with a single `dnf5` command. All third-party dependencies resolve transitively.

**Acceptance**:

1. **ACR-01** — `athenabriana/athens-os` Copr project exists, is public, has `fedora-43-x86_64` as its only enabled chroot, and `cosign.pub` matches the key used by our GHA workflow.
2. **ACR-02** — The Copr project lists exactly one external repo: `https://download.docker.com/linux/fedora/docker-ce.repo`.
3. **ACR-03** — `dnf5 repoquery athens-os-base` (with our COPR enabled) resolves and shows `Requires:` on `athens-os-services`, `athens-os-dconf`, `athens-os-selinux`, `athens-os-shell-ux`, `athens-os-skel`, `docker-ce`, `containerd.io`, `bazaar`.
4. **ACR-04** — `dnf5 install -y athens-os-base` on a vanilla silverblue-main:43 with only our Copr enabled succeeds — dnf resolves everything transitively via external repos, no additional `.repo` files needed.
5. **ACR-05** — `rpm -q athens-os-base` on the installed system shows `athens-os-base-YYYYMMDD.<N>` with a version tied to the image release.

**Test**: Fresh silverblue-main:43 VM → `rpm-ostree install` with ONLY `athenabriana/athens-os` enabled → reboot → all 6 sub-packages present, docker-ce + bazaar present, no stray `.repo` files from removed sources.

---

### P1: Image build uses the COPR ⭐ MVP

**Story**: `build.sh` installs our meta-package instead of per-feature `dnf5` loops + `COPY system_files /etc`. The image is smaller, reproducible via the Copr artifact registry, and one line replaces dozens.

**Acceptance**:

1. **ACR-06** — `build.sh` contains exactly one `dnf5 copr enable athenabriana/athens-os` + one `dnf5 install -y athens-os-base` after the persistent COPR enablement block.
2. **ACR-07** — The per-feature RPM install loop in `build.sh` is removed; `build_files/features/*/packages.txt` files that contained only athens-os-shipped RPMs are deleted.
3. **ACR-08** — `build.sh` still installs Fedora-main-only RPMs via per-feature `packages.txt` (GNOME shell extensions, docker-ce stack, fonts — RPMs that are NOT in our Copr and don't fit home-manager).
4. **ACR-09** — The **production** `Containerfile` no longer has `COPY system_files /etc` or `COPY home /etc/skel` — the files are owned by the RPMs. A separate dev-mode path (`Containerfile.dev` or a pre-build rsync) handles local iteration per ACR-34.
5. **ACR-10** — `bootc container lint` passes on the built image.
6. **ACR-11** — Image layer count does not increase by more than 2 vs. the pre-migration count (one new layer from the meta-package install is expected; nothing else).

**Test**: `just build` succeeds end-to-end; `podman image inspect athens-os:latest` shows the new meta-package layered; `rpm -qa | grep athens-os` lists all 6 packages.

---

### P2: Packages are sub-divided by concern

**Story**: Each sub-package owns a coherent slice of athens-os functionality. A user can remove a single sub-package (e.g., `rpm-ostree override remove athens-os-shell-ux`) and get just the behavior change for that concern.

**Acceptance**:

1. **ACR-12** — `athens-os-base` is a meta-package (no files, only `Requires:`), owns only `/etc/os-release` and `/etc/flatpak-manifest`.
2. **ACR-13** — `athens-os-services` owns every file under `/etc/systemd/system/athens-*.service`, `/etc/systemd/system/athens-*.path`, and the `multi-user.target.wants/` + `default.target.wants/` enablement symlinks, plus the user-level units under `/usr/lib/systemd/user/athens-*.service`.
3. **ACR-14** — `athens-os-dconf` owns every file under `/etc/dconf/db/local.d/` and the `/etc/dconf/profile/user` file; its `%post` scriptlet runs `dconf update`.
4. **ACR-15** — `athens-os-selinux` owns `/etc/selinux/targeted/contexts/files/file_contexts.local` and runs `restorecon -R /nix` in `%posttrans` (no-op if `/nix` does not exist).
5. **ACR-16** — `athens-os-shell-ux` owns `/etc/profile.d/athens-hm-status.sh` and any future interactive shell hooks.
6. **ACR-17** — `athens-os-skel` owns `/etc/skel/.config/home-manager/home.nix` and any future dotfiles shipped via skel.
7. **ACR-18** — `rpm -qf /etc/systemd/system/athens-nix-install.service` returns exactly `athens-os-services`. Every file shipped by athens-os is owned by exactly one sub-package.

**Test**: `rpm-ostree override remove athens-os-shell-ux` on a deployed system → next reboot → `/etc/profile.d/athens-hm-status.sh` is gone, rest of athens-os still works.

---

### P2: Cosign-signed RPMs with keyless OIDC

**Story**: Every RPM built by our GHA workflow is signed by cosign via GitHub OIDC, and the signature can be verified on any host with `cosign.pub` and `cosign verify-blob`.

**Acceptance**:

1. **ACR-19** — The `copr.yml` workflow runs `cosign sign-blob --yes` on every produced `.rpm` and `.src.rpm` using GitHub's OIDC identity token (Sigstore keyless flow — no pre-shared private key); signatures land in the Copr results directory alongside the binaries.
2. **ACR-20** — `cosign verify-blob --certificate-identity "https://github.com/athenabriana/athens-os/.github/workflows/copr.yml@refs/heads/main" --certificate-oidc-issuer "https://token.actions.githubusercontent.com" --signature <sig> --certificate <cert> <rpm>` succeeds for every published RPM (verifies against Sigstore Rekor transparency log + Fulcio CA; no local pub key needed).
3. **ACR-21** — README documents the full `cosign verify-blob` command with the correct `--certificate-identity` and `--certificate-oidc-issuer` flags so users can verify on a clean machine without cloning the repo first.

**Test**: On a host with only `cosign` installed, run the command from ACR-21 against a fresh published RPM — exit code 0.

---

### P2: `bazaar` forked into our own repo

**Story**: The `bazaar` RPM no longer comes from `ublue-os/packages`. Our own `packages/bazaar/bazaar.spec` builds the same upstream source (kolunmi/bazaar) in our Copr, versioned to match whatever we fork from ublue.

**Acceptance**:

1. **ACR-22** — `packages/bazaar/bazaar.spec` exists, forked from `ublue-os/packages:staging/bazaar/bazaar.spec`, with the `Name:` unchanged (`bazaar`) so existing `dnf install bazaar` references continue to resolve.
2. **ACR-23** — `packages/bazaar/bazaar.spec` pulls source from `https://github.com/bazaar-org/bazaar` (upstream moved away from `kolunmi/bazaar`) tagged at the version listed in `Version:`.
3. **ACR-24** — `copr.yml` builds `bazaar.spec` in `athenabriana/athens-os` Copr for `fedora-43-x86_64`.
4. **ACR-25** — `athens-os-base.spec` contains `Requires: bazaar` — resolved by our own Copr, not via external-repo pointing at ublue.
5. **ACR-26** — The `ublue-os/packages` COPR is removed from `PERSISTENT_COPRS` in `build.sh`.

**Test**: `dnf5 repoquery --whatprovides bazaar --disablerepo='*' --enablerepo='copr:copr.fedorainfracloud.org:athenabriana:athens-os'` returns `bazaar-N.M.K-<rel>.athens-os.fc43` (our build, not ublue's).

---

### P2: GHA → Copr automation

**Story**: Pushing changes to packaging-relevant paths on `main` triggers a GHA workflow that rebuilds the affected spec files in Copr and pushes fresh RPMs. Merge is blocked if the Copr build fails.

**Acceptance**:

1. **ACR-27** — `.github/workflows/copr.yml` exists and triggers on push to `main` touching `packages/**`, `system_files/**`, or `home/**`.
2. **ACR-28** — The workflow authenticates to Copr via an API token stored in GitHub secret `COPR_API_TOKEN`.
3. **ACR-29** — The workflow runs `copr-cli build athens-os packages/<name>/<name>.spec` for each changed spec file (or, simpler, for all specs on every relevant push).
4. **ACR-30** — A failed Copr build causes the workflow to exit non-zero; the main branch protection rule (when configured) blocks further merges until fixed.
5. **ACR-31** — Successful builds publish to `https://download.copr.fedorainfracloud.org/results/athenabriana/athens-os/` within 5 minutes of workflow completion.

**Test**: Edit a spec → push to a temporary branch → open PR → CI builds in Copr, workflow reports success → merge.

---

### P3: Hybrid authoring (system_files/ stays as source of truth)

**Story**: During and after the migration, developers edit files in `system_files/` and `home/` as before. Specs reference those paths via `Source0` and `%install` directives. Local `just build` can still use `COPY system_files /etc` as a fallback for fast dev iterations without a Copr round-trip.

**Acceptance**:

1. **ACR-32** — Every `packages/<name>/<name>.spec` uses `Source0: %{name}-%{version}.tar.gz` and the `%install` section copies from a `system_files/`-shaped tree inside the tarball. The tarball is generated from our repo's `system_files/` + `home/` by a build script, not authored separately.
2. **ACR-33** — A script `scripts/build-srpm.sh` (new) creates the SRPM for each package by tarballing the relevant subset of `system_files/` and invoking `rpmbuild -bs`. (Lives under `scripts/`, not `packages/<name>/`, because it's shared across all sub-packages.)
3. **ACR-34** — `just build-local` produces a functioning image in under 30 seconds of incremental dev iteration (no Copr round-trip). Implementation: a `Containerfile.dev` that rsyncs `system_files/` + `home/` into the image at build time, skipping the RPM-install step for athens-os-* packages. `just build-release` runs the canonical `Containerfile` (installs from Copr). Both variants are documented in README.
4. **ACR-35** — Drift detection: CI job runs `rpm -ql athens-os-services` (etc. for each sub-package) and diffs the output against the expected file set derived from `find system_files/… -type f` scoped to that sub-package's ownership rules. Non-empty diff exits non-zero.

**Test**: Edit `system_files/etc/profile.d/athens-hm-status.sh`, run `just build-local` → script is in the image. Push → Copr rebuilds `athens-os-shell-ux` → `just build-release` → script comes from the RPM, same content.

---

### P3: Operations & versioning

**Story**: The packaging and release mechanics are specified — not left as "figure it out at implementation time" — so every build is reproducible, every package tracks an upstream cleanly, and every systemd unit we ship actually activates when its RPM is installed.

**Acceptance**:

1. **ACR-36** — Package version is `YYYYMMDD.<run_number>` where `YYYYMMDD` is the GHA run date (UTC) and `run_number` is `${{ github.run_number }}`. The version is stamped identically on every sub-package produced by the same workflow run so they all `Requires:` each other by exact `=` match without drift.
2. **ACR-37** — Systemd unit enablement is handled by RPM `%files` listing the `multi-user.target.wants/` + `default.target.wants/` symlinks directly (not by `%post systemctl enable`). This makes `rpm-ostree override remove <pkg>` cleanly remove the symlinks along with the unit files — no orphaned enablement state. Exception: `athens-os-dconf` uses `%post dconf update` because that isn't a file-ownership operation.
3. **ACR-38** — `packages/bazaar/UPSTREAM.md` documents the tracked upstream tag (`https://github.com/bazaar-org/bazaar` ref) and last-sync date. A CI reminder job (weekly scheduled workflow) opens an issue if upstream has tagged a release newer than the pinned one.
4. **ACR-39** — Every push to `main` touching `packages/**` or `system_files/**` or `home/**` that the build succeeds on produces a new versioned tarball uploaded to GHA artifacts, retained 30 days; used as a build-cache fallback if Copr is unreachable on a later image build.

---

## Edge Cases

- **Copr build failure**: GHA workflow exits non-zero; main branch is "yellow" (build failed) until fixed. Image build is not affected until we switch `build.sh` to depend on the new Copr (gated behind ACR-06).
- **Copr is down during image build**: `dnf5 copr enable athenabriana/athens-os` or the subsequent `install` fails. Fallback path (per ACR-39): the image-build workflow falls back to a GHA-cached `athens-os-base-<version>.rpm` from a prior successful run. If no cache exists yet, image build fails loudly.
- **External repo outage (docker-ce.repo)**: If Docker's repo is unreachable during `rpm-ostree rebase`, the rebase fails. Same failure mode as current `docker-ce.repo`-based setup; no regression.
- **Fedora version bump (43 → 44)**: When silverblue-main bumps base, Copr needs the new chroot added (`fedora-44-x86_64`) and `build.sh` needs the new enablement. Rollout plan: add the new chroot to Copr first, let builds succeed on both chroots in parallel, switch the image base, then drop the old chroot after one release cycle.
- **Sub-package rename collision with Fedora-main package**: All `athens-os-*` names are namespaced to prevent collision; `bazaar` (un-namespaced fork) keeps upstream name intentionally — and shadows the `ublue-os/packages` version by version number (our builds use a higher `Release:` suffix).
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
| P2: Cosign-signed RPMs | ACR-19 … ACR-21 (3) |
| P2: bazaar forked | ACR-22 … ACR-26 (5) |
| P2: GHA → Copr automation | ACR-27 … ACR-31 (5) |
| P3: Hybrid authoring | ACR-32 … ACR-35 (4) |
| P3: Operations & versioning | ACR-36 … ACR-39 (4) |

**Total**: 39 testable requirements. Status values: Pending → In Tasks → Implementing → Verified.

---

## Supersedes

**From `.specs/features/athens-os/`**:

- **ATH-09 / ATH-10** (flatpak install oneshot — idempotent, sentinel-guarded) → packaged inside `athens-os-services` (no behavioral change)
- **ATH-01** (CI push → build → tag → cosign) → extended by ACR-01/06/27–31 (image build now also installs our Copr artifact; separate Copr workflow runs on packaging changes)
- **ATH-02** (`rpm-ostree rebase` succeeds) → `rpm-ostree rebase` + `rpm -qa | grep athens-os` showing all 6 sub-packages is the new success condition

**From `.specs/features/nix-home/`**:

- **Packaging of nix-home artifacts**: `athens-nix-install.service`, `athens-nix-relabel.{service,path}`, `file_contexts.local`, `athens-hm-status.sh`, `/etc/skel/.config/home-manager/home.nix` — all get sub-package homes per ACR-13/15/16/17. No nix-home **requirements** superseded; only their delivery mechanism changes (loose files → RPMs).

**Parent project (`STATE.md`)**:

- Locked decision *"Persistent COPR pattern — `ublue-os/packages` + `docker-ce.repo`"* → superseded by this spec: `ublue-os/packages` replaced by our own Copr (bazaar forked), `docker-ce.repo` becomes a Copr external-repo (still Docker Inc's source, just aggregated).

---

## Rollout Plan

Three phases, each a separate branch + merge cycle. Later phases depend on earlier ones being green.

### Phase A — Skeleton (~3 h)

Prove the plumbing works without changing image behavior.

1. Create Copr project `athenabriana/athens-os` (public, `fedora-43-x86_64` chroot, docker-ce external repo). Record the Copr API token in GitHub secret `COPR_API_TOKEN`.
2. Write **empty** `athens-os-base.spec` — meta-package, `Requires: bazaar`, no files.
3. Fork `packages/bazaar/bazaar.spec` from `ublue-os/packages:staging/bazaar/bazaar.spec` + `packages/bazaar/UPSTREAM.md`.
4. Write `scripts/build-srpm.sh` — tarballs + runs `rpmbuild -bs`.
5. Write `.github/workflows/copr.yml` — triggers on `packages/**`, runs `copr-cli build` for every spec, signs outputs with cosign keyless.
6. Land: Copr shows `bazaar` + empty `athens-os-base`; `rpm-ostree install athens-os-base` on a clean VM pulls bazaar. Image build still uses the old path.

**Exit criterion**: all of ACR-01, ACR-02, ACR-06 (enablement only), ACR-22–26, ACR-27–31 pass.

### Phase B — Sub-package migration (~8 h, one per sitting)

Migrate concerns one at a time. Each lands as its own PR so CI can catch drift early.

Order (simplest first):
1. **`athens-os-selinux`** — one file (`file_contexts.local`), no `%post` beyond `restorecon`. Good first migration.
2. **`athens-os-shell-ux`** — one file (`athens-hm-status.sh`), `/etc/profile.d/` symlink already handled by file placement.
3. **`athens-os-skel`** — one file (`home.nix`), ships to `/etc/skel/.config/home-manager/`.
4. **`athens-os-dconf`** — `/etc/dconf/db/local.d/*` + profile + `%post dconf update`.
5. **`athens-os-services`** — the heaviest. Multiple `.service`, `.path`, and enablement-symlink files across `system-level` and `user-level` scopes.

Each migration: write spec → rebuild in Copr → verify file ownership via `rpm -qf` → land drift-detection CI.

**Exit criterion**: ACR-12–18 pass; ACR-32/33/35 operational; dev-loop via `just build-local` (ACR-34) works.

### Phase C — Cutover (~2 h)

Switch the image build to consume from Copr.

1. Edit `build.sh` — replace per-feature RPM install loop and `COPY system_files /etc` with `dnf5 copr enable athenabriana/athens-os && dnf5 install -y athens-os-base`.
2. Remove `ublue-os/packages` from `PERSISTENT_COPRS` (our own Copr now ships bazaar).
3. Delete `system_files/etc/yum.repos.d/docker-ce.repo` (external-repo aggregation makes it redundant).
4. Confirm CI goes green with the new flow.
5. Update README with the new architecture narrative.

**Exit criterion**: ACR-03, ACR-04, ACR-05, ACR-07, ACR-09, ACR-10, ACR-11 all pass; existing image users can `rpm-ostree upgrade` to the new base without losing any files.

**Deferred from Phase C** (separate future feature): delete `system_files/` entirely.

---

## Prerequisites (to validate during Phase A)

Unverified assumptions that must hold for this spec to be implementable as written:

1. **Copr's "external repos" feature accepts arbitrary dnf `.repo` URLs**, not just Copr-native repos. Specifically: can `https://download.docker.com/linux/fedora/docker-ce.repo` be added as an external repo via web UI or `copr-cli modify`? (Likely yes per Copr docs, but unverified against our actual setup.)
2. **`copr-cli` supports signing via cosign keyless OIDC** or can we run cosign on the built RPM as a post-build step and upload the `.sig` + `.crt` separately. (Cosign against arbitrary blobs is standard; integration path just needs to be confirmed.)
3. **GitHub OIDC identity tokens** authenticate `cosign sign-blob` from within a GHA workflow without additional setup beyond `permissions: id-token: write`. (Standard Sigstore keyless flow.)
4. **Running `dnf5 install athens-os-base` inside a Containerfile RUN step** does not require the build environment to have an active systemd (no `%post systemctl enable` execution at build time — deferred until first boot). ACR-37's symlink approach sidesteps this, but worth verifying.

Any assumption that breaks requires a spec revision before Phase A can proceed.

---

## Success Criteria

- [ ] Fresh VM rebase → `rpm-ostree status` lists `athens-os-base-<version>` alongside `silverblue-main-<version>`
- [ ] `rpm -qa | grep athens-os` shows all 6 sub-packages with matching versions (same `YYYYMMDD.<run>`)
- [ ] `rpm -qf` on any shipped path (`/etc/systemd/system/athens-nix-install.service`, `/etc/skel/.config/home-manager/home.nix`, `/etc/selinux/targeted/contexts/files/file_contexts.local`, `/etc/profile.d/athens-hm-status.sh`) returns exactly one `athens-os-*` package
- [ ] `cosign verify-blob` against every published RPM succeeds using only the cert-identity + OIDC-issuer flags (no pre-shared pub key)
- [ ] CI image-build time does not regress more than 2 minutes vs. pre-migration (Copr build happens in a separate workflow; image build just installs pre-built RPMs)
- [ ] Copr build failures block merges to `main` (via branch protection, once configured)
- [ ] `just build-local` produces a working image in < 30 seconds of incremental iteration (no Copr round-trip)
- [ ] Drift-detection CI job is green on every merge
- [ ] `rpm-ostree override remove athens-os-shell-ux` cleanly removes `/etc/profile.d/athens-hm-status.sh` (including enablement state) — proves sub-packaging granularity works
