{ pkgs, ... }:
{
  # Open WebUI 0.11.1 from the nixos-26.05 module. Chat front end for the
  # llama.cpp servers in llama-cpp.nix. Those stay on 8081 and 8082, and
  # their own pages stay available.
  #
  # The module default port is 8080, which is qBittorrent. This listens on
  # loopback. Chrome's HSTS list upgrades http://*.ts.net to HTTPS on the
  # same port, so Tailscale Serve terminates TLS on 8088 and proxies here.
  # https://github.com/NixOS/nixpkgs/blob/6713828a351efa628b025a1adf7f43cbf8597513/nixos/modules/services/misc/open-webui.nix
  # https://docs.openwebui.com/reference/env-configuration
  services.open-webui = {
    enable = true;
    host = "127.0.0.1";
    port = 8088;
    openFirewall = false;
    # Assigning this set replaces the module default, so the telemetry
    # flags are repeated here.
    environment = {
      SCARF_NO_ANALYTICS = "True";
      DO_NOT_TRACK = "True";
      ANONYMIZED_TELEMETRY = "False";
      # Nothing is listening for Ollama. Both models are OpenAI-compatible
      # llama-server endpoints. Each server has one slot, so title, follow-up,
      # and tag generation would queue in front of the reply.
      ENABLE_OLLAMA_API = "False";
      ENABLE_OPENAI_API = "True";
      OPENAI_API_BASE_URLS = "http://127.0.0.1:8081/v1;http://127.0.0.1:8082/v1";
      # llama-server has no --api-key and ignores this header. The placeholder
      # is only here because Open WebUI wants one key per URL.
      OPENAI_API_KEYS = "local;local";
      WEBUI_URL = "https://nixos.taile9f484.ts.net:8088";
      ENABLE_TITLE_GENERATION = "False";
      ENABLE_FOLLOW_UP_GENERATION = "False";
      ENABLE_TAGS_GENERATION = "False";
      # Connection URLs and the task switches above stay in this file.
      # Chats and accounts still live in the service state directory.
      ENABLE_PERSISTENT_CONFIG = "False";
    };
  };

  systemd.services.open-webui-tailscale-serve = {
    description = "Tailscale HTTPS for Open WebUI";
    after = [
      "tailscaled.service"
      "network-online.target"
      "open-webui.service"
    ];
    wants = [ "tailscaled.service" "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = 120;
      ExecStart = pkgs.writeShellScript "open-webui-tailscale-serve" ''
        set -euo pipefail
        ${pkgs.tailscale}/bin/tailscale serve --bg --yes --https=8088 http://127.0.0.1:8088
      '';
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    8088 # Open WebUI
  ];
}
