{ pkgs, ... }:

{
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
