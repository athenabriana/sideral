{
  description = "silverfox system packages — home-manager baseline (syspkgs)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    {
      homeManagerModules.syspkgs =
        { pkgs, ... }:
        {
          home.packages = [
            pkgs.nh
            pkgs.nixd
            pkgs.nil
            pkgs.flavours
          ];
        };
    };
}
