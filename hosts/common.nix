{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
    inputs.nix-flatpak.nixosModules.nix-flatpak

    ../modules/base
    ../modules/cli-tools
    ../modules/fonts
    ../modules/services
    ../modules/kubernetes
    ../modules/niri-defaults
    ../modules/shell-ux
    ../modules/flatpaks
  ];

  system.stateVersion = "25.11";
  nixpkgs.config.allowUnfree = true;

  networking.networkmanager.enable = true;
  time.timeZone = lib.mkDefault "UTC";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  users.defaultUserShell = pkgs.zsh;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = {inherit inputs;};
    users = lib.mapAttrs (_name: _user: {
      imports = [../modules/dotfiles];
    }) (lib.filterAttrs (_n: u: (u.isNormalUser or false)) config.users.users);
  };

  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    auto-optimise-store = true;
    trusted-users = ["root" "@wheel"];
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
}
