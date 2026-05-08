{...}: {
  services.flatpak = {
    enable = true;

    remotes = [
      {
        name = "flathub";
        location = "https://flathub.org/repo/flathub.flatpakrepo";
      }
    ];

    packages = [
      "app.zen_browser.zen"
      "io.github.kolunmi.Bazaar"
      "com.github.tchx84.Flatseal"
      "com.mattjakeman.ExtensionManager"
      "io.podman_desktop.PodmanDesktop"
      "com.ranfdev.DistroShelf"
      "net.nokyan.Resources"
      "it.mijorus.smile"
      "org.pvermeer.WebAppHub"
      "org.gnome.World.PikaBackup"
      "re.sonny.Junction"
    ];

    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };
  };
}
