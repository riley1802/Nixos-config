{ config, ... }:
# Declarative services.tailscale.serve uses set-config, which cannot express
# HTTPS TLS termination (nixpkgs#530174 / tailscale#18381). Drive Serve via CLI.
{
  systemd.services.tailscale-serve-apps = {
    description = "Tailscale Serve HTTPS front ends (Homepage, n8n, Portainer, World Monitor)";
    after = [
      "tailscaled.service"
      "homepage-dashboard.service"
      "n8n.service"
      "docker-portainer.service"
    ];
    # World Monitor is not in `after`: first `docker compose build` can take a long
    # time; Serve only needs the proxy registered (backend may come up later).
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ config.services.tailscale.package ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "${config.services.tailscale.package}/bin/tailscale serve reset";
    };
    script = ''
      set -euo pipefail
      # Wait until tailscaled accepts serve config.
      for _ in $(seq 1 30); do
        if tailscale status --json >/dev/null 2>&1; then
          break
        fi
        sleep 1
      done

      tailscale serve reset || true
      tailscale serve --bg --yes --https=443 http://127.0.0.1:8083
      tailscale serve --bg --yes --https=5678 http://127.0.0.1:5678
      tailscale serve --bg --yes --https=9443 https+insecure://127.0.0.1:9443
      tailscale serve --bg --yes --https=3000 http://127.0.0.1:3000
    '';
  };
}
