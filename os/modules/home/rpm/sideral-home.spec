# sideral-home — user-domain seed via /etc/skel.
#
# Ships sideral's image-default dotfiles as a stow source tree at
# /etc/skel/.config/sideral/stow/{bash,zsh,mise,ghostty,zed}/, plus five
# pre-farmed relative symlinks at /etc/skel/{.bashrc,.zshrc,.config/...}.
# `useradd` (traditional Unix, cp -a semantics) copies the whole tree
# into new user homes, preserving symlinks. From that moment forward the
# dotfiles are user-domain — sideral never modifies them. Image upgrades
# that change defaults affect only future-created users; existing users
# own their copy.
#
# To revert to image defaults destructively: `fox home factory-reset`.
# To customize a single file: replace the symlink with a real file and
# edit; future factory-resets will overwrite it.
#
# Replaces sideral-stow-defaults, which seeded via stow-on-first-login
# against /usr/share/sideral/stow/ (read-only ostree-symlinked).

Name:           sideral-home
Version:        %{?_sideral_version}%{!?_sideral_version:0.0.0}
Release:        1%{?dist}
Summary:        sideral user-domain seed (/etc/skel stow tree + pre-farmed symlinks)
License:        MIT
URL:            https://github.com/athenabriana/sideral
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch

%description
Ships sideral's image-default user dotfiles via /etc/skel:

  - /etc/skel/.config/sideral/stow/{bash,zsh,mise,ghostty,zed}/ — five
    stow packages holding the real config content (bash + zsh rcs with
    starship/atuin/zoxide/mise/fzf wiring, mise user toolchain pins,
    ghostty config, zed settings with vim_mode + helix_normal).
  - /etc/skel/{.bashrc, .zshrc} — top-level relative symlinks into the
    stow tree.
  - /etc/skel/.config/{mise/config.toml, ghostty/config, zed/settings.json}
    — depth-2 relative symlinks into the stow tree.

useradd copies the whole tree (cp -a semantics preserves symlinks) into
new user homes. The stow tree gives users `stow`-friendly ergonomics
without sideral owning the post-useradd state.

%prep
%setup -q

%install
mkdir -p %{buildroot}
cp -a etc %{buildroot}/

%files
%dir /etc/skel/.config/sideral
%dir /etc/skel/.config/sideral/stow
%dir /etc/skel/.config/sideral/stow/bash
/etc/skel/.config/sideral/stow/bash/.bashrc
%dir /etc/skel/.config/sideral/stow/zsh
/etc/skel/.config/sideral/stow/zsh/.zshrc
%dir /etc/skel/.config/sideral/stow/mise
%dir /etc/skel/.config/sideral/stow/mise/.config
%dir /etc/skel/.config/sideral/stow/mise/.config/mise
/etc/skel/.config/sideral/stow/mise/.config/mise/config.toml
%dir /etc/skel/.config/sideral/stow/ghostty
%dir /etc/skel/.config/sideral/stow/ghostty/.config
%dir /etc/skel/.config/sideral/stow/ghostty/.config/ghostty
/etc/skel/.config/sideral/stow/ghostty/.config/ghostty/config
%dir /etc/skel/.config/sideral/stow/zed
%dir /etc/skel/.config/sideral/stow/zed/.config
%dir /etc/skel/.config/sideral/stow/zed/.config/zed
/etc/skel/.config/sideral/stow/zed/.config/zed/settings.json
%dir /etc/skel/.config/sideral/stow/nix
%dir /etc/skel/.config/sideral/stow/nix/.config
%dir /etc/skel/.config/sideral/stow/nix/.config/nix
/etc/skel/.config/sideral/stow/nix/.config/nix/flake.nix
/etc/skel/.config/sideral/stow/nix/.config/nix/flake.lock
/etc/skel/.bashrc
/etc/skel/.zshrc
%dir /etc/skel/.config/mise
/etc/skel/.config/mise/config.toml
%dir /etc/skel/.config/ghostty
/etc/skel/.config/ghostty/config
%dir /etc/skel/.config/zed
/etc/skel/.config/zed/settings.json

%changelog
* Mon May 11 2026 GitHub Actions <noreply@github.com> - 0.0.0-1
- Initial. Replaces sideral-stow-defaults: image-default dotfiles now
  seed via /etc/skel + useradd (cp -a), not via stow-on-first-login
  against a read-only ostree path. Source tree migrated as-is from
  os/modules/dotfiles/src/usr/share/sideral/stow/ to
  os/modules/home/src/etc/skel/.config/sideral/stow/. Five pre-farmed
  relative symlinks at /etc/skel/{.bashrc,.zshrc,.config/...} resolve
  into the stow tree at useradd time, preserving symlink-into-stow
  ergonomics inside $HOME. mise user pins ship without the JVM block
  (9 toolchains: node, bun, pnpm, python, uv, go, rust, zig, act).
