{ config, ... }:

let
  tailnetHost = "nixos.taile9f484.ts.net";
  tailnetUrl = "https://${tailnetHost}";
  tailscale = "${config.services.tailscale.package}/bin/tailscale";
in
{
  services.n8n = {
    enable = true;
    environment = {
      N8N_LISTEN_ADDRESS = "127.0.0.1";
      N8N_HOST = tailnetHost;
      N8N_PROTOCOL = "https";
      N8N_EDITOR_BASE_URL = tailnetUrl;
      N8N_WEBHOOK_URL = "${tailnetUrl}/";
      N8N_PROXY_HOPS = 1;
      N8N_SECURE_COOKIE = true;
    };
  };

  systemd.services.n8n-tailscale-serve = {
    description = "Expose n8n to the tailnet with Tailscale Serve";
    after = [
      "n8n.service"
      "tailscaled.service"
    ];
    requires = [
      "n8n.service"
      "tailscaled.service"
    ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${tailscale} serve --bg --yes --https=443 http://127.0.0.1:5678";
      ExecStop = "${tailscale} serve --https=443 off";
    };
  };
}
