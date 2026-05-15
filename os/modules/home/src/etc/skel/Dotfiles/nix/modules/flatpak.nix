# flatpak/default.nix — flatpak apps managed declaratively via nix-flatpak.
#
# Adds Flathub remote and the silverfox default app set. Edit this list
# and run `fox sync` to install/remove apps.

{ ... }:
{
  services.flatpak = {
    enable = true;
    remotes = [
      {
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }
    ];
    packages = [
      {
        appId = "app.zen_browser.zen";
        origin = "flathub";
      }
      {
        appId = "com.github.tchx84.Flatseal";
        origin = "flathub";
      }
      {
        appId = "com.mattjakeman.ExtensionManager";
        origin = "flathub";
      }
      {
        appId = "io.podman_desktop.PodmanDesktop";
        origin = "flathub";
      }
      {
        appId = "net.nokyan.Resources";
        origin = "flathub";
      }
      {
        appId = "it.mijorus.smile";
        origin = "flathub";
      }
      {
        appId = "org.pvermeer.WebAppHub";
        origin = "flathub";
      }
      {
        appId = "org.gnome.World.PikaBackup";
        origin = "flathub";
      }
    ];
  };
}
