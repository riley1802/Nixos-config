{ config, ... }:
{
  services.uptime-kuma = {
    enable = true;
    settings = {
      HOST = "0.0.0.0";
      PORT = "3001";
    };
  };

  # Uptime Kuma does NOT support running behind a subpath (confirmed upstream) —
  # it stays directly reachable over Tailscale on its own port, not proxied.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 3001 ];
}
