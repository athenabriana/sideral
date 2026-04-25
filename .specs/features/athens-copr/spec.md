# athens-copr Specification

## Problem Statement

athens-os currently ships its system customizations as loose files under `system_files/` that the Containerfile `COPY`s into the image at build time. System-integration RPMs come from two separate external sources: `ublue-os/packages` COPR (for bazaar) and Docker Inc's `docker-ce-stable` repo file. This works, but it's architecturally unclear — users can't enumerate "what does athens-os add to silverblue-main?" as a set of versioned artifacts; rollback is "re-image or edit loose files"; users who want to strip the athens-os brand from a deployment have to manually hunt files across `/etc` and `/usr`; and `rpm-ostree rebase` runs over `ostree-unverified-registry:` — only TLS to ghcr.io stands between users and a tampered image.

Goal: consolidate all athens-os-authored customizations into a set of RPMs published from our own Copr project, signed by our CI via cosign keyless OIDC, with two upstream community repos (`ublue-os/packages` for bazaar + future ublue adoptions, and Docker Inc's official dnf repo) aggregated as Copr "external repos" so users enable **one** COPR. Additionally, ship a trust chain — both **our RPMs** and **our deployed OCI image** — verified end-to-end via cosign keyless, so `rpm-ostree rebase ostree-image-signed:registry:ghcr.io/athenabriana/athens-os:latest` becomes the canonical install command.

The feature is scoped narrowly: **we package what we author**. We do not rebuild docker-ce or bazaar — both are well-maintained upstream and we have no patches to carry. They're aggregated via Copr's external-repo feature.

## Goals

- [ ] Copr project `athenabriana/athens-os` exists (public), accepts builds from GHA, and is enabled by `dnf5 copr enable athenabriana/athens-os` in `build.sh`
- [ ] Eight sub-packages built from `packages/<name>/<name>.spec` specs in our repo: `athens-os-base`, `athens-os-services`, `athens-os-flatpaks`, `athens-os-dconf`, `athens-os-selinux`, `athens-os-shell-ux`, `athens-os-user`, `athens-os-signing`
- [ ] `athens-os-base` is a meta-package with `Requires:` on every other `athens-os-*` sub-package plus the transitive third-party deps (`docker-ce`, `containerd.io`, `bazaar`)
- [ ] Single `dnf5 install -y athens-os-base` in `build.sh` replaces the current per-feature `dnf5 install` loop + `COPY system_files /etc`
- [ ] Copr project has two external repos configured: `ublue-os/packages` (provides `bazaar` + future ublue adoptions) and `docker-ce-stable` (Docker Inc's official dnf repo, provides `docker-ce` + `containerd.io`)
- [ ] **No bazaar fork**: bazaar resolves transitively from the aggregated `ublue-os/packages` external repo — we don't host or maintain a `packages/bazaar/bazaar.spec`
- [ ] Every RPM we build is signed via cosign keyless OIDC through GitHub Actions; verification uses Sigstore's Rekor + Fulcio (no pre-shared pub key)
- [ ] **OCI image** is also signed via cosign keyless OIDC; `athens-os-signing` ships `/etc/containers/policy.json` so users can rebase with `ostree-image-signed:` and the rebase fails on signature mismatch
- [ ] GHA workflow `copr.yml` triggers on push to `main` touching `packages/**` or `system_files/**` or `home/**`; builds spec files via `copr-cli`; blocks merge on build failure
- [ ] **Per-package `src/` is the authoring source** (matches ublue-os/packages convention literally). `system_files/` and `home/` retire entirely — every file lives at `packages/<owner-package>/src/<absolute-image-path>`. Self-contained sub-packages: each `packages/<name>/` is everything that package needs to build.

## Out of Scope

| Feature | Reason |
|---|---|
| Rebuilding docker-ce in our Copr | Docker Inc maintains it; we aggregate via external-repo |
| Rebuilding bazaar in our Copr | `ublue-os/packages` maintains it (used by Bluefin/Bazzite/Aurora); we aggregate via external-repo. We have no patches to carry. |
| Pulling `ublue-os-signing` directly | Replaced by our own `athens-os-signing` sub-package (which can include ublue's policy entries if we want base-image verification too — implementation detail). Avoids file ownership conflicts on `/etc/containers/policy.json`. |
| Re-adding a browser to the RPM layer | Browser ships via flatpak (`app.zen_browser.zen`); RPM layer stays browser-free |
| Forking other ublue-os/packages specs (e.g. `ublue-os-just`) | When we have actual recipes/usage, pull them via the same external-repo aggregation — never fork without patches |
| Copr API token management via 1Password / Vault | GitHub secret is fine for personal use |
| Multi-arch builds (aarch64) | x86_64 only, same as image itself |
| Fedora versions other than 43 | Add fedora-44 chroot when F44 drops |
| Keeping `system_files/` and `home/` as authoring directories | Reversed in 2026-04-23 revision (Option B chosen); both retire as part of Phase B per-package migration |

---

## User Stories

### P1: Single-COPR enablement ⭐ MVP

**Story**: A downstream user (or our own CI) enables one Copr project and can install the entire athens-os system layer with a single `dnf5` command. All third-party dependencies resolve transitively through aggregated external repos.

**Acceptance**:

1. **ACR-01** — `athenabriana/athens-os` Copr project exists, is public, has `fedora-43-x86_64` as its only enabled chroot.
2. **ACR-02** — The Copr project lists exactly two external repos: `https://copr.fedorainfracloud.org/coprs/ublue-os/packages/repo/fedora-43/ublue-os-packages-fedora-43.repo` and `https://download.docker.com/linux/fedora/docker-ce.repo`.
3. **ACR-03** — `dnf5 repoquery athens-os-base` (with our COPR enabled) resolves and shows `Requires:` on `athens-os-services`, `athens-os-flatpaks`, `athens-os-dconf`, `athens-os-selinux`, `athens-os-shell-ux`, `athens-os-user`, `athens-os-signing`, plus transitive third-party deps `bazaar`, `docker-ce`, `containerd.io`.
4. **ACR-04** — `dnf5 install -y athens-os-base` on a vanilla silverblue-main:43 with only our Copr enabled succeeds — dnf resolves everything transitively via external repos, no additional `.repo` files needed on the user's host.
5. **ACR-05** — `rpm -q athens-os-base` on the installed system shows `athens-os-base-YYYYMMDD.<N>` with a version tied to the image release.

**Test**: Fresh silverblue-main:43 VM → `rpm-ostree install` with ONLY `athenabriana/athens-os` enabled → reboot → all 8 sub-packages present, `bazaar` + `docker-ce` + `containerd.io` present, no stray `.repo` files from removed sources.

---

### P1: Image build uses the COPR ⭐ MVP

**Story**: `build.sh` installs our meta-package instead of per-feature `dnf5` loops + `COPY system_files /etc`. The image is smaller, reproducible via the Copr artifact registry, and one line replaces dozens.

**Acceptance**:

1. **ACR-06** — `build.sh` contains exactly one `dnf5 copr enable athenabriana/athens-os` + one `dnf5 install -y athens-os-base` after the persistent COPR enablement block.
2. **ACR-07** — The per-feature RPM install loop in `build.sh` keeps only the entries for non-athens RPMs (GNOME shell extensions, docker-ce stack, fonts); all athens-os-shipped files now come via the meta-package install.
3. **ACR-08** — `build.sh` still installs Fedora-main + non-athens RPMs via per-feature `packages.txt` (GNOME shell extensions, docker-ce stack, fonts — RPMs that are NOT in our Copr and don't fit home-manager).
4. **ACR-09** — The **production** `Containerfile` no longer has `COPY system_files /etc` or `COPY home /etc/skel` — the files are owned by the RPMs. A separate dev-mode path (`Containerfile.dev` or a pre-build rsync) handles local iteration per ACR-34.
5. **ACR-10** — `bootc container lint` passes on the built image.
6. **ACR-11** — Image layer count does not increase by more than 2 vs. the pre-migration count (one new layer from the meta-package install is expected; nothing else).

**Test**: `just build` succeeds end-to-end; `podman image inspect athens-os:latest` shows the new meta-package layered; `rpm -qa | grep athens-os` lists all 8 packages.

---

### P2: Packages are sub-divided by concern

**Story**: Each sub-package owns a coherent slice of athens-os functionality. A user can remove a single sub-package (e.g., `rpm-ostree override remove athens-os-shell-ux`) and get just the behavior change for that concern.

**Acceptance**:

1. **ACR-12** — `athens-os-base` is a meta-package (no files, only `Requires:`), owns only `/etc/os-release`. Does NOT own `/etc/flatpak-manifest` (moved to `athens-os-flatpaks` per ACR-20).
2. **ACR-13** — `athens-os-services` owns the **non-flatpak** systemd units only: `/etc/systemd/system/athens-nix-install.service`, `athens-nix-relabel.service`, `athens-nix-relabel.path`, their `multi-user.target.wants/` enablement symlinks, plus `/usr/lib/systemd/user/athens-home-manager-setup.service` + its `default.target.wants/` symlink. The flatpak install service is owned by `athens-os-flatpaks` (ACR-20).
3. **ACR-14** — `athens-os-dconf` owns every file under `/etc/dconf/db/local.d/` and the `/etc/dconf/profile/user` file; its `%post` scriptlet runs `dconf update`.
4. **ACR-15** — `athens-os-selinux` owns `/etc/selinux/targeted/contexts/files/file_contexts.local` and runs `restorecon -R /nix` in `%posttrans` (no-op if `/nix` does not exist).
5. **ACR-16** — `athens-os-shell-ux` owns `/etc/profile.d/athens-hm-status.sh` and any future interactive shell hooks.
6. **ACR-17** — `athens-os-user` owns `/etc/skel/.config/home-manager/home.nix` and any future user-default dotfiles shipped via `/etc/skel`.
7. **ACR-18** — `athens-os-signing` owns `/etc/containers/policy.json` (overwriting the base image's lenient default) and any supporting files in `/etc/containers/registries.d/` for Sigstore signature lookup. Coordinated with the OCI-image signing flow per ACR-27..29.
8. **ACR-19** — `rpm -qf /etc/systemd/system/athens-nix-install.service` returns exactly `athens-os-services`. Every file shipped by athens-os is owned by exactly one sub-package; no two sub-packages claim the same path.

**Test**: `rpm-ostree override remove athens-os-shell-ux` on a deployed system → next reboot → `/etc/profile.d/athens-hm-status.sh` is gone, rest of athens-os still works.

---

### P2: Flatpak preinstall as own sub-package

**Story**: Flatpak auto-install machinery (the manifest + the systemd service that reads it + the enablement symlink) lives in its own sub-package. A user who wants their own flatpak set can `rpm-ostree override remove athens-os-flatpaks` and ship their own — without losing the rest of athens-os.

**Acceptance**:

1. **ACR-20** — `athens-os-flatpaks` owns `/etc/flatpak-manifest`, `/etc/systemd/system/athens-flatpak-install.service`, and the `multi-user.target.wants/athens-flatpak-install.service` enablement symlink. All three coupled files live in one package — no cross-package dependency between manifest and reader.
2. **ACR-21** — `rpm-ostree override remove athens-os-flatpaks` cleanly removes the curated flatpak set's auto-install path: next boot the service is absent and `/etc/flatpak-manifest` is gone. Flatpaks already installed at `/var/lib/flatpak` are NOT removed (that's the user's `flatpak uninstall` job — RPM removal doesn't touch deployed flatpak state).
3. **ACR-22** — `athens-os-base` declares `Requires: athens-os-flatpaks` (default install pulls the curated set); a user wanting to opt out replaces base's dependency closure via `rpm-ostree override remove athens-os-flatpaks` after install.
4. **ACR-23** — The current 8-ref manifest (Zen Browser + 7 GUI apps) ships in this package; future additions/removals to the curated flatpak set are made by editing `packages/athens-os-flatpaks/src/etc/flatpak-manifest` and rebuilding only `athens-os-flatpaks` (no rebuild of unrelated sub-packages).

**Test**: Fresh image with athens-os-base installed → reboot → `flatpak list --app` shows 8 refs. `rpm-ostree override remove athens-os-flatpaks` → next reboot → `/etc/flatpak-manifest` absent, but already-installed flatpaks remain in `/var/lib/flatpak`.

---

### P2: Cosign-signed RPMs with keyless OIDC

**Story**: Every RPM built by our GHA workflow is signed by cosign via GitHub OIDC, and the signature can be verified on any host with `cosign` and the documented identity flags.

**Acceptance**:

1. **ACR-24** — The `copr.yml` workflow runs `cosign sign-blob --yes` on every produced `.rpm` and `.src.rpm` using GitHub's OIDC identity token (Sigstore keyless flow — no pre-shared private key); signatures land in the Copr results directory alongside the binaries.
2. **ACR-25** — `cosign verify-blob --certificate-identity "https://github.com/athenabriana/athens-os/.github/workflows/copr.yml@refs/heads/main" --certificate-oidc-issuer "https://token.actions.githubusercontent.com" --signature <sig> --certificate <cert> <rpm>` succeeds for every published RPM (verifies against Sigstore Rekor transparency log + Fulcio CA; no local pub key needed).
3. **ACR-26** — README documents the full `cosign verify-blob` command with the correct `--certificate-identity` and `--certificate-oidc-issuer` flags so users can verify on a clean machine without cloning the repo first.

**Test**: On a host with only `cosign` installed, run the command from ACR-26 against a fresh published RPM — exit code 0.

---

### P2: Signed image rebase trust chain

**Story**: athens-os OCI images are signed by our CI via cosign keyless OIDC, and `athens-os-signing` configures the consumer side so `rpm-ostree rebase ostree-image-signed:registry:ghcr.io/athenabriana/athens-os:latest` is the canonical install command — failing safely if the registry is tampered with.

**Acceptance**:

1. **ACR-27** — The image-build workflow (`.github/workflows/build.yml`) runs `cosign sign --yes ghcr.io/athenabriana/athens-os@${{ steps.push.outputs.digest }}` after the registry push, using GitHub's OIDC identity token. Signature object is stored in the OCI registry alongside the image.
2. **ACR-28** — `athens-os-signing` ships `/etc/containers/policy.json` with a `default: insecureAcceptAnything` baseline (preserves user's normal podman/skopeo workflow) plus a `transports.docker."ghcr.io/athenabriana/athens-os"` rule of type `sigstoreSigned` referencing the Fulcio root CA + the workflow's OIDC identity (`https://github.com/athenabriana/athens-os/.github/workflows/build.yml@refs/heads/main`) and OIDC issuer (`https://token.actions.githubusercontent.com`). No static pub key — keyless verification only.
3. **ACR-29** — On a fresh machine with athens-os-signing installed, `rpm-ostree rebase ostree-image-signed:registry:ghcr.io/athenabriana/athens-os:latest` succeeds. With `athens-os-signing` removed (or the registry tampered with), the same command fails with a signature-mismatch error before any image content is applied. README documents the signed rebase URL and verification command (`cosign verify ghcr.io/athenabriana/athens-os:latest --certificate-identity ... --certificate-oidc-issuer ...`).

**Test**: From clean silverblue-main:43 VM → install athens-os-signing → `rpm-ostree rebase ostree-image-signed:registry:...` succeeds. Then on another VM, manually mangle a byte in the local image cache → rebase fails loudly. Documented commands in README work as written.

---

### P2: GHA → Copr automation

**Story**: Pushing changes to packaging-relevant paths on `main` triggers a GHA workflow that rebuilds the affected spec files in Copr and pushes fresh RPMs. Merge is blocked if the Copr build fails.

**Acceptance**:

1. **ACR-30** — `.github/workflows/copr.yml` exists and triggers on push to `main` touching `packages/**`, `system_files/**`, or `home/**`.
2. **ACR-31** — The workflow authenticates to Copr via an API token stored in GitHub secret `COPR_API_TOKEN`.
3. **ACR-32** — The workflow runs `copr-cli build athens-os packages/<name>/<name>.spec` for each changed spec file (or, simpler, for all specs on every relevant push).
4. **ACR-33** — A failed Copr build causes the workflow to exit non-zero; the main branch protection rule (when configured) blocks further merges until fixed.
5. **ACR-34** — Successful builds publish to `https://download.copr.fedorainfracloud.org/results/athenabriana/athens-os/` within 5 minutes of workflow completion.

**Test**: Edit a spec → push to a temporary branch → open PR → CI builds in Copr, workflow reports success → merge.

---

### P3: Self-contained sub-packages (per-package src/)

**Story**: Each `packages/<name>/` directory is genuinely self-contained — its `.spec` file plus its `src/` tree of staging files is everything the package needs to build. No central `system_files/` or `home/` directory exists. Local `just build-local` overlays all `packages/*/src/` trees into the image without going through Copr.

**Acceptance**:

1. **ACR-35** — Every `packages/<name>/<name>.spec` uses `Source0: %{name}-%{version}.tar.gz` and the `%install` section unpacks the tarball into `%{buildroot}` preserving the absolute-path layout (`packages/<name>/src/etc/foo` → `/etc/foo` in the installed RPM).
2. **ACR-36** — A script `scripts/build-srpm.sh` (new) creates the SRPM for each package by tarballing exactly `packages/<name>/src/` and invoking `rpmbuild -bs`. No per-package file lists in the script — each package's content is whatever's in its `src/` subtree.
3. **ACR-37** — `just build-local` produces a functioning image in under 30 seconds of incremental dev iteration (no Copr round-trip). Implementation: a `Containerfile.dev` that overlays every `packages/*/src/` tree into the image at build time (`for d in packages/*/src; do cp -a "$d/." /; done`), skipping the RPM-install step for athens-os-* packages. `just build-release` runs the canonical `Containerfile` (installs from Copr). Both variants are documented in README.
4. **ACR-38** — Drift detection: CI job runs `rpm -ql athens-os-<name>` for each sub-package and diffs the output against `find packages/<name>/src/ -type f` (with the `packages/<name>/src/` prefix stripped). Non-empty diff exits non-zero. Trivial because the source-of-truth file layout matches `%files` exactly.

**Test**: Edit `packages/athens-os-shell-ux/src/etc/profile.d/athens-hm-status.sh`, run `just build-local` → script is in the image. Push → Copr rebuilds `athens-os-shell-ux` → `just build-release` → script comes from the RPM, same content.

---

### P3: Operations & versioning

**Story**: The packaging and release mechanics are specified — not left as "figure it out at implementation time" — so every build is reproducible and every systemd unit we ship actually activates when its RPM is installed.

**Acceptance**:

1. **ACR-39** — Package version is `YYYYMMDD.<run_number>` where `YYYYMMDD` is the GHA run date (UTC) and `run_number` is `${{ github.run_number }}`. The version is stamped identically on every sub-package produced by the same workflow run so they all `Requires:` each other by exact `=` match without drift.
2. **ACR-40** — Systemd unit enablement is handled by RPM `%files` listing the `multi-user.target.wants/` + `default.target.wants/` symlinks directly (not by `%post systemctl enable`). This makes `rpm-ostree override remove <pkg>` cleanly remove the symlinks along with the unit files — no orphaned enablement state. Exception: `athens-os-dconf` uses `%post dconf update` because that isn't a file-ownership operation.
3. **ACR-41** — Every push to `main` touching `packages/**` or `system_files/**` or `home/**` that the build succeeds on produces a new versioned tarball uploaded to GHA artifacts, retained 30 days; used as a build-cache fallback if Copr is unreachable on a later image build.

---

## Edge Cases

- **Copr build failure**: GHA workflow exits non-zero; main branch is "yellow" (build failed) until fixed. Image build is not affected until we switch `build.sh` to depend on the new Copr (gated behind ACR-06).
- **Copr is down during image build**: `dnf5 copr enable athenabriana/athens-os` or the subsequent `install` fails. Fallback path (per ACR-41): the image-build workflow falls back to a GHA-cached `athens-os-base-<version>.rpm` from a prior successful run. If no cache exists yet, image build fails loudly.
- **`ublue-os/packages` external repo outage**: `bazaar` fails to resolve during `dnf install athens-os-base`. Image build fails. Same failure mode as the current `PERSISTENT_COPRS` setup; no regression.
- **External repo outage (docker-ce.repo)**: If Docker's repo is unreachable during `rpm-ostree rebase`, the rebase fails. Same failure mode as current `docker-ce.repo`-based setup; no regression.
- **Sigstore is down during signed rebase**: `rpm-ostree rebase ostree-image-signed:...` fails because the policy.json check can't reach Rekor/Fulcio. User can fall back to `ostree-unverified-registry:` for a one-time emergency install (documented in README, but discouraged). Sigstore status: https://status.sigstore.dev.
- **Fedora version bump (43 → 44)**: When silverblue-main bumps base, Copr needs the new chroot added (`fedora-44-x86_64`) and `build.sh` needs the new enablement. Rollout plan: add the new chroot to Copr first, let builds succeed on both chroots in parallel, switch the image base, then drop the old chroot after one release cycle.
- **`ublue-os/packages` upstream removes a package we depend on** (e.g., bazaar deprecated): image build fails on `Requires: bazaar` resolution. Mitigation: pin `Requires: bazaar >= X.Y` on a known-stable version; if upstream drops it entirely, fall back to forking that one spec into our tree (a one-time emergency, not the steady state).
- **OIDC identity changes** (e.g., we rename the workflow file or move to a different branch): existing signatures fail verification on user machines. Mitigation: ship a transition release with the new identity in policy.json BEFORE pushing the next signed image; document in CHANGELOG.
- **Sub-package rename collision with Fedora-main package**: All `athens-os-*` names are namespaced to prevent collision.
- **User modifies a file owned by `athens-os-shell-ux`** (or any sub-package): `rpm-ostree upgrade` treats this as a conflict; `.rpmnew` file is created. Standard RPM behavior.
- **Copr API token leak**: Rotate token in Copr web UI, update GitHub secret, force-rebuild. No user-visible impact.

---

## Requirement Traceability

| Story | Requirement IDs |
|---|---|
| P1: Single-COPR enablement | ACR-01 … ACR-05 (5) |
| P1: Image build uses the COPR | ACR-06 … ACR-11 (6) |
| P2: Sub-divided by concern | ACR-12 … ACR-19 (8) |
| P2: Flatpak preinstall sub-package | ACR-20 … ACR-23 (4) |
| P2: Cosign-signed RPMs | ACR-24 … ACR-26 (3) |
| P2: Signed image rebase trust chain | ACR-27 … ACR-29 (3) |
| P2: GHA → Copr automation | ACR-30 … ACR-34 (5) |
| P3: Hybrid authoring | ACR-35 … ACR-38 (4) |
| P3: Operations & versioning | ACR-39 … ACR-41 (3) |

**Total**: 41 testable requirements. Status values: Pending → In Tasks → Implementing → Verified.

---

## Supersedes

**From `.specs/features/athens-os/`**:

- **ATH-09 / ATH-10** (flatpak install oneshot — idempotent, sentinel-guarded) → packaged inside `athens-os-flatpaks` (no behavioral change; just relocated to its own sub-package per ACR-20)
- **ATH-13** (the manifest itself with 8 refs) → owned by `athens-os-flatpaks`
- **ATH-01** (CI push → build → tag → cosign image) → extended by ACR-01/06/27/30–34 (image build now also installs our Copr artifact AND signs the OCI image; separate Copr workflow runs on packaging changes)
- **ATH-02** (`rpm-ostree rebase` succeeds via `ostree-unverified-registry:`) → upgraded to `rpm-ostree rebase ostree-image-signed:registry:...` per ACR-29; falls back to unverified only as documented escape hatch

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
2. Write **empty** `athens-os-base.spec` — meta-package, `Requires: bazaar, docker-ce, containerd.io, athens-os-signing` (the rest of athens-os-* sub-packages will be added during Phase B), no files.
3. Write `scripts/build-srpm.sh` — tarballs + runs `rpmbuild -bs`.
4. Write `.github/workflows/copr.yml` — triggers on `packages/**`, runs `copr-cli build` for every spec, signs outputs with cosign keyless.
5. Extend `.github/workflows/build.yml` to run `cosign sign --yes ghcr.io/athenabriana/athens-os@${digest}` after the registry push (ACR-27 — image signing, separate concern from RPM signing).
6. Land: Copr project shows empty `athens-os-base`; `dnf5 install athens-os-base` on a clean VM with only our Copr enabled pulls bazaar + docker-ce + containerd.io transitively from external repos. Image build still uses the old path.

**Exit criterion**: ACR-01, ACR-02, ACR-04 (transitive resolution proven), ACR-24–26 (RPM signing pipeline proven), ACR-27 (image signing pipeline proven), ACR-30–34 (workflow proven) pass.

### Phase B — Sub-package migration (~12 h, one per sitting)

Migrate concerns one at a time. Each lands as its own PR so CI can catch drift early. Each migration is **two coupled changes**: (a) `git mv` files from `system_files/` (or `home/`) into `packages/<pkg>/src/`, preserving absolute-path layout; (b) write the package's `.spec` file. After all migrations, both `system_files/` and `home/` are empty and `git rm -rf` cleans them up at the start of Phase C.

Order (simplest first):
1. **`athens-os-selinux`** — one file. `git mv system_files/etc/selinux/targeted/contexts/files/file_contexts.local packages/athens-os-selinux/src/etc/selinux/targeted/contexts/files/file_contexts.local` + write spec with `%posttrans restorecon`. Good first migration.
2. **`athens-os-shell-ux`** — one file (`athens-hm-status.sh` → `packages/athens-os-shell-ux/src/etc/profile.d/`).
3. **`athens-os-user`** — one file. `git mv home/.config/home-manager/home.nix packages/athens-os-user/src/etc/skel/.config/home-manager/home.nix`. Empties the `home/` top-level dir; remove it. Update Justfile recipes that reference `home/.config/...` to point at the new path.
4. **`athens-os-signing`** — author `packages/athens-os-signing/src/etc/containers/policy.json` from scratch (no equivalent in current `system_files/`). Validate full ACR-27..29 trust chain end-to-end against a real signed image.
5. **`athens-os-flatpaks`** — `git mv` the manifest + service + enablement symlink as a coupled trio. Validate with `rpm-ostree override remove athens-os-flatpaks` removal-roundtrip test.
6. **`athens-os-dconf`** — `git mv` all `/etc/dconf/db/local.d/*` + profile file. Spec runs `%post dconf update`.
7. **`athens-os-services`** — heaviest. `git mv` all `athens-*.service`, `.path`, and the `multi-user.target.wants/` + `default.target.wants/` enablement symlinks across system + user scopes. After this migration, `system_files/` should be reduced to RPM-feature artifacts only (none — at this point `system_files/` is empty and gets removed in Phase C).

Each migration: `git mv` → write spec → rebuild in Copr → verify file ownership via `rpm -qf` → land drift-detection CI.

**Exit criterion**: ACR-12–23 pass; ACR-28/29 (signing trust chain proven on real hardware); ACR-35/36/38 operational; dev-loop via `just build-local` (ACR-37) works; both `system_files/` and `home/` directories are empty (ready for Phase C deletion).

### Phase C — Cutover (~2 h)

Switch the image build to consume from Copr; delete the now-empty legacy directories.

> **Pre-Phase-C state**: At the end of Phase B, every athens-os-shipped file lives at `packages/<pkg>/src/<absolute-path>`. `system_files/` and `home/` are empty (or contain only `docker-ce.repo`, which is also retired in Phase C since the external-repo aggregation handles it). `build_files/features/` has only `gnome/`, `gnome-extensions/`, `container/`, `fonts/` left.

1. **Delete legacy directories**:
   ```bash
   git rm -rf system_files/ home/
   ```
   Every file that was previously here now lives in its owner package's `src/` tree.
2. Edit `build.sh`:
   ```diff
   + dnf5 -y copr enable athenabriana/athens-os
   + dnf5 -y install --setopt=install_weak_deps=False athens-os-base
   ```
   Per-feature loop stays for the non-athens RPMs (GNOME extensions, docker-ce stack, fonts).
3. Remove `ublue-os/packages` from `PERSISTENT_COPRS` (our own Copr's external-repo aggregation handles bazaar transitively).
4. Delete the Containerfile's `COPY system_files /etc` and `COPY home /etc/skel` — those directories don't exist anymore.
5. Add a new `Containerfile.dev` that overlays every `packages/*/src/` tree into the image at build time (per ACR-37). One-liner: `RUN for d in /ctx/packages/*/src; do cp -a "$d/." /; done`.
6. Update `Justfile`: rename existing `just build` → `just build-release`; add new `just build-local` that uses `Containerfile.dev`. Update home-iteration recipes (`home-edit`, `home-apply`, `home-diff`, `home-capture`) to point at `packages/athens-os-user/src/etc/skel/.config/home-manager/home.nix`.
7. Update README's installation command to use `ostree-image-signed:` URL (per ACR-29).
8. Confirm CI goes green with the new flow.
9. Update README with the new architecture narrative + verification commands.

**Exit criterion**: ACR-03, ACR-05, ACR-07, ACR-09, ACR-10, ACR-11 all pass; existing image users can `rpm-ostree upgrade` to the new base without losing any files; `rpm-ostree rebase ostree-image-signed:...` is the documented install path; both `system_files/` and `home/` directories are gone from the repo.

---

## Prerequisites (to validate during Phase A)

Unverified assumptions that must hold for this spec to be implementable as written:

1. **Copr's "external repos" feature accepts both Copr-native URLs AND arbitrary dnf `.repo` URLs.** Specifically: can both `https://copr.fedorainfracloud.org/coprs/ublue-os/packages/repo/fedora-43/...` AND `https://download.docker.com/linux/fedora/docker-ce.repo` be added as external repos via web UI or `copr-cli modify`? (Likely yes per Copr docs, but unverified against our actual setup.)
2. **`copr-cli` supports signing via cosign keyless OIDC** or we can run cosign on the built RPM as a post-build step and upload the `.sig` + `.crt` separately. (Cosign against arbitrary blobs is standard; integration path just needs to be confirmed.)
3. **GitHub OIDC identity tokens** authenticate `cosign sign-blob` and `cosign sign` (image) from within a GHA workflow without additional setup beyond `permissions: id-token: write`. (Standard Sigstore keyless flow.)
4. **`policy.json` keyless `sigstoreSigned` rule supports OIDC issuer + workflow identity** without a static pub key. Verified path: `containers/image` library v5.30+ supports `fulcio:` and `rekorPublicKeyData:` blocks — confirm the version shipped in silverblue-main:43.
5. **Running `dnf5 install athens-os-base` inside a Containerfile RUN step** does not require the build environment to have an active systemd (no `%post systemctl enable` execution at build time — deferred until first boot). ACR-40's symlink approach sidesteps this, but worth verifying.

Any assumption that breaks requires a spec revision before Phase A can proceed.

---

## Success Criteria

- [ ] Fresh VM rebase via `rpm-ostree rebase ostree-image-signed:registry:ghcr.io/athenabriana/athens-os:latest` succeeds; tampering with the registry or image content makes it fail loudly
- [ ] `rpm-ostree status` lists `athens-os-base-<version>` alongside `silverblue-main-<version>`
- [ ] `rpm -qa | grep athens-os` shows all 8 sub-packages with matching versions (same `YYYYMMDD.<run>`)
- [ ] `rpm -qf` on any shipped path (`/etc/systemd/system/athens-nix-install.service`, `/etc/skel/.config/home-manager/home.nix`, `/etc/selinux/targeted/contexts/files/file_contexts.local`, `/etc/profile.d/athens-hm-status.sh`, `/etc/flatpak-manifest`, `/etc/containers/policy.json`) returns exactly one `athens-os-*` package
- [ ] `cosign verify-blob` against every published RPM succeeds using only the cert-identity + OIDC-issuer flags (no pre-shared pub key)
- [ ] `cosign verify ghcr.io/athenabriana/athens-os:latest` succeeds with the same cert-identity + OIDC-issuer flags
- [ ] CI image-build time does not regress more than 2 minutes vs. pre-migration (Copr build happens in a separate workflow; image build just installs pre-built RPMs)
- [ ] Copr build failures block merges to `main` (via branch protection, once configured)
- [ ] `just build-local` produces a working image in < 30 seconds of incremental iteration (no Copr round-trip)
- [ ] Drift-detection CI job is green on every merge
- [ ] `rpm-ostree override remove athens-os-shell-ux` cleanly removes `/etc/profile.d/athens-hm-status.sh` (including enablement state) — proves sub-packaging granularity works
- [ ] `rpm-ostree override remove athens-os-flatpaks` cleanly removes the flatpak auto-install path (manifest + service + symlink) — proves the new sub-package boundary
- [ ] `rpm-ostree override remove athens-os-signing` falls back to `insecureAcceptAnything` default; subsequent `rpm-ostree rebase ostree-image-signed:...` fails (proves the trust chain is enforced via athens-os-signing, not silently bypassed)
- [ ] Repo top-level after Phase C contains no `system_files/` or `home/` directories — every athens-os file lives under `packages/<owner>/src/`. `git ls-files | grep -E '^(system_files|home)/'` returns empty.
