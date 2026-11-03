# Prowlarr indexer manager. Web page on port 9696.
{ config, lib, ... }:
let
  cfg = config.my.services.arr.prowlarr;
in
{
  options.my.services.arr.prowlarr.enable = lib.mkEnableOption "Prowlarr";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.network.pia.enable;
        message = "services/arr/prowlarr needs network/pia (nixctl enable network/pia)";
      }
    ];

    # Servarr accepts one bind address. "*" is what lets loopback (this
    # computer), tailscale0 (the phone), and the Homarr bridge in
    # homarr.nix reach the same process. The firewall is what keeps every
    # other interface closed. Prowlarr is further limited to lo, pia, and
    # tailscale0 by network/pia.nix.
    # https://wiki.servarr.com/sonarr/settings#bind-address
    services.prowlarr = {
      enable = true;
      openFirewall = false;
      settings.server.bindaddress = "*";
    };

    # Web UI only. Lookups still leave through the VPN.
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      9696 # Prowlarr
    ];
  };
}
