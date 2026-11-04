# Global firewall ranges stay empty so each service opens its own interface.
{ config, lib, ... }:
let
  cfg = config.my.network.firewall;
in
{
  options.my.network.firewall.enable = lib.mkEnableOption "empty global firewall ranges";

  config = lib.mkIf cfg.enable {
    # KDE Connect, Jellyfin, and the tailnet services each name an interface.
    # Force the global ranges empty so a module default cannot open them
    # on every interface. mkForce wins over those defaults.
    networking.firewall.allowedTCPPortRanges = lib.mkForce [ ];
    networking.firewall.allowedUDPPortRanges = lib.mkForce [ ];
  };
}
