# sideral-chezmoi-defaults — image default dotfiles via chezmoi.
#
# Ships: /usr/share/sideral/chezmoi/ source tree (10 managed files in
# chezmoi source format), /etc/profile.d/sideral-chezmoi-defaults.sh
# (first-login auto-apply; fires once, guarded by marker file).
#
# Replaces: /etc/skel/ niri/noctalia/matugen seeding (sideral-niri-defaults)
# and sideral-shell-seed service (sideral-shell-ux). chezmoi can update
# existing users on image upgrade via `ujust apply-defaults`.

Name:           sideral-chezmoi-defaults
Version:        %{?_sideral_version}%{!?_sideral_version:0.0.0}
Release:        1%{?dist}
Summary:        sideral image default dotfiles via chezmoi
License:        MIT
URL:            https://github.com/athenabriana/sideral
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       chezmoi

%description
Ships sideral's default dotfile seed as a chezmoi source tree:
  - /usr/share/sideral/chezmoi/ — managed files: niri/Noctalia/matugen
    configs, ghostty config, full bash/zsh interactive-shell wiring
    (starship/atuin/zoxide/mise/fzf/carapace + Ctrl-P / Alt-S / Ctrl-G
    keybindings + eza/bat aliases + agent guard), nushell env/config
    plus a static vendor-autoload (editor split, agent guard, view
    command), mise toolchain config, and a run_onchange script that
    pre-generates per-tool nushell init files (starship/atuin/zoxide/
    mise) into ~/.local/share/nushell/vendor/autoload/ on every apply
    (workaround for nushell's parse-time `source` keyword).
  - /etc/profile.d/sideral-chezmoi-defaults.sh — sources on every login
    shell; applies all defaults silently on first login (--force --quiet),
    then writes a marker so subsequent logins are instant no-ops.

After `rpm-ostree upgrade`, run `ujust apply-defaults` to pull in new
defaults. Clean files update silently; customized files get a diff prompt.

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/
cp -a usr %{buildroot}/

%files
/etc/profile.d/sideral-chezmoi-defaults.sh
%dir /usr/share/sideral
%dir /usr/share/sideral/chezmoi
/usr/share/sideral/chezmoi/dot_bashrc
/usr/share/sideral/chezmoi/dot_zshrc
/usr/share/sideral/chezmoi/run_onchange_after_install-nu-prompts.sh
%dir /usr/share/sideral/chezmoi/dot_config
%dir /usr/share/sideral/chezmoi/dot_config/niri
/usr/share/sideral/chezmoi/dot_config/niri/config.kdl
/usr/share/sideral/chezmoi/dot_config/niri/noctalia.kdl
%dir /usr/share/sideral/chezmoi/dot_config/ghostty
/usr/share/sideral/chezmoi/dot_config/ghostty/config
%dir /usr/share/sideral/chezmoi/dot_config/noctalia
/usr/share/sideral/chezmoi/dot_config/noctalia/settings.json
%dir /usr/share/sideral/chezmoi/dot_config/matugen
%dir /usr/share/sideral/chezmoi/dot_config/matugen/templates
/usr/share/sideral/chezmoi/dot_config/matugen/config.toml
/usr/share/sideral/chezmoi/dot_config/matugen/templates/ghostty
/usr/share/sideral/chezmoi/dot_config/matugen/templates/helix.toml
%dir /usr/share/sideral/chezmoi/dot_config/nushell
/usr/share/sideral/chezmoi/dot_config/nushell/env.nu
/usr/share/sideral/chezmoi/dot_config/nushell/config.nu
%dir /usr/share/sideral/chezmoi/dot_config/mise
/usr/share/sideral/chezmoi/dot_config/mise/config.toml
%dir /usr/share/sideral/chezmoi/dot_local
%dir /usr/share/sideral/chezmoi/dot_local/share
%dir /usr/share/sideral/chezmoi/dot_local/share/nushell
%dir /usr/share/sideral/chezmoi/dot_local/share/nushell/vendor
%dir /usr/share/sideral/chezmoi/dot_local/share/nushell/vendor/autoload
/usr/share/sideral/chezmoi/dot_local/share/nushell/vendor/autoload/sideral-cli-init.nu

%changelog
* Mon May 04 2026 GitHub Actions <noreply@github.com> - 0.0.0-2
- Absorb interactive-shell wiring from sideral-shell-ux. dot_bashrc and
  dot_zshrc now ship the full sideral CLI init (starship/atuin/zoxide/
  mise/fzf/carapace, Ctrl-P/Alt-S/Ctrl-G keybindings, eza/bat aliases,
  14-marker AI-agent guard, zsh compinit-before-tools fix). Ship
  dot_local/share/nushell/vendor/autoload/sideral-cli-init.nu (env-phase
  editor split + agent guard + `view` command) and
  run_onchange_after_install-nu-prompts.sh (pre-generates per-tool nu
  init files for starship/atuin/zoxide/mise into the user's vendor
  autoload dir on every chezmoi apply, with the atuin -t→-d sed patch).
- All shell wiring is now user-editable via $HOME — no sudo, no rebase,
  no rebuild. Run `ujust apply-defaults` to restore sideral's defaults.
* Sun May 04 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial: ship /usr/share/sideral/chezmoi/ source tree (10 files) and
  /etc/profile.d/sideral-chezmoi-defaults.sh first-login auto-apply.
  Replaces skel + sideral-shell-seed seeding mechanisms.
