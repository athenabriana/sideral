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
          ./modules/home.nix
          ./modules/mise.nix
          ./modules/flatpak.nix
        ];
      };
    };
}
