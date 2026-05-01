# sideral-rpms Context

Decisions locked during spec authoring. Each entry captures the choice, the alternatives considered, and the reasoning. Reference these by ID when questions arise during design or implementation.

This feature was renamed from `sideral-copr` on 2026-04-29 when the Copr-publishing path was dropped in favor of inline RPM build. Decisions below are preserved with their original D-NN IDs; entries that only made sense under the Copr publishing model are marked **SUPERSEDED** with a date and a pointer to the replacing decision.

---

## D-01 — Package granularity: sub-packages by concern

**Choice**: Eight sub-packages — `sideral-base` (meta), `sideral-services`, `sideral-flatpaks`, `sideral-dconf`, `sideral-selinux`, `sideral-shell-ux`, `sideral-user`, `sideral-signing`. Meta-package `Requires:` all sub-packages plus third-party deps.

**Alternatives considered**:
- One monolithic `sideral-base` package owning all files. Rejected: defeats the selective-removal goal.
- Two-tier split (`sideral-files` + `sideral-deps`). Rejected: loses the "remove by concern" granularity.

**Reasoning**: Mirrors Bluefin/Bazzite/Aurora's structure. Each spec stays small. `rpm-ostree override remove sideral-shell-ux` lets a user strip one concern without touching the rest. **Survives the Copr → inline-RPM switch unchanged** — sub-package boundaries are independent of how the RPMs reach the image.

---

## D-02 — Two external repos aggregated: ublue-os/packages + docker-ce-stable (SUPERSEDED 2026-04-29)

**Original choice**: Our Copr project lists exactly two external repos so a single `dnf5 copr enable` resolves bazaar + docker-ce + containerd.io transitively.

**Status**: Superseded by D-15. With no Copr project, "external repos aggregated by Copr" is moot. The two upstream repos (`ublue-os/packages` COPR + `docker-ce-stable`) are still consumed at build time — but they're enabled directly in `build.sh` (already the case today: `PERSISTENT_COPRS=(ublue-os/packages)` + `dnf5 config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo`). No change to the actual repo set; only the aggregation layer is removed.

**Historical context preserved**: The original deliberation about which third-party repos to consume vs. fork (helium dropped, bazaar not forked, docker-ce consumed upstream) is independent of Copr and still stands.

---

## D-03 — bazaar NOT forked: consume from ublue-os/packages directly

**Choice**: `sideral-base.spec` declares `Requires: bazaar` and dnf resolves it from the `ublue-os/packages` COPR enabled in `build.sh`. We don't host or maintain bazaar.

**Reasoning**: `ublue-os/packages` is the de-facto canonical bazaar packaging on Fedora — used by Bluefin, Bazzite, Aurora. Active F43 chroot, fresh builds, broad community trust. We have zero patches to carry. Forking would be load-bearing maintenance for the same RPM ublue ships.

**Trade accepted**: We ride ublue's release cadence. If bazaar lands a bad release upstream, we wait or pin. Acceptable for a personal image.

**Why this survives the Copr → inline-RPM switch unchanged**: The decision is "consume bazaar from upstream rather than fork it" — independent of whether we publish our own RPMs through Copr or build them inline. `sideral-base.spec` still declares `Requires: bazaar`; the inline-build path's `dnf5 install /tmp/rpmbuild/RPMS/noarch/sideral-*.rpm` still resolves that requirement against the build-time-enabled upstream COPR exactly the same way the published-Copr path would have.

---

## D-04 — Per-package src/ as authoring source (system_files/ + home/ retire)

**Choice**: Each sideral file lives at `packages/<owner-package>/src/<absolute-image-path>`. `system_files/` and `home/` retired entirely (cleanup landed 2026-04-25). RPM spec files use `Source0` tarballs of their own `src/` subtree.

**Reasoning**: Per-package `src/` makes each `packages/<name>/` genuinely self-contained. Drift detection becomes trivial: `rpm -ql sideral-<name>` should equal `find packages/<name>/src/ -type f` with the prefix stripped. **Survives Copr → inline-RPM switch unchanged** — the authoring layout is what feeds the tarball generation, regardless of where rpmbuild runs.

---

## D-05 — Cosign keyless via GHA OIDC for individual RPMs (SUPERSEDED 2026-04-29)

**Original choice**: Each RPM built by `copr.yml` was signed via `cosign sign-blob` using GitHub OIDC.

**Status**: Superseded by D-15. RPMs are no longer published anywhere — they exist only inside the OCI image. Signing them adds no trust boundary (the image itself is the unit being distributed and signed). Image-level cosign signing (D-14, ACR-27..29) is preserved and remains the meaningful trust boundary.

**Historical context**: The original deliberation about GPG-key vs. cosign-keyless was sound for the published-RPM model. With the model retired, the deliberation becomes moot.

---

## D-06 — No rename of system_files/ (RETIRED 2026-04-23 with D-04 revision)

