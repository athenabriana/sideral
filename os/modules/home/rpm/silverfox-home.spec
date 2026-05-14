# silverfox-home — user-domain seed via /etc/skel + skel-merge.
#
# Ships a stow source tree at /etc/skel/Dotfiles/{shell,ghostty,nix}/
# and a profile.d script that bootstraps ~/Dotfiles/ from skel on first
# login, then runs stow on each package every login.

Name:           silverfox-home
Version:        %{?_silverfox_version}%{!?_silverfox_version:0.0.0}
Release:        1%{?dist}
Summary:        silverfox user-domain seed (/etc/skel Dotfiles + skel-merge)
License:        MIT
URL:            https://github.com/athenabriana/silverfox
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       stow

%description
Ships silverfox's image-default user dotfiles via /etc/skel and applies them
on first login:

  - /etc/skel/Dotfiles/{shell,ghostty,nix}/ — stow packages com as
    configurações padrão (shell unifica .bashrc + .zshrc com starship/
    atuin/zoxide/mise/fzf; ghostty; nix flake para nh).

  - /etc/profile.d/silverfox-skel-merge.sh — no primeiro login copia a
    árvore inteira de /etc/skel/Dotfiles para $HOME/Dotfiles; em todo
    login roda stow em cada pacote para criar os symlinks em $HOME.
    Use `fox home reset` para restaurar o estado original do sistema.

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/

%files
%dir /etc/skel/Dotfiles
%dir /etc/skel/Dotfiles/shell
/etc/skel/Dotfiles/shell/.bashrc
/etc/skel/Dotfiles/shell/.zshrc
%dir /etc/skel/Dotfiles/ghostty
%dir /etc/skel/Dotfiles/ghostty/.config
%dir /etc/skel/Dotfiles/ghostty/.config/ghostty
/etc/skel/Dotfiles/ghostty/.config/ghostty/config
%dir /etc/skel/Dotfiles/nix
%dir /etc/skel/Dotfiles/nix/.config
%dir /etc/skel/Dotfiles/nix/.config/nix
/etc/skel/Dotfiles/nix/.config/nix/flake.nix
/etc/skel/Dotfiles/nix/.config/nix/flake.lock
/etc/profile.d/silverfox-skel-merge.sh

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
