{ config, ... }:
{
  services.ntfy-sh = {
    enable = true;
    settings = {
      # Direct Tailscale access — ntfy 2.23 rejects paths in base-url (no nginx subpath).
      listen-http = "0.0.0.0:8090";
      base-url = "http://nixos.taile9f484.ts.net:8090";
      behind-proxy = false;
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 8090 ];
}
