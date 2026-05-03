# sideral-shell-ux — interactive-shell hooks (CLI init wiring).
#
# Lives in the shell-ux module.

Name:           sideral-shell-ux
Version:        %{?_sideral_version}%{!?_sideral_version:0.0.0}
Release:        1%{?dist}
Summary:        sideral shell wiring for bash, zsh, and nushell
License:        MIT
URL:            https://github.com/athenabriana/sideral
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       bash
# fish is in sideral-cli-tools' Requires graph and is the parallel
# default for users who `chsh -s /usr/bin/fish` after deployment.

%description
Ships shell wiring for bash, zsh, and nushell — same tools, same
agent guard, same Ctrl+P quick-open — plus ujust recipes, user-motd,
a system-wide mise config, and per-login shell maintenance scripts.

Bash — /etc/profile.d/sideral-cli-init.sh:
  Wires starship, atuin, zoxide, mise (shims + activate), fzf, carapace.
  EDITOR=hx / VISUAL=code. eza/bat aliases (skipped on AI-agent shells).
  Ctrl+P fzf quick-open. Each tool is `command -v`-guarded.

Zsh — /etc/zsh/sideral-cli-init.zsh + /etc/zshrc:
  Same wiring in zsh syntax. The shipped /etc/zshrc replaces Fedora's
  stock stub via rpm -Uvh --replacefiles. carapace is the sole tab-
  completion backend; zsh-syntax-highlighting + zsh-autosuggestions kept.

Nushell — /usr/share/nushell/vendor/autoload/sideral-cli-init.nu:
  Vendor autoload wires starship, atuin, zoxide, `view` command, agent
  detection, EDITOR/VISUAL. No eza/bat aliases (nushell has structured
  `ls`). mise, keybindings, and carapace completer live in chezmoi-seeded
  config.nu (see sideral-chezmoi-defaults).

Shell maintenance — /etc/profile.d/ login-time scripts:
  sideral-shell-migrate.sh: auto-migrates users whose login shell binary
  no longer exists (e.g. fish removed) to /usr/bin/zsh (sudo -n, safe).
  sideral-nushell-plugins.sh: registers /usr/lib/nushell/plugins/ into
  the user's plugin.msgpackz on first encounter; no-op once registered.

mise config — /etc/mise/config.toml:
  System-wide settings (trusted_config_paths, not_found_auto_install,
  etc.). Tools declared in user-level ~/.config/mise/config.toml (seeded
  by sideral-chezmoi-defaults on first login).

ujust recipes — /usr/share/ublue-os/just/60-custom.just:
  chsh [bash|zsh|nu], chezmoi, apply-defaults, gdrive-setup, gdrive-remove,
  tools, theme, niri.

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/
cp -a usr %{buildroot}/

%files
/etc/profile.d/sideral-cli-init.sh
/etc/profile.d/sideral-shell-migrate.sh
/etc/profile.d/sideral-nushell-plugins.sh
/etc/zsh/sideral-cli-init.zsh
/etc/zshrc
/etc/user-motd
/etc/mise/config.toml
/usr/share/nushell/vendor/autoload/sideral-cli-init.nu
/usr/share/ublue-os/just/60-custom.just
/usr/lib/systemd/user/rclone-gdrive.service

%changelog
* Sun May 04 2026 GitHub Actions <noreply@github.com> - 0.0.0-13
- Remove sideral-shell-seed.service + /usr/libexec/sideral-shell-seed.
  Dotfile seeding replaced by sideral-chezmoi-defaults (profile.d auto-
  apply on first login). Extract two surviving behaviors into profile.d:
  sideral-shell-migrate.sh (broken-login-shell → zsh; sudo -n for safety)
  and sideral-nushell-plugins.sh (register /usr/lib/nushell/plugins/ into
  user plugin.msgpackz on first encounter).
* Sun May 03 2026 GitHub Actions <noreply@github.com> - 0.0.0-12
- Fish → Nushell migration. Remove /etc/fish/conf.d/sideral-cli-init.fish.
  Add /usr/share/nushell/vendor/autoload/sideral-cli-init.nu (env-phase
  wiring: starship, atuin, zoxide, view command, agent detection,
  EDITOR/VISUAL; no eza/bat aliases — nushell has structured ls).
- Add sideral-shell-seed.service (systemd user unit, WantedBy=default.target)
  + /usr/libexec/sideral-shell-seed script. Idempotent on every session:
  auto-migrates broken login shell to /usr/bin/zsh, seeds ~/.bashrc,
  ~/.zshrc, ~/.config/nushell/{env,config}.nu, ~/.config/mise/config.toml
  if missing. Never overwrites existing files.
- ujust chsh: replace fish with nu; picker now offers {zsh,nu,bash}.
- ujust tools motd: updated shell section to reference nu instead of fish.
* Sun May 03 2026 GitHub Actions <noreply@github.com> - 0.0.0-11
- Restore /etc/mise/config.toml (system-wide baseline toolchain lost in
  chezmoi-home migration). Ships 12 tools: node/bun/pnpm, python/uv,
  java-temurin-lts/kotlin/gradle, go/rust/zig, act. not_found_auto_install
  enables lazy install on first use (type `node`, mise auto-installs).
  trusted_config_paths=["/"] suppresses per-project trust prompts.
