# Uptime Kuma: uptime monitoring and status pages. Web UI on port 3001.
# Uses the stock NixOS module (services.uptime-kuma). Data is under
# /var/lib/uptime-kuma. If you used an older custom module that stored the DB
# elsewhere, stop the service and copy kuma.db into that directory before apply.
{ config, lib, ... }:
let
  cfg = config.my.services.uptime-kuma;
in
{
  options.my.services.uptime-kuma.enable = lib.mkEnableOption "Uptime Kuma";

  config = lib.mkIf cfg.enable {
    # https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/services/monitoring/uptime-kuma.nix
    services.uptime-kuma.enable = true;

    # Process listens on 127.0.0.1 (module default). Open 3001 on the tailnet
    # interface only; Tailscale Serve proxies HTTPS from the MagicDNS name.
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      3001 # Uptime Kuma
    ];
  };
}
