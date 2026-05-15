# mise/default.nix — mise runtime version manager.
#
# Global defaults under [tools] are installed on `nh home switch` and
# resolved unless overridden by an idiomatic file (.nvmrc, devEngines
# in package.json, .python-version, rust-toolchain.toml, etc.) in a
# project's tree.
#
# idiomatic_version_file_enable_tools lists tools that read those
# project-level files; only listed tools auto-detect. ["*"] is NOT a
# valid wildcard — names are required.

{ pkgs, ... }:
{
  home.packages = [ pkgs.mise ];

  home.file.".config/mise/config.toml".source = ./mise.toml;

  home.activation.syncMise =
    let
      miseBin = "${pkgs.mise}/bin/mise";
      misePkgBinDir = "${pkgs.mise}/bin";
    in
    ''
      export PATH="${misePkgBinDir}:$PATH"
      $DRY_RUN_CMD ${miseBin} prune --verbose --yes
      $DRY_RUN_CMD ${miseBin} install --verbose --yes
    '';
}
