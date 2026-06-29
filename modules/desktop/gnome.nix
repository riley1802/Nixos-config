{ pkgs, ... }:

{
  # GNOME still uses services.xserver for keyboard layout and XWayland plumbing.
  # GDM and GNOME themselves use the newer non-xserver option paths below.
  services.xserver.enable = true;

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.displayManager.gdm = {
    enable = true;
  };

  services.desktopManager.gnome.enable = true;

  programs.dconf.enable = true;

  environment.systemPackages = with pkgs; [
    gnome-tweaks
    gnome-extension-manager

    gnomeExtensions.appindicator
    gnomeExtensions.dash-to-dock
    gnomeExtensions.blur-my-shell
    gnomeExtensions.vitals
    gnomeExtensions.gsconnect
    gnomeExtensions.just-perfection
    gnomeExtensions.user-themes
    gnomeExtensions.caffeine
  ];

  environment.gnome.excludePackages = with pkgs; [
    gnome-maps
    gnome-contacts
    gnome-weather
    gnome-tour
  ];
}
