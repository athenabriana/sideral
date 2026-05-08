{pkgs, ...}: let
  njust = pkgs.writeShellScriptBin "njust" ''
    exec ${pkgs.just}/bin/just --justfile /etc/sideral/sideral.just "$@"
  '';
in {
  environment.systemPackages = [njust pkgs.just];

  programs.zsh.enable = true;

  users.motd = builtins.readFile ./src/etc/user-motd;

  environment.etc = {
    "mise/config.toml".source = ./src/etc/mise/config.toml;
    "profile.d/sideral-shell-migrate.sh".source = ./src/etc/profile.d/sideral-shell-migrate.sh;
    "profile.d/sideral-nushell-plugins.sh".source = ./src/etc/profile.d/sideral-nushell-plugins.sh;
    "sideral/sideral.just".source = ./src/etc/sideral/sideral.just;
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
