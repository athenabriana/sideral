{
  description = "sideral — niri compositor + Noctalia shell on NixOS, 1:1 port of the Fedora atomic flavor.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    home-manager,
    nix-flatpak,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    nixosConfigurations = {
      sideral = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [./hosts/sideral.nix];
        specialArgs = {inherit inputs self;};
      };

      sideral-nvidia = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [./hosts/sideral-nvidia.nix];
        specialArgs = {inherit inputs self;};
      };

      sideral-iso = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [./hosts/sideral-iso.nix];
        specialArgs = {inherit inputs self;};
      };
    };

    packages.${system} = {
      noctalia-shell = pkgs.callPackage ./pkgs/noctalia-shell {};
      noctalia-qs = pkgs.callPackage ./pkgs/noctalia-qs {};
      sideral-iso = self.nixosConfigurations.sideral-iso.config.system.build.isoImage;
      default = self.packages.${system}.sideral-iso;
    };

    formatter.${system} = pkgs.alejandra;
  };
}
