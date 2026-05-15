# modules/home.nix — user identity + globally-installed packages.
#
# username/homeDirectory use the __USER__ placeholder which is
# substituted at first-login by silverfox-home-sync.sh. To customize,
# edit this file and run `fox sync`.

{ pkgs, ... }:
{
  home = {
    username = "__USER__";
    homeDirectory = "/home/__USER__";
    stateVersion = "24.11";
    packages = [
      pkgs.opencode
      pkgs.atuin
      pkgs.fzf
      pkgs.bat
      pkgs.eza
      pkgs.ripgrep
      pkgs.zoxide
      pkgs.gh
      pkgs.git-lfs
      pkgs.gcc
      pkgs.gnumake
      pkgs.cmake
    ];
  };
}
