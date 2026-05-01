# sideral-rpms Specification

## Problem Statement

sideral currently ships its system customizations as loose files under `packages/<name>/src/` that the Containerfile overlays into the image at build time (`cp -a packages/*/src/. /`). This works, but it loses everything RPMs give you: no `rpm -qa` enumeration of sideral customizations, no clean removal via `dnf remove`, no file-ownership tracking, no conflict detection. The original plan (`sideral-copr`) was to fix this by publishing RPMs through a Copr project signed via cosign keyless OIDC, but that path requires a Copr account, a `COPR_API_TOKEN` GitHub secret, and ongoing maintenance of the external service — friction the user does not want to take on.

Goal: get the benefits of real RPM packaging (rpmdb tracking, clean removal, conflict detection, granular sub-package opt-out) **without** publishing RPMs anywhere. Build the RPMs *inline* during the image build — `rpmbuild -bb` runs inside a Containerfile RUN step, the resulting `.rpm` files are immediately installed via `dnf5 install`, and the build-tools (`rpm-build`, `rpmdevtools`) are removed in the same RUN layer so they don't bloat the final image. The RPMs exist only inside the image; the rebuild is the upgrade mechanism.

The feature is scoped narrowly: **we package what we author, we install it locally**. We do not publish RPMs, we do not run a Copr project, we do not need API tokens. Third-party deps (`docker-ce`, `containerd.io`) come from their existing dnf repos at build time (docker-ce-stable). *(Pre-2026-05-01 also listed `bazaar` from `ublue-os/packages` COPR; that COPR was retired alongside the Bazaar→GNOME-Software swap — see `.specs/features/sideral/context.md` decision #6 banner.)*

## Goals

- [ ] Eight sub-packages built from `packages/<name>/<name>.spec` specs in our repo: `sideral-base`, `sideral-services`, `sideral-flatpaks`, `sideral-dconf`, `sideral-selinux`, `sideral-shell-ux`, `sideral-user`, `sideral-signing`
- [ ] `sideral-base` is a meta-package with `Requires:` on every other `sideral-*` sub-package plus the third-party deps already present (`docker-ce`, `containerd.io`). *(Bazaar Requires removed 2026-05-01.)*
- [ ] Containerfile builds all 8 RPMs inline via `rpmbuild -bb`, installs them with `dnf5 install`, and removes the build toolchain — all in one RUN layer so the final image carries zero rpmbuild artifacts
- [ ] **Per-package `src/` is the authoring source** (already in place). Each `packages/<name>/` is genuinely self-contained: `.spec` + `src/` tree is everything the package needs to build.
- [ ] **OCI image** signed via cosign keyless OIDC; `sideral-signing` ships `/etc/containers/policy.json` so users can rebase with `ostree-image-signed:` and the rebase fails on signature mismatch (independent of RPM publishing — image signing was always the actually-useful trust boundary)
- [ ] Single canonical build path: `just build` runs the inline-RPM Containerfile end-to-end. The previous `cp -a packages/*/src/. /` overlay is retired — rpmbuild adds ~tens of seconds and the granularity benefits (rpmdb tracking, `rpm-ostree override remove`) are worth it even for local iteration

## Out of Scope

| Feature | Reason |
|---|---|
| Publishing RPMs to Copr or any external repo | This is the whole point of the rewrite — no token, no external service, no maintenance. RPMs exist only inside the image. |
| Cosign-signing individual RPMs | If RPMs aren't published, signing them is theater. Image-level signing (ACR-27..29) gives the meaningful trust boundary. |
| GHA `copr.yml` workflow + `COPR_API_TOKEN` secret | Both deleted. Image build pipeline does the rpmbuild inline. |
| Rebuilding docker-ce | Unchanged from `sideral-copr`: Docker Inc maintains it. We consume from `docker-ce-stable` at build time. *(Bazaar removed entirely 2026-05-01; replaced by `gnome-software` from Fedora main.)* |
| Browser packaging | Browser is **`helium-bin`** from the `imput/helium` COPR (RPM, baked into the OCI image at build time). The 2026-04-23 retreat to a flatpak browser is reversed as of 2026-05-01 — see ATH-12 in `.specs/features/sideral/spec.md`. |
| Multi-arch builds (aarch64) | x86_64 only, same as image itself. |
| Fedora versions other than 43 | Build runs against the live silverblue-main:43 base; F44 happens when we rebase the image. |
| Pulling `ublue-os-signing` directly | We ship our own `sideral-signing` so the Sigstore policy targets *our* registry/identity rather than ublue's. The file-ownership conflict on `/etc/containers/policy.json` (vs `containers-common`) still exists either way and is resolved via `rpm -Uvh --replacefiles` (ACR-02). |

---

## User Stories

### P1: Inline RPM build inside the image ⭐ MVP

**Story**: The Containerfile builds all 8 sideral RPMs from spec files, installs them, and removes the build toolchain in a single RUN layer. The resulting image has every sideral customization tracked in its rpmdb without any external service or signing infrastructure required.

**Acceptance**:

1. **ACR-01** — A helper script `scripts/build-rpms.sh` exists that, given the `packages/` directory, produces one `.rpm` per `packages/<name>/<name>.spec`. For each package: tarballs `packages/<name>/src/` as `<name>-<version>.tar.gz` with the dirname `<name>-<version>/` prefix, places it in `SOURCES/`, copies the spec to `SPECS/`, runs `rpmbuild -bb --define "_topdir <topdir>" --define "_sideral_version <version>"`, and emits the resulting RPMs to a single output directory.
2. **ACR-02** — The Containerfile has one RUN block that: (a) `dnf5 install -y rpm-build rpmdevtools`, (b) runs `scripts/build-rpms.sh` against the bind-mounted `packages/`, (c) installs the produced RPMs via `rpm -Uvh --replacefiles --replacepkgs` (transfers ownership of conflict files like `/etc/os-release`, `/etc/containers/policy.json`, `/etc/yum.repos.d/docker-ce.repo` from base-image packages — standard derivative-distro pattern; dnf install rejects file conflicts so we drop to rpm directly), (d) `rpm -e rpm-build rpmdevtools` (NOT `dnf remove`, which auto-removes ~73 transitively-pulled packages including cpio/diffutils/elfutils/file that are part of the silverblue base), (e) cleans rpmbuild scratch dirs. All five steps in one RUN so the final image layer carries no build-time-only state.
3. **ACR-03** — `rpm -qa | grep ^sideral-` on the built image lists exactly 8 packages, all with the same `<version>` stamp.
4. **ACR-04** — `bootc container lint` is the **final** RUN in the Containerfile (no `ostree container commit` after it; nothing layered on top) and passes on the built image. Final placement is normative — adding any RUN below it risks layering content the lint never inspected.
5. **ACR-05** — Image final size grows by no more than 5 MB vs. the current overlay-only approach (the RPMs add their metadata; the build toolchain is removed in the same layer so contributes ~0).

**Test**: `just build` succeeds end-to-end; `podman image inspect sideral:latest` shows the inline-build layer; `rpm -qa | grep sideral` lists all 8 packages with matching versions.

---

### P1: Sub-divided by concern (preserved from `sideral-copr`)

**Story**: Each sub-package owns a coherent slice of sideral functionality. A user can remove a single sub-package (e.g., `rpm-ostree override remove sideral-shell-ux`) and get just the behavior change for that concern.

**Acceptance**:

1. **ACR-12** — `sideral-base` is a meta-package (no files, only `Requires:`), owns only `/etc/os-release`, `/etc/distrobox/distrobox.conf`, and `/etc/yum.repos.d/docker-ce.repo`. Does NOT own `/etc/flatpak-manifest` (moved to `sideral-flatpaks` per ACR-20).
2. **ACR-13** — `sideral-services` owns the **non-flatpak** systemd units only: `/etc/systemd/system/sideral-nix-install.service`, `sideral-nix-relabel.service`, `sideral-nix-relabel.path`, their `multi-user.target.wants/` enablement symlinks, plus `/usr/lib/systemd/user/sideral-home-manager-setup.service` + its `default.target.wants/` symlink. The flatpak install service is owned by `sideral-flatpaks` (ACR-20).
3. **ACR-14** — `sideral-dconf` owns every file under `/etc/dconf/db/local.d/` and the `/etc/dconf/profile/user` file; its `%post` scriptlet runs `dconf update`. The Containerfile additionally has a standalone `RUN dconf update && ostree container commit` step after the RPM-install layer — this is the authoritative compile of the local dconf DB at image-build time. The `%post` covers the live-system override case (`rpm-ostree install sideral-dconf` on a running deployment); the standalone RUN covers the image-build case where `%post` runs inside the rpm-ostree commit boundary and may not produce a usable on-disk DB by itself.
4. **ACR-15** — `sideral-selinux` owns `/etc/selinux/targeted/contexts/files/file_contexts.local` and runs `restorecon -R /nix` in `%posttrans` (no-op if `/nix` does not exist).
5. **ACR-16** — `sideral-shell-ux` owns `/etc/profile.d/sideral-hm-status.sh` and any future interactive shell hooks.
6. **ACR-17** — `sideral-user` owns `/etc/skel/.config/home-manager/home.nix` and any future user-default dotfiles shipped via `/etc/skel`.
7. **ACR-18** — `sideral-signing` owns `/etc/containers/policy.json` (overwriting the base image's lenient default) and any supporting files in `/etc/containers/registries.d/` for Sigstore signature lookup. Coordinated with the OCI-image signing flow per ACR-27..29.
8. **ACR-19** — `rpm -qf /etc/systemd/system/sideral-nix-install.service` returns exactly `sideral-services`. Every file shipped by sideral is owned by exactly one sub-package; no two sub-packages claim the same path.

**Test**: `rpm-ostree override remove sideral-shell-ux` on a deployed system → next reboot → `/etc/profile.d/sideral-hm-status.sh` is gone, rest of sideral still works.

---

### P2: Flatpak preinstall as own sub-package (preserved from `sideral-copr`)

**Story**: Flatpak auto-install machinery (the manifest + the systemd service that reads it + the enablement symlink) lives in its own sub-package. A user who wants their own flatpak set can `rpm-ostree override remove sideral-flatpaks` and ship their own — without losing the rest of sideral.

**Acceptance**:

1. **ACR-20** — `sideral-flatpaks` owns `/etc/flatpak-manifest`, `/etc/systemd/system/sideral-flatpak-install.service`, and the `multi-user.target.wants/sideral-flatpak-install.service` enablement symlink. All three coupled files live in one package — no cross-package dependency between manifest and reader.
2. **ACR-21** — `rpm-ostree override remove sideral-flatpaks` cleanly removes the curated flatpak set's auto-install path: next boot the service is absent and `/etc/flatpak-manifest` is gone. Flatpaks already installed at `/var/lib/flatpak` are NOT removed.
3. **ACR-22** — `sideral-base` declares `Requires: sideral-flatpaks`; a user wanting to opt out replaces base's dependency closure via `rpm-ostree override remove sideral-flatpaks` after install.
4. **ACR-23** — The current 7-ref manifest (GNOME quality-of-life apps; browser is the `helium-bin` RPM, not a flatpak) ships in this package; future additions/removals are made by editing `packages/sideral-flatpaks/src/etc/flatpak-manifest` and the next image build picks it up automatically.

**Test**: Fresh image with sideral-base installed → reboot → `flatpak list --app` shows 7 refs. `rpm-ostree override remove sideral-flatpaks` → next reboot → `/etc/flatpak-manifest` absent, but already-installed flatpaks remain.

---

### P2: Signed image rebase trust chain (preserved from `sideral-copr`)

**Story**: sideral OCI images are signed by our CI via cosign keyless OIDC, and `sideral-signing` configures the consumer side so `rpm-ostree rebase ostree-image-signed:registry:ghcr.io/athenabriana/sideral:latest` is the canonical install command — failing safely if the registry is tampered with.

**Acceptance**:

1. **ACR-27** — The image-build workflow (`.github/workflows/build.yml`) runs `cosign sign --yes ghcr.io/athenabriana/sideral@${{ steps.push.outputs.digest }}` after the registry push, using GitHub's OIDC identity token. Signature object is stored in the OCI registry alongside the image.
2. **ACR-28** — `sideral-signing` ships `/etc/containers/policy.json` with a `default: insecureAcceptAnything` baseline plus a `transports.docker."ghcr.io/athenabriana/sideral"` rule of type `sigstoreSigned` referencing the Fulcio root CA + workflow OIDC identity (`https://github.com/athenabriana/sideral/.github/workflows/build.yml@refs/heads/main`) + OIDC issuer (`https://token.actions.githubusercontent.com`). No static pub key — keyless verification only.
3. **ACR-29** *(Pending — README still documents `ostree-unverified-registry:` as of Phase R landing)* — On a fresh machine with sideral-signing installed, `rpm-ostree rebase ostree-image-signed:registry:ghcr.io/athenabriana/sideral:latest` succeeds. With `sideral-signing` removed (or the registry tampered with), the same command fails with a signature-mismatch error before any image content is applied. README documents the signed rebase URL and verification command (`cosign verify ghcr.io/athenabriana/sideral:latest --certificate-identity ... --certificate-oidc-issuer ...`).

**Test**: From clean silverblue-main:43 VM → install sideral-signing → `rpm-ostree rebase ostree-image-signed:registry:...` succeeds. Then on another VM, manually mangle a byte in the local image cache → rebase fails loudly. Documented commands in README work as written.

---

### P3: Self-contained sub-packages + drift detection (preserved from `sideral-copr`)

**Story**: Each `packages/<name>/` directory is genuinely self-contained — its `.spec` file plus its `src/` tree is everything the package needs to build. CI catches any drift between what `.spec` claims to ship and what `src/` actually contains.

**Acceptance**:

1. **ACR-35** — Every `packages/<name>/<name>.spec` uses `Source0: %{name}-%{version}.tar.gz` and the `%install` section unpacks the tarball into `%{buildroot}` preserving the absolute-path layout (`packages/<name>/src/etc/foo` → `/etc/foo` in the installed RPM). Already true for all 8 packages.
2. **ACR-36** — `scripts/build-rpms.sh` (per ACR-01) creates the binary RPM for each package by tarballing exactly `packages/<name>/src/` and invoking `rpmbuild -bb`. No per-package file lists in the script — each package's content is whatever's in its `src/` subtree.
3. **ACR-37** — `just build` runs the canonical inline-RPM Containerfile. No separate `build-local` overlay path — the rpmbuild step is small relative to a base-image pull / dnf transaction, and the granularity benefits (rpmdb tracking, `rpm-ostree override remove`) apply to local iteration too. The cp-overlay was a transitional artifact and is retired with this feature. Actual rpmbuild duration to be measured against a real reference build when CI lands one.
4. **ACR-38** *(Pending — no GHA job exists yet as of Phase R landing)* — Drift detection: CI job runs `rpm -ql sideral-<name>` for each sub-package on the built image and diffs the output against `find packages/<name>/src/ -type f` (with the `packages/<name>/src/` prefix stripped). Non-empty diff exits non-zero.

**Test**: Edit `packages/sideral-shell-ux/src/etc/profile.d/sideral-hm-status.sh`, run `just build` → script in image, owned by `sideral-shell-ux` per `rpm -qf` on the built image.

---

### P3: Operations & versioning

**Story**: The packaging mechanics are specified — not left as "figure it out at implementation time" — so every build is reproducible and every systemd unit we ship actually activates when its RPM is installed.

**Acceptance**:

1. **ACR-39** — Package version is `YYYYMMDD.<run_number>` where `YYYYMMDD` is the GHA run date (UTC) and `run_number` is `${{ github.run_number }}`. Local builds use `0.0.0.dev` as a sentinel. The version is stamped identically on every sub-package produced by the same build so they all `Requires:` each other by exact `=` match without drift.
2. **ACR-40** — Systemd unit enablement is handled by RPM `%files` listing the `multi-user.target.wants/` + `default.target.wants/` symlinks directly (not by `%post systemctl enable`). This makes `rpm-ostree override remove <pkg>` cleanly remove the symlinks along with the unit files. Exception: `sideral-dconf` uses `%post dconf update` because that isn't a file-ownership operation.

---

## Edge Cases

- **rpmbuild fails inside the Containerfile**: image build fails loudly at the build step. No regression vs. the current overlay (which never had a "validate the files are coherent" gate). The `bootc container lint` final step + drift-detection CI catch most issues before they ship.
- **Sub-package rename collision with Fedora-main package**: All `sideral-*` names are namespaced to prevent collision.
- **User modifies a file owned by `sideral-shell-ux`** (or any sub-package): `rpm-ostree upgrade` treats this as a conflict; `.rpmnew` file is created. Standard RPM behavior.
- **Sigstore is down during signed rebase**: `rpm-ostree rebase ostree-image-signed:...` fails because the policy.json check can't reach Rekor/Fulcio. User can fall back to `ostree-unverified-registry:` for a one-time emergency install (documented in README, but discouraged). Sigstore status: https://status.sigstore.dev.
- **OIDC identity changes** (e.g., we rename `build.yml` or move to a different branch): existing signatures fail verification on user machines. Mitigation: ship a transition release with the new identity in policy.json BEFORE pushing the next signed image.
- **External repo outage (docker-ce.repo)**: Image build fails on the affected dnf install step. Same failure mode as today; no regression. *(Pre-2026-05-01 also covered `ublue-os/packages` COPR for bazaar; that repo was retired with the Bazaar→GNOME-Software swap.)*

---

## Requirement Traceability

| Story | Requirement IDs | Count |
|---|---|---|
| P1: Inline RPM build inside the image | ACR-01 … ACR-05 | 5 |
| P1: Sub-divided by concern | ACR-12 … ACR-19 | 8 |
| P2: Flatpak preinstall sub-package | ACR-20 … ACR-23 | 4 |
| P2: Signed image rebase trust chain | ACR-27 … ACR-29 | 3 |
| P3: Self-contained sub-packages + drift | ACR-35 … ACR-38 | 4 |
| P3: Operations & versioning | ACR-39 … ACR-40 | 2 |

**Total**: 26 testable requirements. Status values: Pending → In Tasks → Implementing → Verified.

**ID gaps preserved on purpose**: ACR-06..11 (build.sh COPR install path), ACR-24..26 (cosign-signed published RPMs), ACR-30..34 (GHA → Copr automation), ACR-41 (GHA artifact retention) are gone — feature no longer publishes RPMs and no Copr workflow exists. Numbers retained as gaps so commit messages and code comments referencing the old IDs stay traceable to "this requirement was deleted in the rewrite, see sideral-rpms/spec.md."

---

## Supersedes

**From `sideral-copr` (this feature's previous form)**:

- **ACR-01..05** (Copr project + transitive resolution) — superseded entirely. No Copr.
- **ACR-06..09** (build.sh installs from Copr; `Containerfile.dev` for dev path) — superseded by ACR-02. Containerfile builds inline; there is no separate dev path. The cp-overlay was a transitional artifact and is retired.
- **ACR-24..26** (cosign-signed published RPMs) — RPMs no longer published, so signing them adds no trust boundary. Image-level signing (ACR-27..29) preserved.
- **ACR-30..34** (GHA → Copr automation) — `copr.yml` workflow deleted; `COPR_API_TOKEN` secret unused.
- **ACR-41** (versioned tarballs uploaded to GHA artifacts as cache fallback) — n/a; Copr unreachability is no longer a failure mode.

**From `.specs/features/sideral/`**: Same as `sideral-copr` (ATH-01/02 trust chain handover, ATH-09/10/13 flatpak install relocation). No change.

**From `.specs/features/nix-home/`**: Packaging-of-nix-home-artifacts handover unchanged.

**Project-level (`STATE.md`)**:

- *"Copr project activation pending"* — retire this entry. No Copr, no token, no workflow.
- *"Stay-unverified mode — Containerfile uses an overlay"* — fully retired. Inline RPM build replaces the overlay; there is no remaining cp-overlay path.

---

## Rollout Plan

Single phase. The current `packages/<name>/src/` layout is already correct (Phase A+B from the original `sideral-copr` plan landed 2026-04-25). What's left is swapping the Containerfile RUN block from cp-overlay to inline-rpmbuild, plus deleting the Copr workflow + token references.

### Phase R — Inline RPM swap (~3 h)

1. **Write `scripts/build-rpms.sh`** — for each `packages/<name>/`:
   - Determine version: env var `_SIDERAL_VERSION` or default `0.0.0.dev`
   - Tarball: `tar czf SOURCES/<name>-<version>.tar.gz -C packages/<name>/src --transform "s,^,<name>-<version>/," .`
   - Copy spec: `cp packages/<name>/<name>.spec SPECS/`
   - Build: `rpmbuild -bb --define "_topdir <topdir>" --define "_sideral_version <version>" SPECS/<name>.spec`
   - Output collected in `RPMS/noarch/`
2. **Edit `Containerfile`** — replace the cp-overlay RUN block with:
   ```dockerfile
   RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
       --mount=type=cache,dst=/var/cache \
       --mount=type=tmpfs,dst=/tmp \
       dnf5 install -y rpm-build rpmdevtools && \
       /ctx/scripts/build-rpms.sh /ctx/packages /tmp/rpmbuild "${SIDERAL_VERSION}" && \
       rpm -Uvh --replacefiles --replacepkgs /tmp/rpmbuild/RPMS/noarch/sideral-*.rpm && \
       rpm -e rpm-build rpmdevtools && \
       rm -rf /tmp/rpmbuild && \
       ostree container commit
   ```
   - `rpm -Uvh --replacefiles`: sideral-base ships `/etc/os-release` (conflicts with `fedora-release-common`), sideral-signing ships `/etc/containers/policy.json` (conflicts with `containers-common`), sideral-base ships `/etc/yum.repos.d/docker-ce.repo` (conflicts with `docker-ce`). dnf install rejects the transaction; rpm with `--replacefiles` transfers ownership cleanly.
   - `rpm -e` (not `dnf remove`): dnf auto-removes the ~73 transitively-pulled deps of rpm-build/rpmdevtools (cpio, diffutils, elfutils, file, …), most of which are part of the silverblue base and breaking to remove. rpm -e removes only the two packages we asked for.
   - `SIDERAL_VERSION` is a Containerfile `ARG` defaulting to `0.0.0.dev`; CI sets it via `--build-arg SIDERAL_VERSION=YYYYMMDD.<run>`.
3. **Fix `%changelog` date typos** — every `.spec` has `Wed Apr 23 2026` but Apr 23 2026 is a Thursday. rpmbuild emits warnings on bogus dates; replace with the correct day-of-week or move to a build-time-injected entry.
4. **Delete `.github/workflows/copr.yml`** — workflow no longer needed.
5. **Remove `COPR_API_TOKEN` from GitHub secrets** — no longer referenced. (Manual step; user does this in repo settings.)
6. **Update README** — drop any mention of "enable our Copr"; install command stays the same.
7. **Update STATE.md** — remove "Copr project activation pending" + "Signed-rebase flip" stays as a separate decision.
8. **Update `Justfile`** — `just build` runs the canonical inline-RPM Containerfile. No `build-local` recipe; the cp-overlay is gone.

**Exit criterion**: `just build` succeeds, `rpm -qa | grep sideral` shows 8 packages, `bootc container lint` passes, image size within +5 MB tolerance.

**Deferred follow-ups (not blocking Phase R close-out)**:

- ACR-29 README cutover from `ostree-unverified-registry:` → `ostree-image-signed:` (one paragraph in README + a line for `cosign verify`). Trivial; just hasn't landed.
- ACR-38 drift-detection CI job. Needs a small GHA workflow that runs `rpm -ql` against a built image artifact and diffs against `find packages/.../src`.
- Image-size and rpmbuild-duration measurements (ACR-05, ACR-37 timing claim) once CI produces a real reference build.

---

## Prerequisites

Validated during the inline-build trial (2026-04-29):

1. ✅ **`rpmbuild -bb` runs cleanly inside Fedora 43 with just `rpm-build` + `rpmdevtools`** — no dependency on `dnf builddep` for these specs (no `BuildRequires:` lines).
2. ✅ **`%setup -q` against `<name>-<version>.tar.gz` with dirname prefix unpacks correctly** — confirmed against `sideral-signing` end-to-end.
3. ✅ **`rpm -Uvh --replacefiles --replacepkgs /path/*.rpm` accepts local file paths and transfers ownership of conflicting files** — confirmed against `/etc/os-release` (vs `fedora-release-common`), `/etc/containers/policy.json` (vs `containers-common`), `/etc/yum.repos.d/docker-ce.repo` (vs `docker-ce`). `dnf5 install` rejects the same transaction with file-conflict errors, hence the drop to `rpm` directly.
4. ⚠ **`dnf5 remove rpm-build rpmdevtools` cascade-removes ~73 base packages** — including `cpio`, `diffutils`, `elfutils`, `file`, several of which are part of the silverblue base. **Mitigation**: use `rpm -e rpm-build rpmdevtools`, which removes only the two named packages and leaves the (now-orphaned) deps in place. Net image-size impact is near zero on silverblue-main where those deps were already present. This is the path baked into ACR-02.
5. ⏳ **Pending CI**: full inline rpmbuild + `rpm -Uvh` + `rpm -e` cycle running inside a single Containerfile RUN against `silverblue-main:43` with `bootc container lint` as the final layer. Locally validatable up to image-build syntax; full validation lands when GH Actions runs the next build.

---

## Success Criteria

CI run 25188178498 on commit `e06bc39` (2026-04-30, 6m24s end-to-end) verified the inline-build path against `silverblue-main:43`:

- [x] `just build` (CI equivalent: `buildah bud -f Containerfile`) produces an image that passes `bootc container lint`
- [x] All 8 sub-packages (`sideral-{base,dconf,flatpaks,selinux,services,shell-ux,signing,user}-0.0.0.dev-1.fc43.noarch.rpm`) build inline and install via `rpm -Uvh --replacefiles --replacepkgs`
- [x] Image was signed via cosign keyless (OIDC) and pushed to `ghcr.io/athenabriana/sideral:latest`, `:20260430`, `:sha-e06bc39`
- [x] No reference to `Copr`, `copr-cli`, or `COPR_API_TOKEN` remains in the repo
- [ ] `rpm -qf` on any shipped path returns exactly one `sideral-*` package *(verifiable on a rebased host; not part of CI gate)*
- [ ] Image size grows by ≤5 MB vs. the pre-swap overlay-only image *(measurement deferred — no reference build to compare against post-swap)*
- [ ] `rpm-ostree override remove sideral-shell-ux` cleanly removes `/etc/profile.d/sideral-hm-status.sh` *(verifiable on rebased host)*
- [ ] `rpm-ostree override remove sideral-flatpaks` cleanly removes the flatpak auto-install path *(verifiable on rebased host)*
- [ ] `cosign verify ghcr.io/athenabriana/sideral:latest` succeeds with cert-identity + OIDC-issuer flags *(deferred to ACR-29 README cutover)*
- [ ] `rpm-ostree rebase ostree-image-signed:registry:ghcr.io/athenabriana/sideral:latest` succeeds on a fresh machine with sideral-signing installed *(blocked on ACR-29; signed-rebase flip)*
- [ ] Drift-detection CI is green on every merge *(deferred to ACR-38)*
