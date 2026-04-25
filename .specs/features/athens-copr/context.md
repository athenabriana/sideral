# athens-copr Context

Decisions locked during spec authoring. Each entry captures the choice, the alternatives that were considered, and the reasoning. Reference these by ID when questions arise during design or implementation.

---

## D-01 — Package granularity: sub-packages by concern

**Choice**: Six sub-packages — `athens-os-base` (meta), `athens-os-services`, `athens-os-dconf`, `athens-os-selinux`, `athens-os-shell-ux`, `athens-os-skel`. Meta-package `Requires:` all sub-packages plus third-party deps.

**Alternatives considered**:
- One monolithic `athens-os-base` package owning all files. Rejected: defeats the selective-removal goal.
- Two-tier split (`athens-os-files` + `athens-os-deps`). Rejected: loses the "remove by concern" granularity that the sub-package approach provides.

**Reasoning**: Mirrors Bluefin/Bazzite/Aurora's structure. Each spec stays small. `rpm-ostree override remove athens-os-shell-ux` lets a user strip one concern without touching the rest.

---

## D-02 — Two external repos aggregated: ublue-os/packages + docker-ce-stable

**Choice**: Our Copr project lists exactly two external repos:
1. `https://copr.fedorainfracloud.org/coprs/ublue-os/packages/repo/fedora-43/ublue-os-packages-fedora-43.repo` — provides `bazaar` (current use) + `ublue-os-signing` (queued, security on rebase) + future ublue adoptions
2. `https://download.docker.com/linux/fedora/docker-ce.repo` — provides `docker-ce` + `containerd.io`

Users enabling our Copr get transitive resolution of all four without enabling any upstream repo themselves.

**Alternatives considered**:
- Also aggregate `imput/helium`. Rejected because helium was dropped entirely from the RPM layer (see addendum below). Browser ships via flatpak instead.
- Aggregate only `docker-ce-stable`, fork bazaar into our own Copr. Rejected (see D-03 reversal below) — fork was load-bearing maintenance for zero patches carried.
- Aggregate none — let users enable each upstream repo separately. Rejected: loses the single-COPR-enablement goal and leaves users with multiple repo files to manage.

**Reasoning**: Both Docker Inc and Universal Blue maintain their packages well, with active release cycles, F43 chroot support, and broad community use (Bluefin/Bazzite/Aurora all consume `ublue-os/packages`). External-repo aggregation means one repo enablement from the user's perspective, with no ongoing packaging work on our side. We pick up new versions automatically as upstream releases.

**Addendum (2026-04-23) — helium dropped, Zen Browser via flatpak**: The `imput/helium` COPR's `helium-bin` RPM hits a cpio `/opt/helium` unpack conflict on Silverblue's tmpfiles-managed `/opt` directory (CI evidence: run 24855724059). Rather than ship a workaround, we replaced helium with Zen Browser via `app.zen_browser.zen` flatpak — a privacy-focused Firefox fork, still the user's declared preference after a brief Chrome → Firefox iteration. Browser is no longer an RPM-layer concern; the `build_files/features/browser/` directory and the `imput/helium` line in `PERSISTENT_COPRS` were removed in the same change.

---

## D-03 — bazaar NOT forked: aggregate via external-repo (REVERSED 2026-04-23)

**Choice**: Use `ublue-os/packages` as a Copr external-repo (per D-02). Do **not** create `packages/bazaar/bazaar.spec`. `athens-os-base.spec` declares `Requires: bazaar` and dnf resolves it transitively from ublue's prebuilt RPM. We don't host or maintain bazaar.

**Alternatives considered**:
- **Original choice (rejected on review)**: Fork `ublue-os/packages:staging/bazaar/bazaar.spec` into `packages/bazaar/bazaar.spec`, build in our Copr, track upstream tags ourselves. Initial decision was driven by user direction *"ublue packages should be cloned and 'rewritten' to our need"*. Rejected on the second pass when we asked "what would we actually rewrite?" and the answer was nothing — we have zero patches to carry. Forking would be load-bearing maintenance (manual upstream tracking, weekly reminder workflow, version bumps) for the same RPM ublue ships.
- Rename to `athens-bazaar` to signal a custom build. Moot once we're not building it.

**Reasoning for reversal**: `ublue-os/packages` is the de-facto canonical bazaar packaging on Fedora — used by Bluefin, Bazzite, Aurora. Active F43 chroot, fresh builds, broad community trust. We have no patches, no opinion on release cadence, no reason to fork. Aggregating is strictly less work for the same outcome. If upstream ever regresses or removes bazaar (an Edge Case noted in spec), we'd fork that one spec then — as an emergency, not as the steady state.

