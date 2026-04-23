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

## D-02 — External repo aggregated: docker-ce-stable (helium dropped)

**Choice**: Our Copr project lists exactly one external repo — `https://download.docker.com/linux/fedora/docker-ce.repo` (Docker Inc). Users enabling our Copr get transitive resolution of `docker-ce` + `containerd.io` without enabling any other repo themselves.

**Alternatives considered**:
- Also aggregate `imput/helium`. Rejected because helium was dropped entirely from the RPM layer (see addendum below). Browser ships via flatpak instead.
- Include `ublue-os/packages` as a second external repo. Rejected in favor of D-03 (fork bazaar into our own Copr).
- Aggregate none — let users enable each upstream repo separately. Rejected: loses the single-COPR-enablement goal and leaves `docker-ce.repo` as a loose file.

**Reasoning**: Docker Inc is closest to their source; we don't rebuild what they maintain. External-repo aggregation means one repo enablement from the user's perspective, with no ongoing packaging work on our side.

**Addendum (2026-04-23) — helium dropped, Zen Browser via flatpak**: The `imput/helium` COPR's `helium-bin` RPM hits a cpio `/opt/helium` unpack conflict on Silverblue's tmpfiles-managed `/opt` directory (CI evidence: run 24855724059). Rather than ship a workaround, we replaced helium with Zen Browser via `app.zen_browser.zen` flatpak — a privacy-focused Firefox fork, still the user's declared preference after a brief Chrome → Firefox iteration. Browser is no longer an RPM-layer concern; the `build_files/features/browser/` directory and the `imput/helium` line in `PERSISTENT_COPRS` were removed in the same change.

---

## D-03 — bazaar forked into packages/bazaar/ (we become its packager)

**Choice**: Fork `ublue-os/packages:staging/bazaar/bazaar.spec` into `packages/bazaar/bazaar.spec` in our repo. Our Copr builds it with the same upstream source (https://github.com/bazaar-org/bazaar). Name stays `bazaar` to preserve `dnf install bazaar` resolution for anyone porting from ublue-based images.

**Alternatives considered**:
- Leave bazaar as an external-repo dependency on `ublue-os/packages`. Rejected per user direction: "ublue packages should be cloned and 'rewritten' to our need".
- Rename the fork to `athens-bazaar` to signal our custom build. Rejected: breaks the `Name:` contract that users and scripts may depend on.

**Reasoning**: Gives us control over bazaar's release cadence and the ability to carry small patches without round-tripping through ublue. Cost: we now track kolunmi/bazaar-org release tags ourselves. Acceptable because bazaar is the only non-authored RPM we currently consume and its release cadence (~monthly) is manageable.

---

## D-04 — Hybrid migration: system_files/ stays as authoring source

**Choice**: `system_files/` and `home/` remain in the repo as the canonical source of each file. RPM spec files generate their staging tarballs from those directories via a build helper (`packages/build-srpm.sh`) rather than duplicating file contents into `packages/<name>/src/`. Local `just build-local` can still `COPY system_files /etc` for fast dev iteration; `just build-release` installs from the Copr.

**Alternatives considered**:
- Parallel sources of truth — `system_files/` for local dev, separate copies in `packages/<name>/src/` for RPM builds. Rejected: drift risk is high; edits land in one place and forget to update the other.
- Delete `system_files/`, RPM specs are the only source. Rejected: every local iteration requires a Copr rebuild (slow) or `rpmbuild -bb` loop (less familiar). Dev-loop friction too high.

**Reasoning**: One source of truth, one iteration speed. The SRPM build helper is ~30 lines of shell that tarballs the relevant subset of `system_files/` per sub-package. Added ACR-35 for drift detection in CI: verifies that what a sub-package ships matches what `system_files/` contains, so we can't accidentally lose a file in the transition.

---

## D-05 — Cosign keyless via GHA OIDC

**Choice**: Each RPM built by the `copr.yml` workflow is signed with `cosign sign-blob` using GitHub's OIDC identity token. `cosign.pub` is committed to the repo root, matches the key derived from OIDC, and is embedded in the image via `athens-os-base` for offline verification.

**Alternatives considered**:
- GPG key dedicated to the Copr. Rejected: extra key to manage + rotate, users would need to `rpm --import` separately. Cosign-keyless is stateless from our side.
- Unsigned RPMs. Rejected: sets a bad precedent even for personal use; cost of signing is low.

**Reasoning**: Matches how the image itself is signed (keyless via OIDC). No key material to rotate. Trust chain is verifiable via `cosign verify-blob --certificate-identity ...` against the workflow URL + OIDC issuer.

---

## D-06 — No rename of system_files/

**Choice**: Keep the directory name `system_files/` unchanged. Matches Bluefin / Bazzite / Aurora convention.

**Alternatives considered** (offered via AskUserQuestion):
- `os_files/` — parallels `build_files/`.
- `rootfs/` — OCI / atomic convention.
- `files/` — shortest.
- `athens/` — brand-labelled.

**Reasoning**: User's instinct to rename wavered once the RPM build mechanics were explained (the dir name has no functional effect on the RPM output). Keeping `system_files/` preserves symmetry with the ublue ecosystem — anyone reading Bluefin/Bazzite PRs for reference sees the same layout. Zero migration work.

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

**Choice**: Acceptance-criteria IDs are `ACR-NN` (Athens COPR). 35 requirements total in this spec (ACR-01 … ACR-35).

**Reasoning**: Distinct from `ATH-` (parent athens-os spec) and `NXH-` (nix-home sibling). Short enough to type in commit messages.

---

## D-12 — Feature lives at .specs/features/athens-copr/

**Choice**: Directory is `athens-copr` (no `-base` suffix, no `-rpm` suffix).

**Reasoning**: Concise. The feature is "our Copr project exists" — the base meta-package is one implementation detail inside it, not the feature itself.

---

## Open items (flag if they come up during design/implementation)

- **Copr external-repo configuration via `copr-cli`** — unverified whether external repos can be set via API, or if one-time web UI config is required. Design task: check Copr API docs and `copr-cli modify` for external-repo flags.
- **Spec file `Source0:` for packages that ship files from system_files/** — decide: tarball the relevant subtree (`system_files/etc/systemd/system/athens-*.service`) per-package, or tarball the whole `system_files/` per-package and `%install` selectively. Impact: SRPM size and drift detection.
- **`bazaar` `Version:` bump policy** — manual bump on each kolunmi/bazaar-org tag, or `%global_source_date_epoch` from git-describe? Defer until first bump is needed.
- **Image-build dependency on Copr availability** — if Copr is down at CI time, image build fails. Mitigation (deferred): cache the latest `athens-os-base.rpm` in the repo's GH Actions cache; fallback install from the cached RPM if Copr is unreachable.
