# modules/mise.nix — mise runtime version manager.
#
# Global defaults under [tools] are installed on `nh home switch` and
# resolved unless overridden by an idiomatic file (.nvmrc, devEngines
# in package.json, .python-version, rust-toolchain.toml, etc.) in a
# project's tree.
#
# idiomatic_version_file_enable_tools lists tools that read those
# project-level files; only listed tools auto-detect. ["*"] is NOT a
# valid wildcard — names are required.

{ ... }:
{
  programs.mise = {
    enable = true;

    globalConfig = {
      settings = {
        trusted_config_paths = [ "/" ];
        auto_install = true;
        not_found_auto_install = true;
        idiomatic_version_file_enable_tools = [
          "bun"
          "go"
          "node"
          "pnpm"
          "python"
          "rust"
          "terraform"
        ];
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
      };
    };
  };
}
