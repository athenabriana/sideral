{
  config,
  lib,
  pkgs,
  ...
}: {
  home.stateVersion = "25.11";

  xdg.configFile = {
    "niri/config.kdl".source = ./src/config/niri/config.kdl;
    "niri/noctalia.kdl".source = ./src/config/niri/noctalia.kdl;
    "matugen/config.toml".source = ./src/config/matugen/config.toml;
    "matugen/templates/ghostty".source = ./src/config/matugen/templates/ghostty;
    "matugen/templates/helix.toml".source = ./src/config/matugen/templates/helix.toml;
    "mise/config.toml".source = ./src/config/mise/config.toml;
    "ghostty/config".source = ./src/config/ghostty/config;
    "noctalia/settings.json".source = ./src/config/noctalia/settings.json;
  };

  programs = {
    bash = {
      enable = true;
      bashrcExtra = builtins.readFile ./src/bashrc;
    };

    zsh = {
      enable = true;
      initContent = builtins.readFile ./src/zshrc;
      syntaxHighlighting.enable = true;
      autosuggestion.enable = true;
    };

    # Per-tool shell integration is handled manually inside the bash/zsh
    # rcs (with `command -v` guards + custom flags like atuin's
    # --disable-up-arrow). Disabling HM's auto-integration prevents
    # double-evaluation of the init blocks.
    starship = {
      enable = true;
      enableBashIntegration = false;
      enableZshIntegration = false;
    };
    atuin = {
      enable = true;
      enableBashIntegration = false;
      enableZshIntegration = false;
    };
    zoxide = {
      enable = true;
      enableBashIntegration = false;
      enableZshIntegration = false;
    };
    yazi = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
    };

    bat.enable = true;
    eza.enable = true;
    git.enable = true;
    gh.enable = true;

    helix = {
      enable = true;
      settings = {
        theme = "onedark";
        editor = {
          bufferline = "always";
          cursorline = true;
          color-modes = true;
          true-color = true;
          gutters = ["diagnostics" "spacer" "line-numbers" "spacer" "diff"];
          indent-guides = {
            render = true;
            character = "│";
          };
          lsp = {
            display-messages = true;
            display-inlay-hints = true;
            auto-signature-help = true;
          };
          cursor-shape = {
            insert = "bar";
            select = "underline";
            normal = "block";
          };
          statusline = {
            left = ["mode" "spinner"];
            center = ["file-name"];
            right = ["diagnostics" "selections" "register" "position" "file-encoding"];
          };
        };
      };
    };

    home-manager.enable = true;
  };
}
