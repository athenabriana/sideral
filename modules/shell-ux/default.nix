{
  pkgs,
  lib,
  ...
}: let
  njust = pkgs.writeShellScriptBin "njust" ''
    exec ${pkgs.just}/bin/just --justfile /etc/sideral/sideral.just "$@"
  '';

  # `edit` — open or attach a per-project zellij IDE session named after
  # the cwd. The `code` layout (shipped at /etc/xdg/zellij/layouts/code.kdl)
  # tiles helix + yazi + lazygit. Switch project → different session;
  # reboot → reattach to whatever's still alive.
  edit = pkgs.writeShellScriptBin "edit" ''
    name="code-$(${pkgs.coreutils}/bin/basename "$PWD")"
    exec ${pkgs.zellij}/bin/zellij attach -c "$name" --layout code "$@"
  '';

  # zjstatus — WASM status-bar plugin for zellij (dj95/zjstatus).
  # Not yet packaged in nixpkgs; fetch the prebuilt wasm directly.
  zjstatus = pkgs.fetchurl {
    url = "https://github.com/dj95/zjstatus/releases/download/v0.23.0/zjstatus.wasm";
    hash = "sha256-4AaQEiNSQjnbYYAh5MxdF/gtxL+uVDKJW6QfA/E4Yf8=";
  };
in {
  environment.systemPackages = [njust edit pkgs.just];

  programs.zsh.enable = true;

  users.motd = builtins.readFile ./src/etc/user-motd;

  environment.etc = {
    "mise/config.toml".source = ./src/etc/mise/config.toml;
    "profile.d/sideral-shell-migrate.sh".source = ./src/etc/profile.d/sideral-shell-migrate.sh;
    "sideral/sideral.just".source = ./src/etc/sideral/sideral.just;
    "xdg/zellij/config.kdl".source = ./src/etc/xdg/zellij/config.kdl;
    "xdg/zellij/layouts/code.kdl".source = ./src/etc/xdg/zellij/layouts/code.kdl;
    "xdg/zellij/plugins/zjstatus.wasm".source = zjstatus;
    "xdg/television/cable/files.toml".source = ./src/etc/xdg/television/cable/files.toml;
    "xdg/television/cable/git-branches.toml".source = ./src/etc/xdg/television/cable/git-branches.toml;
  };

  systemd.user.services.rclone-gdrive = {
    description = "rclone Google Drive auto-mount at ~/gdrive";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["default.target"];
    serviceConfig = {
      Type = "notify";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/gdrive";
      ExecStart = "${pkgs.rclone}/bin/rclone mount gdrive: %h/gdrive --vfs-cache-mode writes";
      ExecStop = "${pkgs.fuse3}/bin/fusermount -u %h/gdrive";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
