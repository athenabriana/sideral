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
3. **ACR-08** — `build.sh` still installs Fedora-main-only RPMs via per-feature `packages.txt` (GNOME shell extensions, kernel debug stack, git plugins — RPMs that are NOT in our Copr).
4. **ACR-09** — The Containerfile no longer has `COPY system_files /etc` or `COPY home /etc/skel` — the files are owned by the RPMs.
5. **ACR-10** — `bootc container lint` passes on the built image.
6. **ACR-11** — Image layer count does not increase by more than 2 vs. the pre-migration count (one new layer from the meta-package install is expected; nothing else).

**Test**: `just build` succeeds end-to-end; `podman image inspect athens-os:latest` shows the new meta-package layered; `rpm -qa | grep athens-os` lists all 6 packages.

---

### P2: Packages are sub-divided by concern

**Story**: Each sub-package owns a coherent slice of athens-os functionality. A user can remove a single sub-package (e.g., `rpm-ostree override remove athens-os-shell-ux`) and get just the behavior change for that concern.

**Acceptance**:

1. **ACR-12** — `athens-os-base` is a meta-package (no files, only `Requires:`), owns only `/etc/os-release` and `/etc/flatpak-manifest`.
2. **ACR-13** — `athens-os-services` owns every file under `/etc/systemd/system/athens-*.service`, `/etc/systemd/system/athens-*.path`, and the `multi-user.target.wants/` + `default.target.wants/` enablement symlinks, plus the user-level units under `/usr/lib/systemd/user/athens-*.service`.
4. **ACR-14** — `athens-os-dconf` owns every file under `/etc/dconf/db/local.d/` and the `/etc/dconf/profile/user` file; its `%post` scriptlet runs `dconf update`.
5. **ACR-15** — `athens-os-selinux` owns `/etc/selinux/targeted/contexts/files/file_contexts.local` and runs `restorecon -R /nix` in `%posttrans` (no-op if `/nix` does not exist).
6. **ACR-16** — `athens-os-shell-ux` owns `/etc/profile.d/athens-hm-status.sh` and any future interactive shell hooks.
7. **ACR-17** — `athens-os-skel` owns `/etc/skel/.config/home-manager/home.nix` and any future dotfiles shipped via skel.
8. **ACR-18** — `rpm -qf /etc/systemd/system/athens-nix-install.service` returns exactly `athens-os-services`. Every file shipped by athens-os is owned by exactly one sub-package.

**Test**: `rpm-ostree override remove athens-os-shell-ux` on a deployed system → next reboot → `/etc/profile.d/athens-hm-status.sh` is gone, rest of athens-os still works.

---

### P2: Cosign-signed RPMs with keyless OIDC

**Story**: Every RPM built by our GHA workflow is signed by cosign via GitHub OIDC, and the signature can be verified on any host with `cosign.pub` and `cosign verify-blob`.

**Acceptance**:

1. **ACR-19** — The `copr.yml` workflow runs `cosign sign-blob --identity-token $(gh auth token)` on every produced `.rpm` and `.src.rpm`, pushing the signatures into the Copr project alongside the binaries.
2. **ACR-20** — `cosign verify-blob --certificate-identity "https://github.com/athenabriana/athens-os/.github/workflows/copr.yml@refs/heads/main" --certificate-oidc-issuer "https://token.actions.githubusercontent.com" <rpm>` succeeds for every published RPM.
3. **ACR-21** — `cosign.pub` is committed to the repo root, matches the key derived from OIDC, and is embedded in the image via `athens-os-base` for offline verification.

**Test**: `cosign verify-blob` against a published RPM with the committed `cosign.pub` returns exit code 0.

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
2. **ACR-33** — A script `packages/build-srpm.sh` (new) creates the SRPM for each package by tarballing the relevant subset of `system_files/` and invoking `rpmbuild -bs`.
3. **ACR-34** — `just build-local` runs the pre-migration flow (`COPY system_files /etc`, no Copr dependency) and produces a functioning image suitable for iteration. `just build-release` runs the new flow (install from Copr). Both variants are documented.
4. **ACR-35** — Drift detection: a CI job compares files shipped by the athens-os sub-packages against files in `system_files/` + `home/`. If they diverge, the job fails loudly.

**Test**: Edit `system_files/etc/profile.d/athens-hm-status.sh`, run `just build-local` → script is in the image. Push → Copr rebuilds `athens-os-shell-ux` → `just build-release` → script comes from the RPM, same content.

---

## Edge Cases

- **Copr build failure**: GHA workflow exits non-zero; main branch is "yellow" (build failed) until fixed. Image build is not affected until we switch `build.sh` to depend on the new Copr (gated behind ACR-06).
- **External repo outage (docker-ce.repo)**: If Docker's repo is unreachable during `rpm-ostree rebase`, the rebase fails. Same failure mode as current `docker-ce.repo`-based setup; no regression.
- **Sub-package rename collision with Fedora-main package**: All `athens-os-*` names are namespaced to prevent collision; `bazaar` (un-namespaced fork) keeps upstream name intentionally.
- **User modifies a file owned by `athens-os-shell-ux`**: `rpm-ostree upgrade` treats this as a conflict; `.rpmnew` file is created. Standard RPM behavior.
- **Copr API token leak**: Rotate token in Copr web UI, update GitHub secret, force-rebuild. No user-visible impact.
- **Cosign signature verification fails on a user's machine**: They can still install via `dnf5 --nogpgcheck` as an escape hatch, but the image-build workflow always signs and never disables verification.

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

**Total**: 35 testable requirements. Status values: Pending → In Tasks → Implementing → Verified.

---

## Supersedes

**From `.specs/features/athens-os/`**:

- ATH-10 (`flatpak-install service is system-level`) — unchanged, moves into `athens-os-services`
- Parts of ATH-01/ATH-02 (image build recipe) — refactored as `athens-os-base` install

**From `.specs/features/nix-home/`**:

- No requirements superseded; nix-home services move into `athens-os-services` unchanged.

---

## Success Criteria

- [ ] Fresh VM rebase → `rpm-ostree status` lists `athens-os-base-<version>` alongside `silverblue-main-<version>`
- [ ] `rpm -qa | grep athens-os` shows all 6 sub-packages with matching versions
- [ ] `rpm -qf` on any shipped path (`/etc/systemd/system/athens-nix-install.service`, `/etc/skel/.config/home-manager/home.nix`, `/etc/selinux/targeted/contexts/files/file_contexts.local`, `/etc/profile.d/athens-hm-status.sh`) returns exactly one `athens-os-*` package
- [ ] Cosign verification passes on every published RPM using the committed `cosign.pub`
- [ ] CI build time does not regress more than 2 minutes vs. pre-migration (Copr build happens async; image build just installs RPMs)
- [ ] Copr build failures block merges to `main`
- [ ] `just build-local` still works for dev iteration without Copr dependency
