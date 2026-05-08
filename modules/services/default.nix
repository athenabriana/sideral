{pkgs, ...}: {
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  environment.systemPackages = with pkgs; [
    podman-compose
    distrobox
  ];

  services.flatpak.enable = true;

  environment.etc."distrobox/distrobox.conf".source = ./src/etc/distrobox/distrobox.conf;
}
