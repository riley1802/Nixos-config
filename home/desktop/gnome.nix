{ pkgs, ... }:

let
  enabledExtensions = with pkgs.gnomeExtensions; [
    appindicator
    dash-to-dock
    blur-my-shell
    vitals
    gsconnect
    just-perfection
    user-themes
    caffeine
  ];
in
{
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      clock-show-weekday = true;
      cursor-theme = "Bibata-Modern-Ice";
      cursor-size = 24;
      show-battery-percentage = true;
    };

    "org/gnome/shell" = {
      # Use nixpkgs-provided UUIDs so extension updates do not require hard-coded strings.
      enabled-extensions = map (extension: extension.extensionUuid) enabledExtensions;
    };

    "org/gnome/shell/extensions/dash-to-dock" = {
      dock-position = "BOTTOM";
      extend-height = false;
      dock-fixed = true;
      dash-max-icon-size = 48;
      click-action = "minimize-or-previews";
      show-trash = false;
      show-mounts = false;
    };
  };
}
