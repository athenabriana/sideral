{
  pkgs,
  lib,
  config,
  ...
}: let
  sideralWallpaper = pkgs.runCommand "sideral-wallpapers" {} ''
    mkdir -p $out/share/wallpapers
    cp -r ${./src/usr/share/wallpapers/sideral} $out/share/wallpapers/sideral
  '';
in {
  programs.niri.enable = true;

  # greetd + regreet — Wayland-native login manager. regreet is a
  # GTK4 greeter wrapped in cage (kiosk Wayland compositor). Reads
  # session entries from /usr/share/wayland-sessions/.
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.cage}/bin/cage -s -m last -- ${pkgs.greetd.regreet}/bin/regreet";
      user = "greeter";
    };
  };

  services.kanata = {
    enable = true;
    keyboards.sideral = {
      configFile = ./src/etc/kanata/sideral.kbd;
      devices = [];
    };
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
  };

  services.fprintd.enable = true;

  services.fwupd.enable = true;

  programs.dconf.enable = true;

  environment.systemPackages = with pkgs; [
    kanshi
    wdisplays
    ddcutil
    brightnessctl
    fastfetch
    wlsunset
    grim
    slurp
    wl-clipboard
    cliphist
    matugen
    ghostty
    noctalia-shell
    noctalia-qs
    sideralWallpaper
  ];

  environment.pathsToLink = ["/share/wallpapers" "/share/wayland-sessions"];

  environment.sessionVariables = {
    XMODIFIERS = "@im=fcitx";
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    SDL_IM_MODULE = "fcitx";
  };

  environment.etc = {
    "kanata/sideral.kbd".source = ./src/etc/kanata/sideral.kbd;
    "xdg/niri/config.kdl".source = ./src/etc/xdg/niri/config.kdl;
    "xdg/niri/config.d/sideral-nvidia.kdl".source = ./src/etc/xdg/niri/config.d/sideral-nvidia.kdl;
    "xdg/matugen/config.toml".source = ./src/etc/xdg/matugen/config.toml;
    "xdg/matugen/templates/ghostty".source = ./src/etc/xdg/matugen/templates/ghostty;
    "xdg/matugen/templates/helix.toml".source = ./src/etc/xdg/matugen/templates/helix.toml;
    "xdg/wayland-sessions/niri.desktop".source = ./src/usr/share/wayland-sessions/niri.desktop;
  };
}
