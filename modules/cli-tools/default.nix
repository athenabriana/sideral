{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    chezmoi
    mise
    atuin
    fzf
    bat
    eza
    ripgrep
    zoxide
    gh
    git
    git-lfs
    gcc
    gnumake
    cmake
    helix
    rclone
    fuse3
    chromium
    nushell
    carapace
    starship
    vscode
    just
  ];

  environment.etc."xdg/applications/chromium-browser.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Chromium (hidden)
    Exec=${pkgs.chromium}/bin/chromium %U
    NoDisplay=true
    Categories=Network;WebBrowser;
  '';

  environment.etc = {
    "nushell/plugins/nu_plugin_query".source = "${pkgs.nushellPlugins.query}/bin/nu_plugin_query";
    "nushell/plugins/nu_plugin_formats".source = "${pkgs.nushellPlugins.formats}/bin/nu_plugin_formats";
    "nushell/plugins/nu_plugin_gstat".source = "${pkgs.nushellPlugins.gstat}/bin/nu_plugin_gstat";
  };
}
