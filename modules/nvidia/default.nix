{
  config,
  lib,
  pkgs,
  ...
}: {
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    powerManagement.enable = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      libvdpau-va-gl
      nvidia-vaapi-driver
    ];
  };

  environment.systemPackages = with pkgs; [
    libva-utils
    vulkan-tools
  ];

  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"
    "rd.driver.blacklist=nouveau"
    "modprobe.blacklist=nouveau"
  ];
  boot.blacklistedKernelModules = ["nouveau"];

  boot.extraModprobeConfig = builtins.readFile ./src/modprobe.d/sideral-nvidia.conf;

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct";
    MOZ_DISABLE_RDD_SANDBOX = "1";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };

  environment.etc = {
    "nvidia/nvidia-application-profiles-rc.d/50-niri.json".source =
      ./src/nvidia-app-profiles/50-niri.json;

    "xdg/niri/config.d/sideral-nvidia.kdl".source =
      lib.mkForce ./src/niri.config.d/sideral-nvidia.kdl;

    "environment.d/90-sideral-niri-nvidia.conf".source =
      ./src/environment.d/90-sideral-niri-nvidia.conf;
  };
}
