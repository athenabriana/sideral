{
  config,
  lib,
  pkgs,
  ...
}: let
  src = ./src;
in {
  home.stateVersion = "25.11";

  xdg.configFile = {
    "niri/config.kdl".source = "${src}/config/niri/config.kdl";
    "niri/noctalia.kdl".source = "${src}/config/niri/noctalia.kdl";
    "matugen/config.toml".source = "${src}/config/matugen/config.toml";
    "matugen/templates/ghostty".source = "${src}/config/matugen/templates/ghostty";
    "matugen/templates/helix.toml".source = "${src}/config/matugen/templates/helix.toml";
    "mise/config.toml".source = "${src}/config/mise/config.toml";
    "ghostty/config".source = "${src}/config/ghostty/config";
    "noctalia/settings.json".source = "${src}/config/noctalia/settings.json";
  };

  home.file.".local/share/nushell/vendor/autoload/sideral-cli-init.nu".source =
    "${src}/local/share/nushell/vendor/autoload/sideral-cli-init.nu";

  programs = {
    bash = {
      enable = true;
      bashrcExtra = builtins.readFile "${src}/bashrc";
    };

    zsh = {
      enable = true;
      initContent = builtins.readFile "${src}/zshrc";
      syntaxHighlighting.enable = true;
      autosuggestion.enable = true;
    };

    nushell = {
      enable = true;
      envFile.source = "${src}/config/nushell/env.nu";
      configFile.source = "${src}/config/nushell/config.nu";
    };

    # Per-tool shell integration is handled manually inside the bash/zsh/nu
    # rcs (with `command -v` guards + custom flags like atuin's
    # --disable-up-arrow). Disabling HM's auto-integration prevents
    # double-evaluation of the init blocks.
    starship = {
      enable = true;
      enableBashIntegration = false;
      enableZshIntegration = false;
      enableNushellIntegration = false;
    };
    atuin = {
      enable = true;
      enableBashIntegration = false;
      enableZshIntegration = false;
      enableNushellIntegration = false;
    };
    zoxide = {
      enable = true;
      enableBashIntegration = false;
      enableZshIntegration = false;
      enableNushellIntegration = false;
    };
    fzf = {
      enable = true;
      enableBashIntegration = false;
      enableZshIntegration = false;
    };

    bat.enable = true;
    eza.enable = true;
    git.enable = true;
    gh.enable = true;
    helix.enable = true;
    home-manager.enable = true;
  };

  home.activation.installNuPrompts = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ -x "${src}/install-nu-prompts.sh" ]; then
      $DRY_RUN_CMD ${pkgs.bash}/bin/bash ${src}/install-nu-prompts.sh || true
    fi
  '';
}
