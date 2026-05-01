# sideral — Project State

Persistent memory: decisions, blockers, lessons, todos, deferred ideas.

## Current feature
- None. `sideral-rpms` Phase R landed and CI is green (run 25188178498, sha `e06bc39`, 6m24s end-to-end). All 8 sub-packages build inline, install cleanly, and the image was signed + pushed to `ghcr.io/athenabriana/sideral:latest`. Two deferred ACRs remain (29: README signed-rebase cutover, 38: drift-detection CI job) — both documented in `.specs/features/sideral-rpms/spec.md` Rollout § "Deferred follow-ups" and intentionally non-blocking.

## Past feature (verified)
- `sideral-rpms` — 26 requirements, inline RPM build inside the Containerfile (rpmbuild + `rpm -Uvh --replacefiles` + `rpm -e` toolchain teardown in one RUN layer). Renamed from `sideral-copr` 2026-04-29 when the Copr publishing path was dropped (D-15). See `.specs/features/sideral-rpms/spec.md`. Signing requirements (ACR-27..29) still parked until user flips to signed-rebase; see `packages/sideral-signing/UPGRADE.md`.

## Past feature (verified-pending-VM)
- `nix-home` — migrates user-level config to nix + home-manager, collapses `/etc/skel` to a single `home.nix`, moves mise from RPM to nix. 40 requirements across 7 user stories. See `.specs/features/nix-home/spec.md`.

## Roadmap
- See `.specs/project/ROADMAP.md` for queued (`image-ops`) and backlog (`gnome-extras`, `ublue-adopt`, `nix-extras-v2`, hardware, security) features. `image-ops` entry criterion (`nix-home` Verified AND `sideral-rpms` Phase R landed) is half-met — only `nix-home` VM verification remains.

## Previous feature
- `sideral` — fork from `fedora-sideral`/Hyprland lineage into GNOME + tiling-shell on `silverblue-main:43`. 27 requirements across 5 user stories. See `.specs/features/sideral/spec.md`.
  - Superseded by `nix-home`: ATH-17, ATH-23, ATH-24, ATH-26 (mise + VS Code extensions moved into home.nix; first-login services collapsed to one).
  - Superseded by 2026-04-23 cleanup: ATH-12 (helium → Zen flatpak), ATH-14, ATH-15, ATH-18 (VS Code RPM removed), ATH-13 count (7 → 8 flatpaks).
  - Still valid: ATH-01..11, ATH-16, ATH-19..22, ATH-25, ATH-27 (image build, GNOME session, flatpak first-boot mechanics, dotfile workflow, mise lazy-install behavior).

## Pending decisions
- **Signed-rebase flip** — currently `ostree-unverified-registry:` is canonical. To flip: replace `packages/sideral-signing/src/etc/containers/policy.json` with the strict `sigstoreSigned` schema (template in `packages/sideral-signing/UPGRADE.md`), update README's install command. Keyless OIDC signing of the OCI image already runs in `build.yml`. (This is the same work as ACR-29.)

