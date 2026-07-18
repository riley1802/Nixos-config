{ config, ... }:
{
  services.homepage-dashboard = {
    enable = true;
    listenPort = 8083;
    openFirewall = false;
    # Accept Tailscale MagicDNS via nginx, plus local access on the bind port.
    allowedHosts = "nixos.taile9f484.ts.net,localhost:8083,127.0.0.1:8083";

    services = [
      {
        "AI / Local Models" = [
          { "llama.cpp" = { href = "http://127.0.0.1:8080"; description = "Local LLM inference"; }; }
          { "whisper.cpp" = { href = "http://127.0.0.1:8081"; description = "Speech-to-text"; }; }
          { "Piper TTS" = { href = "http://127.0.0.1:8082"; description = "Text-to-speech"; }; }
          { "SearXNG" = { href = "http://127.0.0.1:8888"; description = "Metasearch"; }; }
        ];
      }
      {
        "Automation & Infra" = [
          { "n8n" = { href = "/n8n/"; description = "Workflow automation"; }; }
          { "Portainer" = { href = "/portainer/"; description = "Container management"; }; }
        ];
      }
      {
        "Monitoring" = [
          { "Uptime Kuma" = { href = "http://127.0.0.1:3001"; description = "Status dashboard (not proxied — own port)"; }; }
          { "ntfy" = { href = "http://nixos.taile9f484.ts.net:8090"; description = "Push notifications (not proxied — own port)"; }; }
        ];
      }
    ];
  };

  # No tailscale0 firewall rule here on purpose — Homepage itself is only reached via nginx (port 80),
  # which proxies "/" to it.
}
