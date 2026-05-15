# fox-home — Declarative config via fox/config.toml

## Problem Statement

Silverfox has two user-level package systems outside of stow: flatpak (apps) and rpm-ostree (system packages). There is no single file that declares "which flatpaks and RPMs this user wants" — nor a way to apply or capture that state.

Mise is managed by stow (`~/.config/mise/config.toml`) and `mise install` itself — fox doesn't need to touch it.

This spec unifies flatpak + rpm in `~/.config/fox/config.toml`. `fox home apply` reads the config and applies it. `fox home capture` reads the reality and rewrites the config. One file, two backends, two commands.

## Goals

- [ ] `~/.config/fox/config.toml` declara `[flatpaks]` e `[rpm]`
- [ ] `fox home apply` reads the config and reconciles flatpak + rpm (installs missing, removes extras)
- [ ] `fox home capture` reads the current state and rewrites the config
- [ ] `fox home diff` shows drift between config and reality
- [ ] Starter `fox/config.toml` no stow package `home/` em `/etc/skel`

## Out of Scope

| Feature | Reason |
|---|---|
| Mise | Managed by stow + `mise install`. Fox doesn't need to. |
| nix / home-manager | Spec archived |
| Auto-apply/capture via hook | Manual: you decide direction and run |
| `silverfox-cli-tools` RPM | Unchanged — base tools remain in the image |
| `silverfox-flatpaks` service | Unchanged — coexists, but apply may remove defaults if not in config |

---

## Stow tree

```
~/.config/silverfox/stow/
  ├── bash/
  ├── zsh/
  ├── ghostty/
  ├── zed/
  ├── mise/                          ← own package (unchanged)
  │   └── .config/mise/config.toml
  └── home/                          ← NEW
      └── .config/fox/config.toml
```

Symlinks:
- `~/.config/mise/config.toml` → `stow/mise/.config/mise/config.toml` (unchanged)
- `~/.config/fox/config.toml` → `stow/home/.config/fox/config.toml` (new)

---

## fox/config.toml Format

```toml
# ~/.config/fox/config.toml — flatpaks + RPMs.
# fox home apply  → reality   (installs/removes to match)
# fox home capture → config   (rewrites the config)
# fox home diff   <> reality  (shows drift)

[flatpaks]

[flatpaks.remotes]
flathub = true

[flatpaks.packages]
default = [
    "app.zen_browser.zen",
    "org.gnome.Extensions",
]

[rpm]
packages = [
    "helix",
    "fish",
]
```

---

## User Stories

### P1: fox home apply ⭐ MVP

1. **TOM-01** — Starter `fox/config.toml` in `/etc/skel/.config/silverfox/stow/home/.config/fox/config.toml`.
2. **TOM-02** — `~/.config/fox/config.toml` is a symlink to `stow/home/.config/fox/config.toml`.
3. **TOM-03** — `fox home apply` reconciles `[flatpaks.remotes]` (adds missing, removes extras).
4. **TOM-04** — `fox home apply` reconciles `[flatpaks.packages]` (installs missing, removes extras).
5. **TOM-05** — `fox home apply` reads `[rpm.packages]`, runs `rpm-ostree install --allow-inactive` for each RPM not installed, `rpm-ostree override remove` for each RPM installed not in the list. If RPM changed, prints "Reboot needed to apply RPM changes."
6. **TOM-06** — Error in flatpak does not block rpm and vice versa.
7. **TOM-07** — Idempotent: second run is no-op.

### P1: fox home capture ⭐ MVP

8. **TOM-08** — `fox home capture` reads `flatpak list --app` + `flatpak remote-list` and writes `[flatpaks]` to config.
9. **TOM-09** — `fox home capture` reads `rpm-ostree status` (layered packages) and writes `[rpm.packages]` to config.
10. **TOM-10** — `fox home capture` preserves comments in existing config (replaces only sections, not the whole file). If not possible, warns.

### P1: fox home init ⭐ MVP

