{ ... }:

{
  # GNOME still uses services.xserver for keyboard layout and XWayland plumbing.
  services.xserver.enable = true;

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.desktopManager.gnome.enable = true;

  programs.dconf.enable = true;
}