Already retired in the sideral-copr era. No change.

---

## D-07 — Package-level subdir name: src/

**Choice**: Each package's staging files live under `packages/<name>/src/`, matching ublue-os/packages' literal convention. **Survives Copr → inline-RPM switch unchanged**.

---

## D-08 — Copr project visibility: public (SUPERSEDED 2026-04-29)

**Original choice**: `athenabriana/sideral` Copr project public so `rpm-ostree` could pull without auth.

**Status**: Superseded by D-15. No Copr project exists. RPMs aren't published. Visibility is moot.

---

## D-09 — Single-arch: x86_64 only

**Choice**: Build x86_64 only; matches the image. **Survives unchanged** — inline rpmbuild only runs against the build host's architecture, which is x86_64.

---

## D-10 — Fedora chroot: fedora-43 only initially

**Choice**: Only F43; F44 added when image base rebases. **Survives unchanged** — inline rpmbuild runs inside the silverblue-main:43 base image, so "chroot" is now "the live build container", which by definition matches the image's Fedora version.

---

## D-11 — Requirement ID prefix: ACR-

**Choice**: ACR-NN (originally "Sideral COPR"; now "Sideral RPMs" — same letters, different last word). **26 surviving requirements** post-rewrite (was 41 in sideral-copr). Deleted ID ranges (ACR-06..11, ACR-24..26, ACR-30..34, ACR-41) are kept as gaps so prior commits and code comments referencing them stay traceable to "this requirement was deleted in the rewrite, see sideral-rpms/spec.md."

**Reasoning**: Distinct from `ATH-` (parent sideral spec) and `NXH-` (nix-home sibling). Renaming the prefix would force a churn pass across STATE.md, code comments in `.spec` files, and any landed commits — for zero new clarity since "ACR" already stood for "sideral C/R packaging" in author intent.

---

## D-12 — Feature lives at .specs/features/sideral-rpms/ (renamed 2026-04-29)

**Choice**: Directory is `sideral-rpms/`. Renamed from `sideral-copr/` via `git mv` on 2026-04-29 when the Copr publishing model was dropped.

**Reasoning**: The old name described the publishing transport (Copr). The feature is now "we package what we author into RPMs" — `sideral-rpms` describes the actual output without committing to a transport.

---

## D-13 — `sideral-flatpaks` as own sub-package

**Choice**: Flatpak preinstall machinery (manifest + service + enablement symlink) lives in `sideral-flatpaks`. Total sub-packages: 8.

**Reasoning**: The flatpak triplet is tightly coupled — one reads the others, all three must travel together for clean removal. Putting them in their own sub-package gives users a clean opt-out: `rpm-ostree override remove sideral-flatpaks`. **Survives Copr → inline-RPM switch unchanged** — sub-package boundaries are independent of the build path.

---

## D-14 — `sideral-signing` sub-package + image trust chain

**Choice**: Ship our own `sideral-signing` sub-package (8th in the count) instead of pulling `ublue-os-signing` from upstream. Combined with cosign keyless signing of our OCI image in CI, this establishes an end-to-end trust chain: `rpm-ostree rebase ostree-image-signed:registry:ghcr.io/athenabriana/sideral:latest` and a tampered registry breaks the rebase.