11. **TOM-11** — `fox home init` copies stow tree from skel, `stow -R home`, `fox home apply`.
12. **TOM-12** — Idempotent: if `~/.config/fox/config.toml` exists, exit 0.

### P2: fox home diff / edit / status

13. **TOM-13** — `fox home diff` compares config vs reality in both backends. Exit 0 if clean, 1 if drift.
14. **TOM-14** — `fox home edit` opens `~/.config/fox/config.toml` in `$EDITOR`.
15. **TOM-15** — `fox home status` shows N flatpaks declared vs installed, N RPMs declared vs layered.

### P3: fox home apply --check / factory-reset

16. **TOM-16** — `fox home apply --check` prints what each backend would do without executing.
17. **TOM-17** — `fox home factory-reset` preserves `~/.config/fox/config.toml`.

---

## Backend details

| Backend | Apply (config → reality) | Capture (reality → config) |
|---|---|---|
| **Flatpak** | `flatpak remote-add` / `remote-delete` for remotes; `flatpak install` / `uninstall` for packages | `flatpak list --app` + `flatpak remote-list` → writes `[flatpaks]` |
| **RPM** | `rpm-ostree install <pkg>` for missing; `rpm-ostree override remove <pkg>` for extras. Warns reboot if changed. | `rpm-ostree status` (layered) → writes `[rpm.packages]` |

---

## Modules

### `os/modules/home/` — stow packages and RPM spec
- **Add**: stow package `home/` with `.config/fox/config.toml`
- **Keep**: `mise/` (unchanged), `bash/`, `zsh/`, `ghostty/`, `zed/`
- **RPM spec `silverfox-home.spec`**: add entries for `home/`

### `os/modules/fox/` — justfile recipes
- **Add**: `home init`, `home apply`, `home capture`, `home diff`, `home edit`, `home status`
- `home apply`: reconciles flatpak + RPM

---

## Requirement Traceability

| ID | Story | Phase | Status |
|---|---|---|---|
| TOM-01 | Starter fox/config.toml in skel | Spec | Pending |
| TOM-02 | Configs are stow symlinks | Spec | Pending |
| TOM-03 | apply reconciles flatpak remotes | Spec | Pending |
| TOM-04 | apply reconciles flatpak packages | Spec | Pending |
| TOM-05 | apply reconciles RPMs + reboot warning | Spec | Pending |
| TOM-06 | apply: error does not block backends | Spec | Pending |
| TOM-07 | apply idempotent | Spec | Pending |
| TOM-08 | capture: flatpaks from flatpak list | Spec | Pending |
| TOM-09 | capture: RPMs from rpm-ostree status | Spec | Pending |
| TOM-10 | capture preserves comments | Spec | Pending |
| TOM-11 | fox home init | Spec | Pending |
| TOM-12 | init idempotente | Spec | Pending |
| TOM-13 | fox home diff (2 backends) | Spec | Pending |
| TOM-14 | fox home edit | Spec | Pending |
| TOM-15 | fox home status | Spec | Pending |
| TOM-16 | apply --check dry-run | Spec | Pending |
| TOM-17 | factory-reset preserva config | Spec | Pending |

**Total:** 17 requirements.

---

## Success Criteria

- [ ] `fox home init` → stow tree copied → `fox home apply` → flatpaks installed, RPMs layered
- [ ] `~/.config/fox/config.toml` and `~/.config/mise/config.toml` are symlinks (package `home/`)
- [ ] Add flatpak to config → `fox home apply` → installed; remove → uninstalled
- [ ] Add RPM to config → `fox home apply` → `rpm-ostree install` → "Reboot needed"
- [ ] `flatpak install gimp` + `fox home capture` → gimp in config
- [ ] `fox home diff` shows drift in both backends, clean after apply
- [ ] `fox home apply --check` shows what would change without executing
- [ ] `fox home factory-reset` does not delete `fox/config.toml`
- [ ] `fox home apply` twice → identical, no errors