**Trade accepted**: We ride ublue's release cadence by default. If bazaar lands a bad release at upstream, we wait or pin. Acceptable for a personal image.

**Implications for the spec** (applied 2026-04-23):
- "P2: bazaar forked" user story removed (was ACR-22..26)
- ACR-38 ("packages/bazaar/UPSTREAM.md tracker") removed
- D-02 expanded to add `ublue-os/packages` as the second external repo
- `athens-os-base.spec` Requires gains `ublue-os-signing` since it's in the same repo (free win — security on rebase)
- Total ACRs: 39 → 37 (removed 6, added 4 for new -flatpaks story per D-13)

---

## D-04 — Per-package src/ as authoring source (system_files/ + home/ retire)

**Choice (REVISED 2026-04-23)**: Each athens-os file lives at `packages/<owner-package>/src/<absolute-image-path>`. The `system_files/` and `home/` top-level directories retire entirely — every file there migrates to its owner package's `src/` tree during Phase B. RPM spec files use `Source0` tarballs of their own `src/` subtree.

Local `just build-local` overlays every `packages/*/src/` tree into the image at build time (`Containerfile.dev` runs `cp -a packages/*/src/. /`); `just build-release` runs the canonical `Containerfile` (installs from Copr).

**Original choice (rejected on review)**: `system_files/` + `home/` stay as canonical authoring source; specs generate `Source0` tarballs from subsets. Rejected because it directly contradicted D-07 (which named per-package `src/` as the staging convention) and forced a per-package file-list map in `build-srpm.sh` to know which files belonged to which package — a separate source of truth that drift detection had to keep in sync. Self-contained packages (Option B) eliminate that bookkeeping.

