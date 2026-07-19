{ config, ... }:
{
  services.ntfy-sh = {
    enable = true;
    settings = {
      # Direct Tailscale access — ntfy 2.23 rejects paths in base-url (no nginx subpath).
      listen-http = "0.0.0.0:8090";
      base-url = "http://${config.host.tailnetName}:8090";
      behind-proxy = false;
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 8090 ];
}
