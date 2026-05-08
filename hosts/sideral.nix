{...}: {
  imports = [./common.nix];

  networking.hostName = "sideral";
  system.nixos.variant_id = "open-source";
}
