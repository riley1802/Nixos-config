{ pkgs, ... }:
{
  # n8n 2.34.6 from the nixos-26.05 module. The editor listens on loopback.
  # Chrome's HSTS list upgrades http://*.ts.net to HTTPS on the same port,
  # so Tailscale Serve terminates TLS on 5678 and proxies here. 5678 is
  # free: 8080 is qBittorrent, 8081 and 8082 are llama.cpp, and 8088 is
  # Open WebUI.
  #
  # The owner account, workflows, SQLite database, and the generated
  # encryption key live in /var/lib/n8n. That directory is not in git.
  #
  # LFM3-1.7B is the OpenAI-compatible server on 127.0.0.1:8082. n8n
  # cannot take that URL from an environment variable, and a credential
  # import needs the owner account created on first login. After that
  # login, add one OpenAI credential:
  #   API key: local
  #   Base URL: http://127.0.0.1:8082/v1
  #   Organization ID: empty
  # On an OpenAI or OpenAI Chat Model node, the model id is lfm3-1.7b.
  # Leave "Use Responses API" off. llama-server has no --api-key and
  # ignores this header. Omni on 8081 is not connected. The 1.7B server
  # has one slot and is shared with Open WebUI, so a workflow waits if a
  # chat is already generating.
  # https://github.com/NixOS/nixpkgs/blob/6713828a351efa628b025a1adf7f43cbf8597513/nixos/modules/services/misc/n8n.nix
  # https://docs.n8n.io/hosting/configuration/environment-variables/
  services.n8n = {
    enable = true;
    openFirewall = false;
    environment = {
      N8N_LISTEN_ADDRESS = "127.0.0.1";
      N8N_PORT = 5678;
      N8N_PROTOCOL = "https";
      N8N_HOST = "nixos.taile9f484.ts.net";
      # 2.34.6 still accepts WEBHOOK_URL and warns to use this name instead.
      N8N_WEBHOOK_URL = "https://nixos.taile9f484.ts.net:5678/";
      N8N_EDITOR_BASE_URL = "https://nixos.taile9f484.ts.net:5678/";
      # Tailscale Serve sets X-Forwarded-Proto. One hop is that proxy.
      N8N_PROXY_HOPS = 1;
      # The Secure cookie default blocks a login at http://127.0.0.1:5678.
      # The process is not reachable off loopback. The tailnet URL is HTTPS.
      N8N_SECURE_COOKIE = false;
    };
  };

  # A workflow notifies the phone with an HTTP Request node: POST the
  # message body to http://127.0.0.1:2586/n8n and send the publisher token
  # from /run/agenix/ntfy-passwords as Authorization: Bearer. The token and
  # the topic are set up in ntfy.nix. n8n has no notification of its own
  # until a workflow posts one.
  # https://docs.ntfy.sh/publish/
  # https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.httprequest/

  # Start after the model when it is present. Do not require it, so n8n
  # still comes up if the GGUF is missing.
  systemd.services.n8n = {
    after = [ "llama-cpp-1.7b.service" ];
    wants = [ "llama-cpp-1.7b.service" ];
  };

  systemd.services.n8n-tailscale-serve = {
    description = "Tailscale HTTPS for n8n";
    after = [
      "tailscaled.service"
      "network-online.target"
      "n8n.service"
    ];
    wants = [ "tailscaled.service" "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = 120;
      ExecStart = pkgs.writeShellScript "n8n-tailscale-serve" ''
        set -euo pipefail
        ${pkgs.tailscale}/bin/tailscale serve --bg --yes --https=5678 http://127.0.0.1:5678
      '';
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    5678 # n8n
  ];
}
