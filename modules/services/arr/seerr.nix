# Seerr requests. Web page on port 5055.
{ config, lib, ... }:
let
  cfg = config.my.services.arr.seerr;
in
{
  options.my.services.arr.seerr.enable = lib.mkEnableOption "Seerr";

  config = lib.mkIf cfg.enable {
    # Jellyseerr's NixOS module was renamed to Seerr. The old name still works.
    services.seerr = {
      enable = true;
      openFirewall = false;
    };

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      5055 # Seerr
    ];
  };
}
