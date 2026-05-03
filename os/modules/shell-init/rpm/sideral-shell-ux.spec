# sideral-shell-ux — interactive-shell hooks (CLI init wiring + onboarding tip).
#
# Lives in the shell-init module. Spec name kept (sideral-shell-ux)
# for upgrade safety; the module name "shell-init" is more accurate
# but renaming the spec adds Obsoletes:/Provides: complexity for no
# functional gain.

Name:           sideral-shell-ux
Version:        %{?_sideral_version}%{!?_sideral_version:0.0.0}
Release:        1%{?dist}
Summary:        sideral shell-init wiring + chezmoi onboarding hint
License:        MIT
URL:            https://github.com/athenabriana/sideral
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       bash
# fish is in sideral-cli-tools' Requires graph and is the parallel
# default for users who `chsh -s /usr/bin/fish` after deployment.

%description
Ships shell-init wiring for bash, fish, and zsh — same tools, same
agent guard, same Ctrl+P quick-open, same eza/bat aliases — plus
ujust recipes and the user-motd banner.

Bash side — /etc/profile.d/sideral-cli-init.sh:
  Central wiring for starship, atuin, zoxide, mise, fzf. Plus
  EDITOR=hx / VISUAL=code, eza/bat aliases (skipped on AI-agent
  shells), and Ctrl+P → fzf quick-open. Each integration is
  `command -v`-guarded so `rpm-ostree override remove` of any one
  tool doesn't break the rest.

Fish side — /etc/fish/conf.d/sideral-cli-init.fish:
  Fish port. Fish brings syntax highlighting + autosuggestions +
  smarter tab completion built-in.

Zsh side — /etc/zsh/sideral-cli-init.zsh + /etc/zshrc:
  Zsh port (same shape, zsh syntax). The shipped /etc/zshrc replaces
  Fedora's stock 3-line stub via rpm -Uvh --replacefiles; it sets
  umask and sources sideral-cli-init.zsh.

User-facing UX — /etc/user-motd:
  Welcome banner displayed on every interactive login by ublue-os-
  just's /etc/profile.d/user-motd.sh. Lists the most-used `ujust`
  recipes (chsh, chezmoi-init, update). Per-user opt-out via
  `touch ~/.config/no-show-user-motd`. Replaces the previous
  one-shot sideral-onboarding.sh (was bash-only and tied to first-
  shell; the motd works for any login shell and any session).

ujust recipes — /usr/share/ublue-os/just/60-custom.just:
  Fills the ublue-os-just `import? "60-custom.just"` extension slot.
  Provides `chsh [bash|fish|zsh]` (sudo usermod wrapper) and
  `chezmoi-init <repo>` (chezmoi init --apply wrapper).

(sideral-kind-podman.sh moved to sideral-kubernetes 2026-05-02 as part
of the module refactor — that snippet is K8s-tooling-specific, not a
generic shell-init concern.)

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/
cp -a usr %{buildroot}/

%files
/etc/profile.d/sideral-cli-init.sh
/etc/fish/conf.d/sideral-cli-init.fish
/etc/zsh/sideral-cli-init.zsh
/etc/zshrc
/etc/user-motd
/usr/share/ublue-os/just/60-custom.just
/usr/lib/systemd/user/rclone-gdrive.service

%changelog
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
- Module refactor: source tree moved to os/modules/shell-init/src/.
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
