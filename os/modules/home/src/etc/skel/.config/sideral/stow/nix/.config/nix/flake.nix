# sideral starter flake — declarative user packages via nix + nh.
# Edit this file, then run `fox home sync` to apply changes.
#
# nh replaces home-manager switch and nix-collect-garbage:
#   `nh home switch -c $(whoami)`  — build + activate
#   `nh clean`                     — garbage collection
#
# $NH_FLAKE is set in bashrc/zshrc so nh resolves ~/.config/nix
# automatically.
{
  description = "sideral user home configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }: let
    user = builtins.getEnv "USER";
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
  in {
    homeConfigurations."${user}" = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ({ pkgs, ... }: {
          home = {
            username = "${user}";
            homeDirectory = "/home/${user}";
            stateVersion = "24.11";

            packages = with pkgs; [
              # nh manages its own version — stays here so `nh clean`
              # doesn't remove it as an orphaned profile entry.
              nh

              # ── Uncomment what you need ─────────────────────────
              # bat           # file viewer with syntax highlighting
              # eza           # modern ls replacement (icons, git)
              # ripgrep       # fast recursive grep
              # fd            # fast file find
              # jq            # JSON processor
              # yq            # YAML/JSON/XML/Toml processor
              # htop          # interactive process viewer
              # btop          # modern resource monitor (TUI)
              # lazygit       # git TUI
              # delta         # git diff viewer (used by git config)
              # tealdeer      # fast tldr client (community-man pages)
              # du-dust       # `dust` — intuitive `du` replacement
              # procs         # modern `ps` replacement
              # sd            # intuitive `sed` replacement
            ];
          };

          # ── Mise (runtime manager) — uncomment to manage via nix ──
          # WARNING: If you already have mise installed via the RPM
          # layered in the image, use the nix version OR the RPM one,
          # not both. They will conflict on PATH.
          # programs.mise.enable = true;
          # programs.mise.globalConfig = ".config/mise/config.toml";

          # ── Flatpaks — uncomment to manage flatpaks via nix ─────
          # WARNING: The image ships a curated flatpak set via
          # sideral-flatpaks. Enabling this will manage flatpaks
          # declaratively via home-manager instead.
          # services.flatpak.enable = true;
          # services.flatpak.packages = [
          #   { appId = "org.mozilla.firefox"; origin = "flathub"; }
          # ];

          programs.home-manager.enable = true;
        })
      ];
    };
  };
}
