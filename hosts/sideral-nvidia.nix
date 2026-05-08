{...}: {
  imports = [
    ./common.nix
    ../modules/nvidia
  ];

  networking.hostName = "sideral";
  system.nixos.variant_id = "nvidia";
}
