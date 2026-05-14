# sideral starter flake — declarative user packages via nix + nh.
#
# Edit this file, then run `fox sync` to apply changes.
#
# nh replaces home-manager switch:
#   `fox sync`  →  stow + `nh home switch --impure -c <user>`
#
# $NH_FLAKE é definido em bashrc/zshrc apontando para ~/.config/nix.
#
# NOTA sobre pureza da avaliação:
#   O nix avalia flakes em modo PURE por padrão, onde `builtins.getEnv`
#   retorna vazio. O `--impure` permite acesso a variáveis de ambiente.
#   Os comandos fox (sync, diff) passam `--impure` automaticamente.
{
  description = "sideral user home configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    # devenv para ambientes de desenvolvimento declarativos por projeto.
    # Descomente para usar `devenv shell` no lugar de distrobox/toolbox:
    #   devenv.url = "github:cachix/devenv";
  };

  outputs = { self, nixpkgs, home-manager, nix-flatpak, ... }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    # O attr name precisa ser estatico (nh avalia sem --impure pra listar).
    # Troque "changeme" pelo seu username:
    #   nh home switch --impure -c <username>
    user = "changeme";
  in {
    homeConfigurations."${user}" = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        "${nix-flatpak}/modules/home-manager.nix"
        ({ ... }: {
          home = {
            username = "${user}";
            homeDirectory = "/home/${user}";
            stateVersion = "24.11";

            packages = [
              # nh já vem pré-instalado na imagem (/usr/libexec/nh).
              # Descomente os pacotes que quiser instalar:

              # pkgs.bat            # file viewer com syntax highlight
              # pkgs.eza            # ls moderno (icons, git status)
              # pkgs.ripgrep        # grep recursivo rápido
              # pkgs.fd             # find rápido
              # pkgs.jq             # processador JSON
              # pkgs.yq             # YAML/JSON/XML/Toml
              # pkgs.btop           # monitor de recursos TUI
              # pkgs.lazygit        # git TUI
              # pkgs.delta          # diff viewer para git
              # pkgs.tealdeer       # tldr client
              # pkgs.du-dust        # dust — du intuitivo
              # pkgs.procs          # ps moderno
              # pkgs.sd             # sed intuitivo
            ];
          };

          # ── Mise (runtime manager) ───────────────────────────────
          # programs.mise.enable = true;

          # ── Flatpaks gerenciados pelo nix ────────────────────────
          services.flatpak = {
            enable = true;
            remotes = [{
              name = "flathub";
              location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
            }];
            packages = [
              { appId = "app.zen_browser.zen"; origin = "flathub"; }
              { appId = "io.github.kolunmi.Bazaar"; origin = "flathub"; }
              { appId = "com.github.tchx84.Flatseal"; origin = "flathub"; }
              { appId = "com.mattjakeman.ExtensionManager"; origin = "flathub"; }
              { appId = "io.podman_desktop.PodmanDesktop"; origin = "flathub"; }
              { appId = "com.ranfdev.DistroShelf"; origin = "flathub"; }
              { appId = "net.nokyan.Resources"; origin = "flathub"; }
              { appId = "it.mijorus.smile"; origin = "flathub"; }
              { appId = "org.pvermeer.WebAppHub"; origin = "flathub"; }
              { appId = "org.gnome.World.PikaBackup"; origin = "flathub"; }
              { appId = "re.sonny.Junction"; origin = "flathub"; }
            ];
          };

        })
      ];
    };
  };
}
