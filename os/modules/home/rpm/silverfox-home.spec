# silverfox-home — user-domain seed via /etc/skel + home-sync.
#
# Ships /etc/skel/Dotfiles/{home-manager/, stow/{shell,ghostty,flavours,zed}/}
# and a profile.d script that bootstraps ~/Dotfiles/ from skel on first
# login, runs stow on each package every login, syncs nix home-manager,
# and ensures a default base16 theme is applied.

Name:           silverfox-home
Version:        %{?_silverfox_version}%{!?_silverfox_version:0.0.0}
Release:        1%{?dist}
Summary:        silverfox user-domain seed (/etc/skel Dotfiles + home-sync)
License:        MIT
URL:            https://github.com/athenabriana/silverfox
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       stow

%description
Ships silverfox's image-default user dotfiles via /etc/skel and syncs them
on every login:

  - /etc/skel/Dotfiles/{shell,ghostty,flavours,zed}/ — stow packages com
    as configurações padrão. O pacote shell agrupa .bashrc + .zshrc +
    starship.toml + módulos POSIX em .config/shell/*.sh; ghostty é o
    terminal; flavours tem base16 + template COSMIC; zed é o editor.

  - /etc/profile.d/silverfox-home-sync.sh — no primeiro login copia a
    árvore inteira de /etc/skel/Dotfiles para $HOME/Dotfiles; em todo
    login roda stow, sincroniza nix home-manager em background, importa
    o tema gerado pelo flavours via `cosmic-settings appearance import`.
    Use `fox dotfiles-reset` para restaurar o estado original do sistema.

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/

%files
%dir /etc/skel/Dotfiles
%dir /etc/skel/Dotfiles/home-manager
/etc/skel/Dotfiles/home-manager/flake.nix
%dir /etc/skel/Dotfiles/home-manager/modules
/etc/skel/Dotfiles/home-manager/modules/home.nix
/etc/skel/Dotfiles/home-manager/modules/mise.nix
/etc/skel/Dotfiles/home-manager/modules/mise.toml
/etc/skel/Dotfiles/home-manager/modules/flatpak.nix
%dir /etc/skel/Dotfiles/stow
%dir /etc/skel/Dotfiles/stow/shell
/etc/skel/Dotfiles/stow/shell/.bashrc
/etc/skel/Dotfiles/stow/shell/.zshrc
%dir /etc/skel/Dotfiles/stow/shell/.config
%dir /etc/skel/Dotfiles/stow/shell/.config/shell
/etc/skel/Dotfiles/stow/shell/.config/shell/00-path.sh
/etc/skel/Dotfiles/stow/shell/.config/shell/10-editor.sh
/etc/skel/Dotfiles/stow/shell/.config/shell/20-nix.sh
/etc/skel/Dotfiles/stow/shell/.config/shell/30-agent-detect.sh
/etc/skel/Dotfiles/stow/shell/.config/shell/40-aliases.sh
/etc/skel/Dotfiles/stow/shell/.config/shell/50-mise-shims.sh
/etc/skel/Dotfiles/stow/shell/.config/starship.toml
%dir /etc/skel/Dotfiles/stow/ghostty
%dir /etc/skel/Dotfiles/stow/ghostty/.config
%dir /etc/skel/Dotfiles/stow/ghostty/.config/ghostty
/etc/skel/Dotfiles/stow/ghostty/.config/ghostty/config
/etc/skel/Dotfiles/stow/ghostty/.config/ghostty/config-base16
%dir /etc/skel/Dotfiles/stow/flavours
%dir /etc/skel/Dotfiles/stow/flavours/.config
%dir /etc/skel/Dotfiles/stow/flavours/.config/flavours
/etc/skel/Dotfiles/stow/flavours/.config/flavours/config.toml
%dir /etc/skel/Dotfiles/stow/flavours/.config/flavours/templates
%dir /etc/skel/Dotfiles/stow/flavours/.config/flavours/templates/ghostty
%dir /etc/skel/Dotfiles/stow/flavours/.config/flavours/templates/ghostty/templates
/etc/skel/Dotfiles/stow/flavours/.config/flavours/templates/ghostty/templates/default.mustache
%dir /etc/skel/Dotfiles/stow/flavours/.config/flavours/templates/zed
%dir /etc/skel/Dotfiles/stow/flavours/.config/flavours/templates/zed/templates
/etc/skel/Dotfiles/stow/flavours/.config/flavours/templates/zed/templates/default.mustache
%dir /etc/skel/Dotfiles/stow/flavours/.config/flavours/templates/cosmic-theme
%dir /etc/skel/Dotfiles/stow/flavours/.config/flavours/templates/cosmic-theme/templates
/etc/skel/Dotfiles/stow/flavours/.config/flavours/templates/cosmic-theme/templates/default.mustache
%dir /etc/skel/Dotfiles/stow/flavours/.config/flavours/templates/cosmic-wallpaper-all
%dir /etc/skel/Dotfiles/stow/flavours/.config/flavours/templates/cosmic-wallpaper-all/templates
/etc/skel/Dotfiles/stow/flavours/.config/flavours/templates/cosmic-wallpaper-all/templates/default.mustache
%dir /etc/skel/Dotfiles/stow/flavours/.config/flavours/templates/cosmic-wallpaper-colors
%dir /etc/skel/Dotfiles/stow/flavours/.config/flavours/templates/cosmic-wallpaper-colors/templates
/etc/skel/Dotfiles/stow/flavours/.config/flavours/templates/cosmic-wallpaper-colors/templates/default.mustache
%dir /etc/skel/Dotfiles/stow/zed
%dir /etc/skel/Dotfiles/stow/zed/.config
%dir /etc/skel/Dotfiles/stow/zed/.config/zed
/etc/skel/Dotfiles/stow/zed/.config/zed/settings.json
%dir /etc/skel/Dotfiles/stow/zed/.config/zed/themes
/etc/skel/Dotfiles/stow/zed/.config/zed/themes/base16-dark.json
/etc/profile.d/silverfox-home-sync.sh

%changelog
* Thu May 14 2026 GitHub Actions <noreply@github.com> - 0.0.0-3
- skel-merge.sh: replace "sempre copia arquivos novos no login" com
  bootstrap único (só copia se ~/Dotfiles/ não existir) + stow sempre.
  O reset manual fica com `fox home reset`.
* Thu May 14 2026 GitHub Actions <noreply@github.com> - 0.0.0-2
- Sync flake.nix with downstream usage: add nixd/nil/opencode to
  home.packages (Nix LSPs + opencode CLI as baseline tooling); simplify
  programs.mise.globalConfig.settings (drop experimental,
  idiomatic_version_file_enable_tools, jobs, http_timeout, show_env,
  show_tools); add auto_install=true; status.missing_tools="always".
  Drop act from tools (kept node/bun/pnpm/python/uv/go/rust/zig).
  Drop com.ranfdev.DistroShelf + re.sonny.Junction from the flatpak
  seed. Reformat with nixfmt-RFC.
- Unify bash + zsh stow packages into single shell/ package. Both
  .bashrc and .zshrc now live under /etc/skel/Dotfiles/shell/. Existing
  users with ~/Dotfiles/{bash,zsh} stay functional (skel-merge never
  overwrites) but should manually migrate to ~/Dotfiles/shell/ and
  re-stow.
- Drop zed/ stow package. Zed manages its own settings.json in
  ~/.config/zed/ and the seed conflicted with its writes.
* Wed May 14 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Simplifica: remove symlinks diretos do skel, skel-merge copia Dotfiles e
  aplica stow automaticamente no login. Script migrado do módulo nix.
