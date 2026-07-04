{ pkgs, ... }:

{
  dconf.settings."org/gnome/shell" = {
    # Use nixpkgs-provided UUIDs so extension updates do not require hard-coded strings.
    enabled-extensions = map (extension: extension.extensionUuid) (with pkgs.gnomeExtensions; [
      appindicator
      dash-to-dock
      blur-my-shell
      vitals
      gsconnect
      just-perfection
      user-themes
      caffeine
    ]);
  };
}