- Fix mise activation in bash + zsh: add ~/.local/share/mise/shims to
  PATH unconditionally; guard `mise activate` for interactive shells only.
  Resolves "command not found" for mise-managed tools before first prompt
  render and in non-interactive contexts (scripts, SSH exec).
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-10
- Add /etc/user-motd row for `ujust niri` (niri+Noctalia cheatsheet).
- Add `ujust theme <wallpaper>` recipe to 60-custom.just: runs matugen,
  seeds per-user config from /etc/xdg on first use, signals ghostty
  via SIGUSR1, writes ghostty palette to config-matugen and helix theme
  to ~/.config/helix/themes/sideral.toml.
- Add `ujust niri` recipe to 60-custom.just: niri+Noctalia keybind
  cheatsheet with theming instructions and config override paths.
  Modeled on existing `ujust tools` shape (libformatting.sh, OSC-8
  Urllinks, B/D/R styling).
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-9
- Add `ujust gdrive-remove` recipe — counterpart to gdrive-setup.
  Disables + stops the rclone-gdrive systemd user unit, defensively
  unmounts ~/gdrive if the ExecStop hook didn't fire, then prompts
  via ugum confirm whether to also wipe the rclone gdrive: remote
  config + remove the empty ~/gdrive directory. Default leaves the
  rclone config in place so a future re-enable via `ujust gdrive-
  setup` is a one-step no-OAuth re-arm.
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-8
- Ship /usr/lib/systemd/user/rclone-gdrive.service. Systemd USER unit
  that runs `rclone mount gdrive: %h/gdrive --vfs-cache-mode=writes
  --daemon` with WantedBy=default.target so it auto-mounts on every
  login once enabled. Restart=on-failure handles transient network
  drops and OAuth-token refresh hiccups. Not enabled by default —
  user opts in via the new `ujust gdrive-setup` recipe (single
  command: walks rclone OAuth on first run, enables + starts the
  unit, sticks across reboots). Replaces the previous three-recipe
  init/mount/unmount split with one auto-mount-forever flow.
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-7
- Add /etc/zsh/sideral-cli-init.zsh + /etc/zshrc — zsh port of the
  bash/fish init. Same 14-marker agent detection, same eza/bat
  aliases, same Ctrl+P fzf quick-open (via zsh's ZLE widget +
  bindkey '^P'). The shipped /etc/zshrc replaces Fedora's stock
  zsh package /etc/zshrc via rpm -Uvh --replacefiles — content is
  minimal (umask + source sideral-cli-init.zsh).
- Add /etc/user-motd — every-login banner picked up by ublue-os-
  just's /etc/profile.d/user-motd.sh. Lists the common `ujust`
  recipes. User opt-out via touch ~/.config/no-show-user-motd.
- Drop /etc/profile.d/sideral-onboarding.sh — replaced by the motd
  (works for any login shell, not just bash; shows on every login,
  not just the first; consistent with bluefin's first-run UX).
- Extend 60-custom.just: `ujust chsh` now accepts zsh as a third
  option, and a new `ujust chezmoi-init <repo>` recipe replaces the
  removed onboarding hint with an actually-actionable command.
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-6
- Add /usr/share/ublue-os/just/60-custom.just — sideral's ujust recipe
  drop-in. Fills the `import? "60-custom.just"` slot left by ublue-os/
  main's justfile for downstreams. First recipe: `ujust chsh [shell]`,
  defaulting to fish, switches login shell via sudo usermod -s
  (chsh proper is removed by ublue's setuid hardening). Run
  `ujust chsh bash` to switch back, `ujust` (no args) to list all
  recipes including ublue's stock set.
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-5
- Add /etc/fish/conf.d/sideral-cli-init.fish — fish port of the bash
  init. Same tool wiring (starship/atuin/zoxide/mise/fzf), same
  EDITOR=hx + VISUAL=code, same agent-shell detection list (14
  markers), same Ctrl+P → fzf quick-open, same eza/bat aliases. Fish
  brings syntax highlighting + autosuggestions + smarter tab
  completion built-in (no config needed). Bash init unchanged. Switch
  per-user with `chsh -s /usr/bin/fish` after deployment; both shells
  remain functional out of the box.
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-4
- Module refactor: source tree moved to os/modules/shell-ux/src/.
  /etc/profile.d/sideral-kind-podman.sh ownership transferred to
  sideral-kubernetes (kubernetes module owns its K8s-tooling-specific
  shell wiring). Spec name kept for upgrade safety. No file conflict
  on image build — sideral-kubernetes claims the path cleanly via
  rpm -Uvh --replacefiles in the inline-RPM step.
* Sat May 02 2026 GitHub Actions <noreply@github.com> - 0.0.0-3
- Add sideral-kind-podman.sh (subsequently moved to sideral-kubernetes
  in -4).
* Fri May 01 2026 GitHub Actions <noreply@github.com> - 0.0.0-2
- Replace sideral-hm-status.sh (home-manager bootstrap waiter, retired
  alongside nix-home) with sideral-cli-init.sh (CHM-11/12) and
  sideral-onboarding.sh (CHM-21/22).
* Thu Apr 23 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: poll-and-source bootstrap UX (sideral-hm-status.sh)
