{
  description = "silverfox user home configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    silverfox = {
      url = "path:/usr/share/silverfox";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nix-flatpak,
      silverfox,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      homeConfigurations."__USER__" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          "${nix-flatpak}/modules/home-manager.nix"
          silverfox.homeManagerModules.syspkgs
          (
            { ... }:
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

              programs.mise = {
                enable = true;

                globalConfig = {
                  settings = {
                    trusted_config_paths = [ "/" ];
                    auto_install = true;
                    not_found_auto_install = true;
                    status = {
                      missing_tools = "always";
                    };
                  };

                  tools = {
                    node = "lts";
                    bun = "latest";
                    pnpm = "latest";
                    python = "latest";
                    uv = "latest";
                    go = "latest";
                    rust = "stable";
                    zig = "latest";
                  };
                };
              };

              services.flatpak = {
                enable = true;
                remotes = [
                  {
                    name = "flathub";
                    location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
                  }
                ];
                packages = [
                  {
                    appId = "app.zen_browser.zen";
                    origin = "flathub";
                  }
                  {
                    appId = "com.github.tchx84.Flatseal";
                    origin = "flathub";
                  }
                  {
                    appId = "com.mattjakeman.ExtensionManager";
                    origin = "flathub";
                  }
                  {
                    appId = "io.podman_desktop.PodmanDesktop";
                    origin = "flathub";
                  }
                  {
                    appId = "net.nokyan.Resources";
                    origin = "flathub";
                  }
                  {
                    appId = "it.mijorus.smile";
                    origin = "flathub";
                  }
                  {
                    appId = "org.pvermeer.WebAppHub";
                    origin = "flathub";
                  }
                  {
                    appId = "org.gnome.World.PikaBackup";
                    origin = "flathub";
                  }
                ];
              };
            }
          )
        ];
      };
    };
}
