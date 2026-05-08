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
    yazi
    television
    zellij
    lazygit
    rclone
    fuse3
    chromium
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
}
