# sideral-stow-defaults — image default dotfiles via GNU stow.
#
# Ships: /usr/share/sideral/stow/<pkg>/ source tree (one stow package
# per concern: bash, zsh, ghostty, mise) and
# /etc/profile.d/sideral-stow-defaults.sh (first-login auto-apply via
# stow; marker-guarded so subsequent logins are instant no-ops).
#
# Re-apply after `rpm-ostree upgrade` with `ujust apply-defaults` to
# pick up new files added to the seed.

Name:           sideral-stow-defaults
Version:        %{?_sideral_version}%{!?_sideral_version:0.0.0}
Release:        1%{?dist}
Summary:        sideral image default dotfiles via GNU stow
License:        MIT
URL:            https://github.com/athenabriana/sideral
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

Requires:       stow

%description
Ships sideral's default dotfile seed as GNU-stow packages:
  - /usr/share/sideral/stow/<pkg>/ — one subdir per concern
    (bash/, zsh/, ghostty/, mise/). Each holds the destination-shaped
    layout (e.g. ghostty/.config/ghostty/config) so
    `stow --target=$HOME --dir=/usr/share/sideral/stow <pkg>` symlinks
    cleanly into $HOME.
  - /etc/profile.d/sideral-stow-defaults.sh — sources on every login
    shell; runs stow over every package on first login (marker-guarded),
    then becomes an instant no-op.

To re-apply after `rpm-ostree upgrade` (e.g. when a new package was
added to the seed), run `ujust apply-defaults`. To customize a single
file, replace its symlink with a real file before editing — stow will
refuse to overwrite a regular file on next apply.

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/
cp -a usr %{buildroot}/

%files
/etc/profile.d/sideral-stow-defaults.sh
%dir /usr/share/sideral
%dir /usr/share/sideral/stow
%dir /usr/share/sideral/stow/bash
/usr/share/sideral/stow/bash/.bashrc
%dir /usr/share/sideral/stow/zsh
/usr/share/sideral/stow/zsh/.zshrc
%dir /usr/share/sideral/stow/ghostty
%dir /usr/share/sideral/stow/ghostty/.config
%dir /usr/share/sideral/stow/ghostty/.config/ghostty
/usr/share/sideral/stow/ghostty/.config/ghostty/config
%dir /usr/share/sideral/stow/mise
%dir /usr/share/sideral/stow/mise/.config
%dir /usr/share/sideral/stow/mise/.config/mise
/usr/share/sideral/stow/mise/.config/mise/config.toml

%changelog
* Sun May 10 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial. Replaces sideral-chezmoi-defaults: chezmoi swapped for GNU
  stow as the image-default dotfile seeding tool. Source tree
  reorganized from chezmoi format (dot_bashrc, dot_config/...) to
  per-package stow layout (bash/.bashrc, ghostty/.config/ghostty/...).
  /etc/profile.d/sideral-stow-defaults.sh runs `stow --restow
  --no-folding` over every package on first login. nushell support
  dropped alongside the swap.
