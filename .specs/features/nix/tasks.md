# Nix + nh — Tasks

**Auto-sizing check:** Medium scope (4 clear tasks, well-defined patterns). Tasks broken down explicitly.

---

## Task 1 — System-level nix module (`os/modules/nix/`)

**What:** Create the `os/modules/nix/` module with nix-installer pre-download, first-boot oneshot, sudoers snippet, and nixbld user creation.

**Where:**
- `os/modules/nix/nix-installer-download.sh` — downloads `nix-installer` binary at build time, stages at `src/usr/libexec/nix-installer`
- `os/modules/nix/src/usr/lib/systemd/system/silverfox-nix-bootstrap.service` — systemd oneshot unit
- `os/modules/nix/src/etc/sudoers.d/nix-sudo-env` — adds nix profile bin to secure_path
- `os/modules/nix/nixbld-users.sh` — creates nixbld users 30000-30031 at build time
- `os/modules/nix/rpm/silverfox-nix.spec` — packages the systemd unit + sudoers snippet

**Depends on:** nothing
**Reuses:** Pattern from `os/modules/flatpaks/` (systemd unit + src tree + RPM spec)

**Done when:**
- `os/lib/build.sh` runs `nix-installer-download.sh` → `/usr/libexec/nix-installer` exists in the build
- `nixbld-users.sh` creates users 30000-30031 (verified with `getent passwd {30000..30031}`)
- RPM spec packages the service file + sudoers snippet
- `rpm -qp --requires silverfox-nix` shows no unexpected deps

**Tests:** RPM builds in `just build`; `rpm -qpl` shows expected files.
**Gate:** `just lint` passes.

---

## Task 2 — Starter nix flake + NH_FLAKE (in home module stow tree)

**What:** Add a `nix` stow package to the existing `os/modules/home/` module with a starter `flake.nix`, `flake.lock`. Also add `export NH_FLAKE="$HOME/.config/nix"` to the bash/zsh stow packages.

