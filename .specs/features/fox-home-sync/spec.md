# fox-home — Config declarativa via fox/config.toml

## Problem Statement

Silverfox tem dois sistemas de user-level packages fora do stow: flatpak (apps) e rpm-ostree (system packages). Não há um arquivo único que declare "quais flatpaks e RPMs esse usuário quer" — nem uma forma de aplicar ou capturar esse estado.

Mise é gerenciado pelo stow (`~/.config/mise/config.toml`) e pelo próprio `mise install` — fox não precisa tocar.

Este spec unifica flatpak + rpm em `~/.config/fox/config.toml`. `fox home apply` lê o config e aplica. `fox home capture` lê o reality e reescreve o config. Um arquivo, dois backends, dois comandos.

## Goals

- [ ] `~/.config/fox/config.toml` declara `[flatpaks]` e `[rpm]`
- [ ] `fox home apply` lê o config e reconcilia flatpak + rpm (instala faltando, remove extras)
- [ ] `fox home capture` lê o estado atual e reescreve o config
- [ ] `fox home diff` mostra drift entre config e reality
- [ ] Starter `fox/config.toml` no stow package `home/` em `/etc/skel`

## Out of Scope

| Feature | Reason |
|---|---|
| Mise | Gerenciado pelo stow + `mise install`. Fox não precisa. |
| nix / home-manager | Spec arquivada |
| Auto-apply/capture em hook | Manual: você decide direção e roda |
| `silverfox-cli-tools` RPM | Inalterado — ferramentas base continuam na imagem |
| `silverfox-flatpaks` serviço | Inalterado — coexiste, mas apply pode remover defaults se não estiverem no config |

---

## Stow tree

```
~/.config/silverfox/stow/
  ├── bash/
  ├── zsh/
  ├── ghostty/
  ├── zed/
  ├── mise/                          ← próprio pacote (inalterado)
  │   └── .config/mise/config.toml
  └── home/                          ← NOVO
      └── .config/fox/config.toml
```

Symlinks:
- `~/.config/mise/config.toml` → `stow/mise/.config/mise/config.toml` (inalterado)
- `~/.config/fox/config.toml` → `stow/home/.config/fox/config.toml` (novo)

---

## fox/config.toml Format

```toml
# ~/.config/fox/config.toml — flatpaks + RPMs.
# fox home apply  → reality   (instala/remove pra bater)
# fox home capture → config   (reescreve o config)
# fox home diff   <> reality  (mostra drift)

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

1. **TOM-01** — Starter `fox/config.toml` em `/etc/skel/.config/silverfox/stow/home/.config/fox/config.toml`.
2. **TOM-02** — `~/.config/fox/config.toml` é symlink para `stow/home/.config/fox/config.toml`.
3. **TOM-03** — `fox home apply` reconcilia `[flatpaks.remotes]` (adiciona faltando, remove extras).
4. **TOM-04** — `fox home apply` reconcilia `[flatpaks.packages]` (instala faltando, remove extras).
5. **TOM-05** — `fox home apply` lê `[rpm.packages]`, roda `rpm-ostree install --allow-inactive` para cada RPM não instalado, `rpm-ostree override remove` para cada RPM instalado que não está na lista. Se houve mudança em RPM, printa "Reboot necessário para aplicar mudanças de RPM."
6. **TOM-06** — Erro em flatpak não bloqueia rpm e vice-versa.
7. **TOM-07** — Idempotente: segunda execução é no-op.

### P1: fox home capture ⭐ MVP

8. **TOM-08** — `fox home capture` lê `flatpak list --app` + `flatpak remote-list` e escreve `[flatpaks]` no config.
9. **TOM-09** — `fox home capture` lê `rpm-ostree status` (layered packages) e escreve `[rpm.packages]` no config.
10. **TOM-10** — `fox home capture` preserva comentários do config existente (substitui só as seções, não o arquivo inteiro). Se não for possível, avisa.

### P1: fox home init ⭐ MVP

11. **TOM-11** — `fox home init` copia stow tree do skel, `stow -R home`, `fox home apply`.
12. **TOM-12** — Idempotente: se `~/.config/fox/config.toml` existe, exit 0.

### P2: fox home diff / edit / status

13. **TOM-13** — `fox home diff` compara config vs reality nos dois backends. Exit 0 se limpo, 1 se drift.
14. **TOM-14** — `fox home edit` abre `~/.config/fox/config.toml` em `$EDITOR`.
15. **TOM-15** — `fox home status` mostra N flatpaks declarados vs instalados, N RPMs declarados vs em camada.

### P3: fox home apply --check / factory-reset

16. **TOM-16** — `fox home apply --check` printa o que cada backend faria sem executar.
17. **TOM-17** — `fox home factory-reset` preserva `~/.config/fox/config.toml`.

---

## Backends em detalhe

| Backend | Apply (config → reality) | Capture (reality → config) |
|---|---|---|
| **Flatpak** | `flatpak remote-add` / `remote-delete` para remotes; `flatpak install` / `uninstall` para packages | `flatpak list --app` + `flatpak remote-list` → escreve `[flatpaks]` |
| **RPM** | `rpm-ostree install <pkg>` para faltando; `rpm-ostree override remove <pkg>` para extras. Avisa reboot se houve mudança. | `rpm-ostree status` (layered) → escreve `[rpm.packages]` |

---

## Módulos

### `os/modules/home/` — stow packages e RPM spec
- **Adicionar**: stow package `home/` com `.config/fox/config.toml`
- **Manter**: `mise/` (inalterado), `bash/`, `zsh/`, `ghostty/`, `zed/`
- **RPM spec `silverfox-home.spec`**: adicionar entradas de `home/`

### `os/modules/fox/` — justfile recipes
- **Adicionar**: `home init`, `home apply`, `home capture`, `home diff`, `home edit`, `home status`
- `home apply`: reconcilia flatpak + RPM

---

## Requirement Traceability

| ID | Story | Phase | Status |
|---|---|---|---|
| TOM-01 | Starter fox/config.toml in skel | Spec | Pending |
| TOM-02 | Configs são stow symlinks | Spec | Pending |
| TOM-03 | apply reconcilia remotes flatpak | Spec | Pending |
| TOM-04 | apply reconcilia packages flatpak | Spec | Pending |
| TOM-05 | apply reconcilia RPMs + aviso reboot | Spec | Pending |
| TOM-06 | apply: erro não bloqueia backends | Spec | Pending |
| TOM-07 | apply idempotente | Spec | Pending |
| TOM-08 | capture: flatpaks do flatpak list | Spec | Pending |
| TOM-09 | capture: RPMs do rpm-ostree status | Spec | Pending |
| TOM-10 | capture preserva comentários | Spec | Pending |
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

- [ ] `fox home init` → stow tree copiado → `fox home apply` → flatpaks instalados, RPMs em camada
- [ ] `~/.config/fox/config.toml` e `~/.config/mise/config.toml` são symlinks (pacote `home/`)
- [ ] Adicionar flatpak no config → `fox home apply` → instalado; remover → desinstalado
- [ ] Adicionar RPM no config → `fox home apply` → `rpm-ostree install` → "Reboot necessário"
- [ ] `flatpak install gimp` + `fox home capture` → gimp no config
- [ ] `fox home diff` mostra drift nos 2 backends, limpo após apply
- [ ] `fox home apply --check` mostra o que mudaria sem executar
- [ ] `fox home factory-reset` não apaga `fox/config.toml`
- [ ] `fox home apply` duas vezes → idêntico, sem erros