## Locked decisions
See `.specs/features/sideral/context.md` (9 decisions, some now superseded), `.specs/features/nix-home/context.md` (15 decisions), and `.specs/features/sideral-rpms/context.md` (15 decisions, 4 superseded by D-15 inline-rpm). Highlights:
- Desktop: GNOME + tiling-shell, Hyprland dropped entirely.
- Browser: Zen Browser via flatpak (`app.zen_browser.zen`). helium-bin dropped 2026-04-23 due to imput/helium COPR's `/opt/helium` unpack conflict with Silverblue's tmpfiles-managed `/opt`; supersedes earlier "helium via COPR" decision.
- Editor: `vscode` via `programs.vscode` in home.nix (with `ms-vscode-remote.remote-ssh` + `remote-containers`); supersedes ATH-14, ATH-15, ATH-17 (VS Code RPM + sideral-vscode-setup.service removed; vscode.repo file deleted).
- Container: `docker-ce` + `containerd.io` from docker-ce-stable repo.
- **User layer:** nix + home-manager is the sole source of user-level config. `/etc/skel` reduced to one file: `~/.config/home-manager/home.nix`.
- **Nix:** upstream CppNix via `NixOS/experimental-nix-installer`, baked binary at `/usr/libexec/nix-installer`, first-boot `ostree` planner, `/nix` bind-mounted from `/var/lib/nix`, `restorecon` post-install, default NixOS behavior (flakes off, channels).
- **home-manager:** channels-based (release-24.11), bootstrapped on first login via user systemd unit, starter `home.nix` declares bash/starship/git/atuin + `pkgs.mise` + inlined mise config.
- **2026-04-23 cleanup — RPM layer narrowed to system-integration only.** Single sweep removed every plain CLI from the RPM layer; everything user-facing now lives in nix or flatpak. Specifically:
  - **Removed RPMs** (now via home.nix): `gh`, `starship`, `gcc`, `make`, `cmake`, `git-lfs`, `git-subtree`, `git-credential-libsecret`, `code` (VS Code).
  - **Removed RPMs** (no replacement, niche/unused): `nix-software-center` (snowfallorg fetch), `android-tools` (use `nix shell` ad-hoc), kernel-debug stack `bcc`/`bpftop`/`bpftrace`/`sysprof`/`trace-cmd`/`tiptop`/`nicstat`/`iotop`/`udica` (bluefin-dx parity that the personal workload never needed).
  - **Removed RPM** (replaced by flatpak): `helium-bin` (tmpfiles `/opt` conflict on Silverblue, see Browser entry above) → Zen Browser via flatpak.
  - **Removed feature dirs**: `build_files/features/devtools/` and `build_files/features/browser/` deleted entirely. Remaining RPM features: gnome, container, fonts, gnome-extensions only.
  - **home.nix integration**: `programs.vscode` (with `ms-vscode-remote.remote-ssh` + `remote-containers`), `programs.git` (with `lfs.enable` + `credential.helper = "libsecret"`), `programs.gh`, `programs.starship`, `pkgs.gcc`/`gnumake`/`cmake` in `home.packages`.
  - **`/etc/distrobox/distrobox.conf`** added — auto-mounts `/nix`, `/var/lib/nix`, `/etc/nix` into every distrobox container; bashrc snippet sources nix-daemon profile so `nix`, `nix-shell`, `nix-build` work inside containers without per-container flags.
- **mise:** moved from RPM to nix (via `home.packages`); `mise.jdx.dev/rpm/` repo and `sideral-mise-install.service` removed. Config inlined into `home.nix` via `home.file.".config/mise/config.toml".text`.
- **Dropped from mise toolchain**: `direnv` (user declined), `act` (on-demand via `nix profile install`); `atuin` moved to `programs.atuin.enable`. mise toolchain now 12 tools (was 15).
- Shell: bash only; `~/.bashrc` is fully home-manager-generated (was hand-authored `/etc/skel/.bashrc`).
- Fonts: Source Serif 4 + Source Sans 3 built from Adobe GitHub at image time; cascadia-code, jetbrains-mono, adwaita, opendyslexic from Fedora.
- Flatpaks: **8 curated refs** via systemd oneshot on first boot — Zen Browser + Flatseal, Warehouse, Extension Manager, Podman Desktop, DistroShelf, Resources, Smile.
- No distrobox pre-bake (DistroShelf flatpak available on demand). `/nix` IS auto-mounted into every distrobox.
- **Host-first, distrobox-shared:** mise and nix run on the host; distrobox containers share the host's `/nix` store via the new auto-mount config.
- No brew (user declined; nix via `nix profile install` covers ad-hoc CLI tooling, mise covers language runtimes).

## Known blockers
None yet.

## nix-home implementation status (Apr 2026)
All 9 tasks implemented locally. Local gate limited to `bash -n` + INI parse + grep invariants
(shellcheck/podman/just not on this dev host). Full `just build` + `bootc container lint` runs in
CI. Runtime criteria (NXH-06/27/28) require VM rebase to verify.