**Alternatives considered**:
- **Original choice (hybrid)**: kept files in `system_files/`. Rejected per discussion above.
- **Parallel sources of truth** — `system_files/` for local dev, separate copies in `packages/<name>/src/` for RPM builds. Rejected: drift risk is high; edits land in one place and forget to update the other.
- **Symlinked src/** — each `packages/<name>/src/` symlinked to `system_files/` subset. Rejected: symlinks-in-RPM-staging are an antipattern; build-srpm.sh would need to dereference them anyway.

**Reasoning**: Per-package `src/` makes each `packages/<name>/` genuinely self-contained — its `.spec` plus its `src/` tree is everything the package needs to build. Drift detection becomes trivial: `rpm -ql athens-os-<name>` should equal `find packages/<name>/src/ -type f` with the prefix stripped. One mental model: when adding a file to athens-os, you put it in the package that owns it — there's no separate "where does the actual content live" question.

**Trade accepted**: `git mv` operations during Phase B (~30 file moves total). One-time cost. After Phase B + C complete, the repo has a cleaner top-level layout (no `system_files/`, no `home/`).

---

## D-05 — Cosign keyless via GHA OIDC

**Choice**: Each RPM built by the `copr.yml` workflow is signed with `cosign sign-blob` using GitHub's OIDC identity token. `cosign.pub` is committed to the repo root, matches the key derived from OIDC, and is embedded in the image via `athens-os-base` for offline verification.

**Alternatives considered**:
- GPG key dedicated to the Copr. Rejected: extra key to manage + rotate, users would need to `rpm --import` separately. Cosign-keyless is stateless from our side.
- Unsigned RPMs. Rejected: sets a bad precedent even for personal use; cost of signing is low.

**Reasoning**: Matches how the image itself is signed (keyless via OIDC). No key material to rotate. Trust chain is verifiable via `cosign verify-blob --certificate-identity ...` against the workflow URL + OIDC issuer.

---

## D-06 — No rename of system_files/ (RETIRED 2026-04-23 with D-04 revision)

**Original choice**: Keep the directory name `system_files/` unchanged.

**Status**: Moot. Under D-04's revised choice (per-package `src/` as authoring source), `system_files/` doesn't exist after Phase C. The "should we rename it?" question doesn't apply when the directory itself goes away.

**Historical context preserved**: The original deliberation (rename to `os_files/`, `rootfs/`, `files/`, or `athens/`?) was about cosmetic symmetry with `build_files/` and the ublue ecosystem. The user's instinct to rename wavered once the RPM build mechanics were explained, and we kept it as-is. That choice is now superseded by the larger Option-B decision in D-04.

---

## D-07 — Package-level subdir name: src/

**Choice**: Each package's staging files live under `packages/<name>/src/`, matching the literal convention ublue-os/packages uses in their `packages/ublue-os-signing/src/…` and `packages/ublue-os-just/src/…` layouts.

**Alternatives considered**:
- `packages/<name>/files/` — more self-explanatory to newcomers.

**Reasoning**: User directed "name it src". Full alignment with ublue convention (both the top-level `packages/<name>/` layout AND the `src/` subdir name). Easier to port patterns from their spec files without translation.

---

## D-08 — Copr project visibility: public

**Choice**: `athenabriana/athens-os` is a public Copr project. The source GitHub repo stays private; only the built RPM artifacts are public.

**Reasoning**: `rpm-ostree` on client machines must be able to pull from the Copr without authentication. Copr does not support private projects with token-based access for rpm-ostree consumption. The public/private split of Copr-artifacts vs GitHub-source is normal.

---

## D-09 — Single-arch: x86_64 only

**Choice**: Copr chroot is `fedora-43-x86_64`; we do not build aarch64 or ppc64le.

**Reasoning**: Matches the image itself (personal use, x86_64 laptops/desktops only). Adding aarch64 doubles build time and storage for zero current benefit. Can be added later if Framework/Asahi becomes relevant.

---

## D-10 — Fedora chroot: fedora-43 only initially

**Choice**: Only `fedora-43-x86_64` chroot. Add `fedora-44` when F44 ships and silverblue-main:44 is our base.

**Reasoning**: We don't have a reason to keep F42 builds alive (silverblue-main:42 is EOL-soon). F43 is current; F44 will be added alongside an image rebase.

---

## D-11 — Requirement ID prefix: ACR-

**Choice**: Acceptance-criteria IDs are `ACR-NN` (Athens COPR). **41 requirements** total in this spec (ACR-01 … ACR-41) after the 2026-04-23 reversal of D-03 (bazaar story removed), addition of D-13 (-flatpaks story), and addition of D-14 (-signing story + image trust chain).

**Reasoning**: Distinct from `ATH-` (parent athens-os spec) and `NXH-` (nix-home sibling). Short enough to type in commit messages.

---

## D-12 — Feature lives at .specs/features/athens-copr/

**Choice**: Directory is `athens-copr` (no `-base` suffix, no `-rpm` suffix).

**Reasoning**: Concise. The feature is "our Copr project exists" — the base meta-package is one implementation detail inside it, not the feature itself.

---

## D-14 — `athens-os-signing` sub-package + image trust chain

**Choice**: Ship our own `athens-os-signing` sub-package (8th in the count) instead of pulling `ublue-os-signing` from upstream. Combined with cosign keyless signing of our OCI image in CI, this establishes an end-to-end trust chain: users can rebase via `ostree-image-signed:registry:ghcr.io/athenabriana/athens-os:latest` and a tampered registry breaks the rebase.

**What `athens-os-signing` ships**:
- `/etc/containers/policy.json` (overwrites the base image's lenient default), with:
  - `default: insecureAcceptAnything` — preserves the user's existing podman/skopeo workflow for arbitrary images
  - A `transports.docker."ghcr.io/athenabriana/athens-os"` rule of type `sigstoreSigned` referencing the Fulcio root CA (embedded in the policy file) + the workflow OIDC identity (`https://github.com/athenabriana/athens-os/.github/workflows/build.yml@refs/heads/main`) + the OIDC issuer (`https://token.actions.githubusercontent.com`)
- Optionally: `/etc/containers/registries.d/ghcr.io.yaml` if the default registries.d entry doesn't already point Sigstore lookups at ghcr.io (TBD during implementation)

**No static pub key shipped** — cosign keyless OIDC verifies against Sigstore's transparency log (Rekor) + Fulcio CA + a workflow identity match. Same verification path as our RPM signing (D-05).

**Alternatives considered**:
- **Pull `ublue-os-signing` directly**: Rejected. Their policy.json scopes `sigstoreSigned` to `ghcr.io/ublue-os/*` against ublue's signing keys; doesn't cover athenabriana/athens-os. Pulling it gives base-image verification but doesn't end-to-end secure our deployed image. Worse: it would conflict on file ownership of `/etc/containers/policy.json` if we tried to install both.
- **Patch ublue-os-signing's policy.json in `%post`** (`Requires: ublue-os-signing` + scriptlet to add our entry): Rejected. Fragile — every ublue-os-signing update would need to coordinate with our patcher. RPM `%post` modifications to packaged files are an antipattern.
- **Static-key cosign instead of keyless**: Rejected. We already use keyless OIDC for RPM signing (D-05); using a static key for image signing would mean managing key rotation manually. Keyless gives us "no key material to lose" by design.
- **Skip image signing entirely; only sign RPMs**: Rejected. Defeats the goal — `rpm-ostree rebase` on user machines pulls the OCI image, which without signing is vulnerable to a compromised registry. RPM signing only matters at install time inside the image; it doesn't protect the rebase path.

**Reasoning**: The whole point of athens-copr is to "package athens-os as real software with verifiable provenance." It would be inconsistent to lock down the RPM artifacts (D-05) while leaving the deployed image (the actual thing users install) unverified. Bluefin/Bazzite/Aurora all ship their own `<distro>-signing` packages for the same reason — packaging cleanliness AND end-to-end trust.

**Trade accepted**:
- We can't trivially adopt ublue's signing for our base image at the same time. Verifying silverblue-main is a build-time concern (CI workflow can `cosign verify` the base image before using it), not a user-machine concern.
- If the GHA workflow file path or branch ever changes (e.g., we rename `build.yml` or move to `next` branch), existing user installs need a transition release: ship a new `athens-os-signing` with both old + new identities for a release cycle, then drop the old.

**Implementation**:
- New ACRs ACR-18 (sub-package contents), ACR-27..29 (image-signing trust chain story)
- Phase A adds image signing to `build.yml`
- Phase B migrates `athens-os-signing` 4th in order (after the simplest single-file packages, before flatpaks/dconf/services) so the trust chain can be validated end-to-end on a real signed image before more files migrate
- Phase C cutover updates README to use `ostree-image-signed:` URL as the canonical install command

---

## D-13 — `athens-os-flatpaks` as own sub-package

**Choice**: The flatpak preinstall machinery (`/etc/flatpak-manifest`, `/etc/systemd/system/athens-flatpak-install.service`, and the `multi-user.target.wants/` enablement symlink) lives in its own sub-package `athens-os-flatpaks`. Total sub-packages: 7 (`-base`, `-services`, `-flatpaks`, `-dconf`, `-selinux`, `-shell-ux`, `-user`).

**Alternatives considered**:
- **Keep manifest in `-base`, service in `-services`** (original spec). Rejected: implicit cross-package coupling — the service in `-services` reads a config file owned by `-base`. Removing `-base` while keeping `-services` would orphan a running service.
- **Move both to `-services`** (group by mechanism). Rejected: `-services` becomes a grab bag of unrelated concerns (nix install + nix relabel + flatpak + home-manager-setup); poor concern boundary.
- **Move manifest to `-user`** (user-facing reasoning). Rejected: file lives in `/etc`, read by a system service running as root — putting it in a "user-scope" package is a packaging mismatch even if user-facing in spirit.

**Reasoning**: The flatpak triplet (manifest + service + symlink) is tightly coupled — one reads the others, all three must travel together for clean removal. Putting them in their own sub-package gives users a clean opt-out: `rpm-ostree override remove athens-os-flatpaks` skips the curated set entirely and lets them ship their own. This is the same reasoning that motivated the per-concern sub-package split in D-01; we just had it slightly wrong on the original divide.

**Implementation**:
- New ACRs ACR-19..ACR-22 cover the sub-package
- ACR-12 updated: `-base` no longer owns `/etc/flatpak-manifest`
- ACR-13 updated: `-services` no longer owns the flatpak service or its symlink
- Phase B migration order updated to include `-flatpaks` between `-user` and `-dconf`

---

## Open items (flag if they come up during design/implementation)

- **Copr external-repo configuration via `copr-cli`** — unverified whether external repos can be set via API, or if one-time web UI config is required. Design task: check Copr API docs and `copr-cli modify` for external-repo flags. ACR-02 depends on this working with TWO external repos (ublue-os/packages + docker-ce).
- **Spec file `Source0:` for packages that ship files from system_files/** — decide: tarball the relevant subtree (`system_files/etc/systemd/system/athens-*.service`) per-package, or tarball the whole `system_files/` per-package and `%install` selectively. Impact: SRPM size and drift detection.
- **Image-build dependency on Copr availability** — if Copr is down at CI time, image build fails. Mitigation (per ACR-37): cache the latest `athens-os-base.rpm` in the repo's GH Actions cache; fallback install from the cached RPM if Copr is unreachable.
- **`ublue-os-signing` interaction with rpm-ostree rebase** — adding this RPM ships `/etc/containers/policy.json`. Verify the rebase target URL flips from `ostree-unverified-registry:` to `ostree-image-signed:` cleanly without breaking existing user installs that haven't yet pulled this version.