**Where:**
- `os/modules/home/src/etc/skel/.config/silverfox/stow/nix/.config/nix/flake.nix` — starter flake with homeConfigurations, commented packages/mise/flatpak sections, and nh in home.packages
- `os/modules/home/src/etc/skel/.config/silverfox/stow/nix/.config/nix/flake.lock` — pre-generated lockfile
- `os/modules/home/src/etc/skel/.config/silverfox/stow/bash/.bashrc` — add `NH_FLAKE` export
- `os/modules/home/src/etc/skel/.config/silverfox/stow/zsh/.zshrc` — add `NH_FLAKE` export
- `os/modules/home/rpm/silverfox-home.spec` — add new stow package files to %files, update bash/zsh %files if changed (they shouldn't need changes since the files already exist)

Note: No pre-farmed symlink at `/etc/skel/.config/nix/flake.nix` — `stow -R nix` via `fox home init` creates the symlink on first run. This differs from bash/zsh/ghostty/zed which have skel-level symlinks for immediate usability after useradd.

**Depends on:** nothing (pure content, no build-time deps)
**Reuses:** Pattern from existing stow packages (bash/zsh/ghostty/zed) in the home module

**Done when:**
- `ls /etc/skel/.config/silverfox/stow/nix/.config/nix/flake.nix` exists in the image
- `ls /etc/skel/.config/silverfox/stow/nix/.config/nix/flake.lock` exists in the image
- `NH_FLAKE` export lines exist in bashrc and zshrc stow packages
- On a test VM: `fox home init` → `ls ~/.config/nix/flake.nix` shows stow-created symlink → `nh home switch -c $(whoami)` succeeds

**Tests:** `just build` succeeds; `rpm -qpl silverfox-home` shows new flake files.
**Gate:** `just lint` passes.

---

## Task 3 — Fox recipes for nix operations

**What:** Add `home-init`, `home-sync`, `home-diff`, `home-edit`, `nix-doctor` recipes to the fox justfile, and update `cleanup` to include `nh clean`.

**Where:**
- `os/modules/fox/src/recipes/silverfox.justfile` — add new recipes
- `os/modules/fox/src/recipes/home.just` — update home submodule
- `os/modules/fox/rpm/silverfox-fox.spec` — update %files if new libexec scripts are added

**Recipes:**
```
home-init:              # First-time setup: copy stow + install nh + apply flake
    #!/usr/bin/bash
    if ! command -v nix >/dev/null 2>&1; then
      echo "nix not ready. Wait for first-boot bootstrap or reboot."
      exit 1
    fi
    stow -R nix 2>/dev/null || true
    if ! command -v nh >/dev/null 2>&1; then
      echo "Installing nh..."
      nix profile install nixpkgs#nh
    fi
    # NH_FLAKE (set in bashrc/zshrc) points to ~/.config/nix
    nh home switch -c $(whoami)

home-sync:              # Re-apply the nix flake
    #!/usr/bin/bash
    stow -R nix 2>/dev/null || true
    nh home switch -c $(whoami)

home-diff:              # Show pending changes without activating
    #!/usr/bin/bash
    nh home switch -c $(whoami) -- --dry-run 2>/dev/null \
      || nh home switch -c $(whoami) --dry 2>/dev/null \
      || echo "Dry-run not available with this nh version. Run 'fox home sync' to apply."

home-edit:              # Open the flake.nix in $EDITOR
    exec $EDITOR ~/.config/nix/flake.nix

nix-doctor:             # Diagnose nix + nh health
    #!/usr/bin/bash
    echo "=== nix version ==="
    nix --version 2>&1 || echo "NOT FOUND"
    echo "=== nix-daemon ==="
    systemctl is-active nix-daemon 2>&1 || echo "NOT ACTIVE"
    echo "=== /nix mount ==="
    findmnt /nix 2>&1 || echo "NOT MOUNTED"
    echo "=== SElinux /nix/store ==="
    ls -Z /nix/store 2>&1 | head -1 || echo "NOT ACCESSIBLE"
    echo "=== nh version ==="
    nh --version 2>&1 || echo "NOT INSTALLED (run 'fox home init')"
    echo "=== NH_FLAKE ==="
    echo "${NH_FLAKE:-<unset>}"
    echo "=== flake symlink ==="
    if [ -L "$HOME/.config/nix/flake.nix" ]; then
      readlink -f "$HOME/.config/nix/flake.nix"
      nix flake check "$HOME/.config/nix" 2>&1 || echo "flake check FAILED"
    else
      echo "~/.config/nix/flake.nix not found or not a symlink. Run 'fox home init'."
    fi
```

**Update cleanup:**
```
cleanup *args:          # Clean podman, flatpak, ostree, nix store
    #!/usr/bin/bash
    if [ $# -eq 0 ]; then
      podman image prune -af
      flatpak uninstall --unused
      rpm-ostree cleanup -prm
      command -v nh >/dev/null 2>&1 && nh clean
    else
      rpm-ostree cleanup "$@"
    fi
```

**Depends on:** Task 1 (nix bootstrap) + Task 2 (starter flake)
**Reuses:** Existing fox recipe patterns, home.just submodule pattern

**Done when:**
- `fox home init` installs nh and applies starter flake
- `fox home sync` re-applies flake changes
- `fox home diff` shows pending changes
- `fox home edit` opens flake.nix
- `fox nix-doctor` prints all diagnostics
- `fox cleanup` runs `nh clean` when nh is available

**Tests:** `os/modules/fox/src/tests/fox.test.sh` updated with nix recipe tests (dry-run, no nix available, etc.)
**Gate:** `just fox-lint && just fox-test` passes.

---

## Task 4 — Build integration

**What:** Wire the nix module into the build orchestrator and update the Containerfile.

**Where:**
- `os/lib/build.sh` — add `nix` to the `MODULES` array
- `os/modules/nix/nix-installer-download.sh` — called by build.sh for the nix module
- `os/modules/nix/nixbld-users.sh` — called by build.sh for the nix module
- `os/modules/base/rpm/silverfox-base.spec` — add `Requires: silverfox-nix` (version-pinned)
- `Containerfile` — may need adjustments if the nix-installer download needs network or special handling

**Changes to `os/lib/build.sh`:**
```bash
MODULES=(cli-tools services kubernetes flatpaks nix)
BUILD=(fonts nvidia)
```
(nix added to MODULES array for script execution)

**Depends on:** Task 1 (module exists)
**Reuses:** Pattern from existing module registration in build.sh

**Done when:**
- `just build` includes nix module scripts
- `rpm -q silverfox-nix` succeeds
- `silverfox-base` correctly Requires `silverfox-nix`

**Tests:** `just build` succeeds with silverfox-nix in the RPM list.
**Gate:** `bootc container lint` passes on the built image.
