# athens-os — starter home.nix
#
# Single source of truth for all user-level config. Ships via /etc/skel on every
# fresh user, then home-manager materializes it on first login via
# athens-home-manager-setup.service (see system_files/usr/lib/systemd/user/).
#
# Edit & apply from the repo:    just home-edit && just home-apply
# Edit & apply from your home:   $EDITOR ~/.config/home-manager/home.nix && home-manager switch
# Roll back one generation:      home-manager generations && home-manager switch <gen-path>
{ config, pkgs, lib, ... }:

let
  # nix-software-center is not in upstream nixpkgs, so we fetch directly from
  # GitHub. builtins.fetchGit is pinned by rev (deterministic, no sha256 needed)
  # and works in channels-only mode (no flakes — D-02). Bumping: update `rev`.
  nix-software-center-src = builtins.fetchGit {
    url     = "https://github.com/snowfallorg/nix-software-center.git";
    rev     = "181c1c61eab79130879257550dba0b36bd6bb8c9";  # 2026-02-15
    ref     = "refs/heads/main";
    shallow = true;
  };
  nix-software-center = import nix-software-center-src { inherit pkgs lib; };
in
{
  # ── Identity — resolved at switch time, so one file works for any user ──
  home.username      = builtins.getEnv "USER";
  home.homeDirectory = builtins.getEnv "HOME";

  # Pinned to the channel release baked into athens-os.
  # Never bump without reading home-manager release notes.
  home.stateVersion = "24.11";

  # Allow proprietary builds (vscode, vscode-extensions, some fonts).
  # Flip to allowUnfreePredicate if you ever want a narrower gate.
  nixpkgs.config.allowUnfree = true;

  # ── User-profile packages (ad-hoc CLI tooling + runtime manager + GUI) ──
  home.packages = [
    pkgs.mise
    nix-software-center
    # Native-build toolchain — used by pip/npm/cargo C-ext builds and by
    # mise when compiling Python/Ruby from source. Keeping them in nix
    # (not RPM) keeps the compiler lineage consistent with nix's glibc.
    pkgs.gcc
    pkgs.gnumake
    pkgs.cmake
  ];

  # ── Bash: the login / interactive shell ─────────────────────────────────
  programs.bash = {
    enable = true;
    initExtra = ''
      # mise activation (mise comes from home.packages above).
      if command -v mise >/dev/null 2>&1; then
        eval "$(mise activate bash)"
      fi
    '';
  };

  # ── Prompt ──────────────────────────────────────────────────────────────
  programs.starship.enable = true;

  # ── Shell history (Ctrl+R fuzzy search) ─────────────────────────────────
  programs.atuin.enable = true;

  # ── Git (name / email intentionally unset — user fills in) ──────────────
  programs.git.enable = true;

  # ── Editor: VS Code (Microsoft proprietary build) ───────────────────────
  # Declarative install + preloaded extensions for remote/devcontainer flow.
  # mutableExtensionsDir defaults to true, so users can still install more
  # via the VS Code UI (e.g., ms-azuretools.vscode-containers once it lands
  # in nixpkgs — for now grab it from the marketplace).
  programs.vscode = {
    enable = true;
    extensions = with pkgs.vscode-extensions; [
      ms-vscode-remote.remote-ssh
      ms-vscode-remote.remote-containers
    ];
  };

  # ── CLI quality-of-life ─────────────────────────────────────────────────
  programs.zoxide.enable    = true;   # smart `cd` with frecency (z / zi)
  programs.fzf.enable       = true;   # Ctrl-R / Ctrl-T / Alt-C pickers
  programs.bat.enable       = true;   # cat with syntax highlighting
  programs.eza = {                    # modern ls
    enable = true;
    icons  = true;
    git    = true;
  };
  programs.ripgrep.enable   = true;   # fast grep
  programs.nix-index.enable = true;   # which-package-provides on non-NixOS
  programs.gh.enable        = true;   # GitHub CLI (`gh auth login` on first use)

  # ── mise toolchain, inlined as a managed dotfile ────────────────────────
  # Per-project .mise.toml files override this.
  home.file.".config/mise/config.toml".text = ''
    [tools]

    # JavaScript / TypeScript
    node = "lts"
    bun  = "latest"
    pnpm = "latest"

    # Python
    python = "latest"
    uv     = "latest"

    # JVM
    java   = "temurin-lts"
    kotlin = "latest"
    gradle = "latest"

    # Systems
    go   = "latest"
    rust = "stable"
    zig  = "latest"

    # Mobile
    android-sdk = "13.0"

    [settings]
    experimental                        = true
    trusted_config_paths                = ["/"]
    not_found_auto_install              = true
    idiomatic_version_file_enable_tools = ["node", "python", "java", "ruby", "go", "rust"]
    jobs                                = 8
    http_timeout                        = "60s"

    [settings.status]
    missing_tools = "if_other_versions_installed"
    show_env      = false
    show_tools    = false
  '';
}
