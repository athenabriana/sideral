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
    # devenv para ambientes de desenvolvimento declarativos por projeto.
    # Descomente para usar `devenv shell` no lugar de distrobox/toolbox:
    #   devenv.url = "github:cachix/devenv";
  };

  outputs = { self, nixpkgs, home-manager, ... }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    # builtins.getEnv retorna "" em pure eval. Com --impure, retorna
    # o usuário real. O fallback "changeme" é usado quando --impure
    # não é passado (se você executar `nh` manualmente sem --impure,
    # troque "changeme" pelo seu username).
    user = let u = builtins.getEnv "USER"; in if u != "" then u else "changeme";
  in {
    homeConfigurations."${user}" = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      extraSpecialArgs = { inherit user; };
      modules = [
        ({ user, ... }: {
          home = {
            username = "${user}";
            homeDirectory = "/home/${user}";
            stateVersion = "24.11";

            packages = with pkgs; [
              # nh gerencia a própria versão. `fox sync` instala
              # nh automaticamente se não estiver presente.
              nh

              # ── Descomente o que precisar ─────────────────────────
              # bat           # file viewer com syntax highlight
              # eza           # ls moderno (icons, git status)
              # ripgrep       # grep recursivo rápido
              # fd            # find rápido
              # jq            # processador JSON
              # yq            # YAML/JSON/XML/Toml
              # btop          # monitor de recursos TUI
              # lazygit       # git TUI
              # delta         # diff viewer para git
              # tealdeer      # tldr client (man pages comunitários)
              # du-dust       # dust — du intuitivo
              # procs         # ps moderno
              # sd            # sed intuitivo
            ];
          };

          # ── Mise (runtime manager) ───────────────────────────────
          # programs.mise.enable = true;

          # ── Flatpaks via nix ─────────────────────────────────────
          # services.flatpak.enable = true;

          programs.home-manager.enable = true;
        })
      ];
    };
  };
}