**Spec deviation**: NXH-01 URL/asset text is stale. Upstream renamed
`experimental-nix-installer` → `nix-installer`; x86_64 asset is `nix-installer-x86_64-linux`
(dropped the `-unknown-linux-gnu` suffix). Using `2.34.5` pin. Spec intent (upstream CppNix via
installer's ostree planner, per D-01) unchanged. See `.specs/features/nix-home/tasks.md`
SPEC-DEV-01. Update spec.md NXH-01 text when promoting to Verified.

## Lessons
- **docker-ce repo is both shipped AND registered at build time.** Shipped file (`/etc/yum.repos.d/docker-ce.repo`) is for `rpm-ostree upgrade` to see. Inline `dnf5 config-manager addrepo --from-repofile=<URL>` in `build.sh` is for the build itself — the shipped copy isn't available during the RUN step because `COPY system_files/etc /etc` happens *after* `build.sh`.
- **`--allowerasing` is required** on the dnf5 install that adds `containerd.io`, because Fedora's `containerd` is already present in `silverblue-main:43` and dnf can't swap it without explicit permission.
- **GNOME-extension download at build time** needs the real `gnome-shell --version` of the running container — we call it inside the container (since silverblue-main ships gnome-shell), then query `extensions.gnome.org/extension-info/?uuid=<uuid>&shell_version=<N>`. `glib2-devel`/`jq`/`unzip` are installed and removed in the same script so they don't bloat the final layer.
- **`dconf update` must run after `COPY system_files/etc /etc`.** The Containerfile now has a second RUN step for that, followed by the final `ostree container commit`.
- **flatpak-install service is system-level, not user.** System-wide flatpaks live under `/var/lib/flatpak`, which is mutable on atomic. User-level would require a per-user unit, which we already use for `mise` and `vscode-setup`.
- **Persistent COPR pattern**: repos enabled during build.sh + kept enabled in the shipped image let `rpm-ostree upgrade` pull new releases without touching the image. Currently used for `ublue-os/packages` (bazaar). Same applies to docker-ce.repo (Docker Inc's official dnf repo, shipped as /etc/yum.repos.d/docker-ce.repo).
- **Dev host shell used here had no podman / just / shellcheck**, so the final gate was limited to `bash -n` on shell scripts, YAML parse, and INI parse on dconf files. The real `just build` gate runs in CI.
- **Phase R lessons (2026-04-30, run 25188178498)**:
  - **`/ctx` bind-mount layout is `/ctx/build_files/...`, not `/ctx/...`** — Containerfile does `COPY build_files /build_files` then mounts the carrier at `/ctx`, so features live at `/ctx/build_files/features`. A wrong `FEATURES_DIR=/ctx/features` made the per-feature install loop silently no-op (every `[ -f .../packages.txt ]` false, no error), and the failure surfaced two RUN layers later when `rpm -Uvh sideral-base` couldn't resolve `bazaar/docker-ce/containerd.io`. Lesson: when a downstream RPM Requires-check fails for packages you "know" are installed, suspect the upstream install loop ran zero iterations.
  - **RPM file-path Requires resolves through the rpmdb, not the filesystem.** `Requires: /usr/libexec/nix-installer` against a curl-staged binary (no owning package) can never satisfy. Use `ConditionPathExists=` in the systemd unit instead.
  - **`rpm -Uvh --replacefiles --replacepkgs` does not bypass package-level `Conflicts:`.** `--replacefiles` only handles file-ownership transfer. silverblue-main:43 ships `ublue-os-signing` and our `sideral-signing.spec` declares `Conflicts:` against it (intentionally — we target a different sigstore policy identity). Containerfile must `rpm -e --nodeps ublue-os-signing` *before* the install step. `--nodeps` is safe because nothing in the base image Requires it.
  - **`set -o pipefail` makes `var=$(... | grep ...)` a hidden landmine** when the grep can find nothing. The unauthenticated GitHub-API call in `features/fonts/post-install.sh` for adobe-fonts/source-sans hit a rate limit on the second back-to-back call, returned an error JSON without any `browser_download_url`, grep emitted nothing, and the whole image build aborted *before* reaching the script's own "Could not resolve URL" fallback. Pattern: capture the response into a variable first, then `grep ... || true`, then validate.

## Deferred
- Tailscale daemon + GNOME indicator.
- ISO / QCOW2 / bootc-image-builder outputs.
- Matrix builds (aarch64).
