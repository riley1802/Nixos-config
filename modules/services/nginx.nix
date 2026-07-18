{ config, ... }:
{
  services.nginx = {
    enable = true;

    virtualHosts."nixos-dashboard" = {
      default = true; # catches any Host header — no hostname assumption baked in
      listen = [
        {
          addr = "0.0.0.0";
          port = 80;
        }
      ];

      locations."/" = {
        proxyPass = "http://127.0.0.1:8083";
      };

      locations."/n8n/" = {
        proxyPass = "http://127.0.0.1:5678/n8n/";
        proxyWebsockets = true;
      };

      locations."/portainer/" = {
        proxyPass = "https://127.0.0.1:9443/portainer/";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_ssl_verify off;
        '';
      };
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 80 ];
}
