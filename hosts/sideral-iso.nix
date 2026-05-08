{
  modulesPath,
  pkgs,
  lib,
  self,
  ...
}: {
  imports = [
    "${modulesPath}/installer/cd-dvd/iso-image.nix"
    "${modulesPath}/profiles/all-hardware.nix"
    "${modulesPath}/profiles/base.nix"
    ../modules/base
  ];

  system.stateVersion = "25.11";
  system.nixos.variant_id = "iso";
  networking.hostName = "sideral-installer";

  isoImage = {
    isoName = "sideral_x86_64.iso";
    volumeID = "SIDERAL_INSTALL";
    makeEfiBootable = true;
    makeUsbBootable = true;
    squashfsCompression = "zstd -Xcompression-level 19";
  };

  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    trusted-users = ["root" "@wheel"];
  };

  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false;

  environment.systemPackages = with pkgs; [
    calamares-nixos
    calamares-nixos-extensions
    parted
    gparted
    pciutils
    nixos-install-tools
    git
    vim
    curl
  ];

  environment.etc = {
    "calamares/settings.conf".source = ../iso/calamares/settings.conf;
    "calamares/branding/sideral/branding.desc".source = ../iso/calamares/branding/sideral/branding.desc;
    "calamares/branding/sideral/sideral-logo.svg".source = ../iso/calamares/branding/sideral/sideral-logo.svg;
    "calamares/branding/sideral/welcome.png".source = ../iso/calamares/branding/sideral/welcome.png;
    "calamares/branding/sideral/stylesheet.qss".source = ../iso/calamares/branding/sideral/stylesheet.qss;
    "calamares/modules/welcome.conf".source = ../iso/calamares/modules/welcome.conf;
    "calamares/modules/partition.conf".source = ../iso/calamares/modules/partition.conf;
    "calamares/modules/users.conf".source = ../iso/calamares/modules/users.conf;
    "calamares/modules/finished.conf".source = ../iso/calamares/modules/finished.conf;
    "calamares/modules/shellprocess-sideral.conf".source = ../iso/calamares/modules/shellprocess-sideral.conf;
    "sideral/iso/pre-install.sh" = {
      source = ../iso/pre-install.sh;
      mode = "0755";
    };
    "sideral/flake".source = self;
  };

  users.users.liveuser = {
    isNormalUser = true;
    description = "sideral live installer";
    extraGroups = ["wheel" "networkmanager" "video"];
    initialHashedPassword = "";
    shell = pkgs.bash;
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  services.xserver = {
    enable = true;
    desktopManager.runXdgAutostartIfNone = true;
  };

  services.displayManager = {
    autoLogin = {
      enable = true;
      user = "liveuser";
    };
    sddm = {
      enable = true;
      settings.Autologin = {
        Relogin = false;
        Session = "calamares-sideral.desktop";
        User = "liveuser";
      };
    };
  };

  services.xserver.windowManager.session = lib.singleton {
    name = "calamares-sideral";
    start = ''
      ${pkgs.sudo}/bin/sudo -E ${pkgs.calamares-nixos}/bin/calamares &
      waitPID=$!
    '';
  };
}
