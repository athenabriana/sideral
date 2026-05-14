# silverfox-home — user-domain seed via /etc/skel + skel-merge.
#
# Ships a stow source tree at /etc/skel/Dotfiles/{bash,zsh,ghostty,zed,nix}/
# and a profile.d script that copies new Dotfiles to $HOME/Dotfiles on login
# and runs stow on each package.

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

  - /etc/skel/Dotfiles/{bash,zsh,ghostty,zed,nix}/ — stow packages com as
    configurações padrão (zshrc com starship/atuin/zoxide/mise/fzf, ghostty,
    zed, nix flake para nh).

  - /etc/profile.d/silverfox-skel-merge.sh — em todo login copia arquivos
    novos de /etc/skel/Dotfiles para $HOME/Dotfiles (ignora existentes) e
    roda stow em cada pacote para criar os symlinks em $HOME.

Arquivos já existentes em $HOME nunca são modificados.

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/

%files
%dir /etc/skel/Dotfiles
%dir /etc/skel/Dotfiles/bash
/etc/skel/Dotfiles/bash/.bashrc
%dir /etc/skel/Dotfiles/zsh
/etc/skel/Dotfiles/zsh/.zshrc
%dir /etc/skel/Dotfiles/ghostty
%dir /etc/skel/Dotfiles/ghostty/.config
%dir /etc/skel/Dotfiles/ghostty/.config/ghostty
/etc/skel/Dotfiles/ghostty/.config/ghostty/config
%dir /etc/skel/Dotfiles/zed
%dir /etc/skel/Dotfiles/zed/.config
%dir /etc/skel/Dotfiles/zed/.config/zed
/etc/skel/Dotfiles/zed/.config/zed/settings.json
%dir /etc/skel/Dotfiles/nix
%dir /etc/skel/Dotfiles/nix/.config
%dir /etc/skel/Dotfiles/nix/.config/nix
/etc/skel/Dotfiles/nix/.config/nix/flake.nix
/etc/skel/Dotfiles/nix/.config/nix/flake.lock
/etc/profile.d/silverfox-skel-merge.sh

%changelog
* Wed May 14 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Simplifica: remove symlinks diretos do skel, skel-merge copia Dotfiles e
  aplica stow automaticamente no login. Script migrado do módulo nix.