**What `sideral-signing` ships**:
- `/etc/containers/policy.json` (overwrites the base image's lenient default), with:
  - `default: insecureAcceptAnything` — preserves the user's existing podman/skopeo workflow for arbitrary images
  - A `transports.docker."ghcr.io/athenabriana/sideral"` rule of type `sigstoreSigned` referencing the Fulcio root CA + the workflow OIDC identity (`https://github.com/athenabriana/sideral/.github/workflows/build.yml@refs/heads/main`) + the OIDC issuer (`https://token.actions.githubusercontent.com`)
- Optionally: `/etc/containers/registries.d/ghcr.io.yaml` if the default registries.d entry doesn't already point Sigstore lookups at ghcr.io (TBD during implementation)

**No static pub key shipped** — cosign keyless OIDC verifies against Sigstore's transparency log (Rekor) + Fulcio CA + a workflow identity match.

**Why this survives the Copr → inline-RPM switch unchanged**: Image signing was always independent of RPM signing. The OCI image is the unit users `rpm-ostree rebase` to; signing it is the meaningful trust boundary. RPM signing only protected the RPMs in transit between Copr and the image build — and once we stopped publishing RPMs, that whole transit step disappeared. ACR-27..29 stay as written.

**Trade accepted**:
- We can't trivially adopt ublue's signing for our base image at the same time. Verifying silverblue-main is a build-time concern (CI workflow can `cosign verify` the base image before using it), not a user-machine concern.
- If the GHA workflow file path or branch ever changes, existing user installs need a transition release: ship a new `sideral-signing` with both old + new identities for a release cycle, then drop the old.

---

## D-15 — Inline RPM build instead of Copr publishing (NEW 2026-04-29)

**Choice**: Build all 8 sideral RPMs inline during the OCI image build. The Containerfile RUN block installs `rpm-build` + `rpmdevtools`, runs `scripts/build-rpms.sh` against the bind-mounted `packages/`, installs the produced `.rpm` files via `dnf5 install`, then removes the build toolchain — all in one RUN layer so the final image carries no rpmbuild scratch state. RPMs exist only inside the image; the rebuild **is** the upgrade mechanism.

**Alternatives considered**:
- **Original choice (rejected 2026-04-29)**: Publish RPMs through `athenabriana/sideral` Copr project, sign each via cosign keyless OIDC, install in `build.sh` via `dnf5 install sideral-base`. Rejected because it requires a Copr account, a `COPR_API_TOKEN` GitHub secret, and a separate `copr.yml` workflow that has to stay green — friction the user explicitly does not want to take on ("im lazy"). The user-facing benefit ("download our RPMs separately") doesn't apply because nobody outside this user actually consumes them: sideral is a personal rebase-only image.
- **Pre-build RPMs in CI, copy `.rpm` files into the image as build context**: Rejected. Same total cost as inline build (rpmbuild has to run somewhere), more moving parts (a separate workflow step + artifact upload + bind-mount), no upside. Inline keeps the RPM lifecycle in one place.
- **Self-host a dnf repo on GitHub Pages**: Rejected. Would re-introduce the publishing infrastructure we're trying to delete; needs `createrepo_c` + a Pages workflow + repo metadata signing. All the cost of Copr, none of the community trust.
- **Drop RPMs entirely, keep the cp-overlay**: Rejected. Loses the actual benefits we want (rpmdb tracking, conflict detection, granular `rpm-ostree override remove`, drift detection that compares `rpm -ql` to `find src/`). Inline-rpmbuild keeps every benefit at the cost of ~30–60 s of build time and zero new infrastructure.

**Reasoning**: For a personal rebase-only image, the entire value of a published RPM repo is "users between rebases can `rpm-ostree upgrade` to pull new RPM versions." But sideral has no users between rebases — every change ships through a new image. The image rebuild **is** the upgrade. Once that's the framing, publishing RPMs separately is theater: extra infrastructure, extra failure modes, extra secrets, for no functional gain.

**Trade accepted**:
- ~30–60 s added to image build time for `rpmbuild -bb` against 8 specs. Mitigated by the cache mount on `/var/cache` so dnf doesn't re-download `rpm-build` every layer.
- No "install sideral-base on a vanilla silverblue without rebasing" path. Acceptable: nobody was going to do that.
- File conflicts with base-image packages (`/etc/os-release` vs `fedora-release-common`, `/etc/containers/policy.json` vs `containers-common`, `/etc/yum.repos.d/docker-ce.repo` vs `docker-ce`) require `rpm -Uvh --replacefiles --replacepkgs` instead of `dnf5 install`. dnf rejects the transaction; rpm directly transfers file ownership. Standard derivative-distro pattern. Caught during the 2026-04-29 trial against fedora:43 and confirmed clean install of all 8 RPMs with ownership transfer verified via `rpm -qf`.
- No `just build-local` shortcut. The rpmbuild step adds ~30 s for all 8 packages, which is acceptable for the rare case of local iteration. Single canonical Containerfile is simpler than maintaining a dev variant + a release variant in lockstep.

**Implementation**: ACR-01 (build-rpms.sh), ACR-02 (Containerfile RUN), ACR-03 (rpmdb verification), ACR-04 (bootc lint), ACR-05 (size budget). Phase R rollout in spec.md.

---

## Open items (flag if they come up during implementation)

- **`%changelog` date typos**: every `.spec` has `Wed Apr 23 2026` but Apr 23 2026 is a Thursday. rpmbuild emits warnings; replace with the correct day-of-week or move to a build-time-injected entry. Caught during the 2026-04-29 inline-build trial.
- **Build-time RAM for rpmbuild**: 8 specs × small tarballs is trivial. No expected concern; flag if image build OOMs.
- **`dnf5 remove rpm-build` cascade removal**: RESOLVED 2026-04-29 trial. dnf5 auto-removes ~73 transitively-pulled deps (cpio, diffutils, elfutils, file, jansson, dwz, libpkgconf, fakeroot-libs, add-determinism, …). On fedora:43 (where they were only pulled in by rpm-build), this removes them entirely; on silverblue-main:43 (where they're part of the base) the impact would be bigger because dnf would still try to remove the dep-tree leaves. Switched to `rpm -e rpm-build rpmdevtools` which removes ONLY the two named packages; orphaned deps stay put. ~5 MB residual that overlaps almost entirely with the silverblue base = near-zero net image growth.
- **rpm-ostree rebase against signed image**: still unverified end-to-end. Phase R doesn't change this — same as sideral-copr's open item — needs a real signed image + a fresh VM to validate ACR-29.
