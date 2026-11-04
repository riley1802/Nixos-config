# Homelable network diagram. Web page on port 3000.
{ config, lib, ... }:
let
  cfg = config.my.services.homelable;
  # Outside Docker's default pools and Homarr's 172.30.88.0/29.
  # .1 is the gateway. .2–.4 are the three containers.
  bridgeSubnet = "172.30.89.0/29";
  bridgeGateway = "172.30.89.1";
  bridgeName = "br-homelable";
  backendIp = "172.30.89.2";
  frontendIp = "172.30.89.3";
  mcpIp = "172.30.89.4";
in
{
  options.my.services.homelable.enable = lib.mkEnableOption "Homelable network diagram";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.services.docker.enable;
        message = "services/homelable needs services/docker (nixctl enable services/docker)";
      }
    ];

    # Homelable is not in nixpkgs. These are the official images, pinned to
    # 3.6.0 (VERSION on main, 2026-11-04), not :latest. The linux/amd64
    # manifests are on ghcr.io. The canvas database stays in
    # /var/lib/homelable and is not committed.
    # https://github.com/Pouzor/homelable
    # https://github.com/Pouzor/homelable/blob/main/docker-compose.prebuilt.yml
    #
    # The UI is the frontend nginx on 127.0.0.1:3000. Tailscale Serve
    # publishes that port. The backend's 8000 stays on the bridge, so it is
    # not a host listener. The image binds 0.0.0.0:8000; host networking
    # would put that on the LAN. This bridge can scan 192.168.50.0/24 by IP.
    # It cannot see MAC addresses, because ARP stops at the Docker gateway.
    # https://github.com/Pouzor/homelable/blob/main/INSTALLATION.md
    #
    # nginx in the frontend image proxies /api to BACKEND_UPSTREAM. The
    # container name is homelable-backend, not the compose name backend.
    # https://github.com/Pouzor/homelable/blob/main/docker/nginx.conf
    #
    # SECRET_KEY, the admin password hash, and the MCP keys are an age
    # secret, loaded with --env-file. Docker does not expand $ in that
    # file, so the bcrypt hash is stored as-is. The password itself is a
    # second secret. Read it with:
    #   pkexec cat /run/agenix/homelable-login
    age.secrets.homelable-env = {
      file = ../../secrets/homelable-env.age;
      mode = "0400";
      owner = "root";
      group = "root";
    };
    age.secrets.homelable-login = {
      file = ../../secrets/homelable-login.age;
      mode = "0400";
      owner = "root";
      group = "root";
    };

    systemd.tmpfiles.settings.homelable."/var/lib/homelable"."d" = {
      mode = "0700";
      user = "root";
      group = "root";
    };

    virtualisation.oci-containers = {
      backend = "docker";
      containers = {
        homelable-backend = {
          image = "ghcr.io/pouzor/homelable-backend:3.6.0";
          volumes = [ "/var/lib/homelable:/app/data" ];
          environment = {
            SQLITE_PATH = "/app/data/homelab.db";
            AUTH_MODE = "local";
            # This computer's home LAN. enp132s0 is 192.168.50.101/24.
            SCANNER_RANGES = ''["192.168.50.0/24"]'';
            STATUS_CHECKER_INTERVAL = "60";
            CORS_ORIGINS = ''["http://127.0.0.1:3000","https://${config.my.tailnetHost}:3000"]'';
          };
          environmentFiles = [ config.age.secrets.homelable-env.path ];
          networks = [ "homelable" ];
          # Ping and nmap need raw sockets. The published compose file adds
          # the same capability.
          capabilities.NET_RAW = true;
          extraOptions = [ "--ip=${backendIp}" ];
        };

        homelable-frontend = {
          image = "ghcr.io/pouzor/homelable-frontend:3.6.0";
          ports = [ "127.0.0.1:3000:80" ];
          environment.BACKEND_UPSTREAM = "homelable-backend:8000";
          dependsOn = [ "homelable-backend" ];
          networks = [ "homelable" ];
          extraOptions = [ "--ip=${frontendIp}" ];
        };

        # MCP stays on loopback. It can change the canvas, so it is not on
        # the tailnet. The API key is MCP_API_KEY in the env secret.
        homelable-mcp = {
          image = "ghcr.io/pouzor/homelable-mcp:3.6.0";
          ports = [ "127.0.0.1:8001:8001" ];
          environment.BACKEND_URL = "http://homelable-backend:8000";
          environmentFiles = [ config.age.secrets.homelable-env.path ];
          dependsOn = [ "homelable-backend" ];
          networks = [ "homelable" ];
          extraOptions = [ "--ip=${mcpIp}" ];
        };
      };
    };

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      3000 # Homelable
    ];

    # An existing network with a different subnet is left in place and this
    # unit fails, instead of silently pointing --ip at the wrong range.
    systemd.services = {
      docker-homelable-network = {
        description = "Docker network for Homelable";
        after = [ "docker.service" ];
        requires = [ "docker.service" ];
        requiredBy = [
          "docker-homelable-backend.service"
          "docker-homelable-frontend.service"
          "docker-homelable-mcp.service"
        ];
        before = [
          "docker-homelable-backend.service"
          "docker-homelable-frontend.service"
          "docker-homelable-mcp.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          set -euo pipefail
          docker=${config.virtualisation.docker.package}/bin/docker
          if "''$docker" network inspect homelable >/dev/null 2>&1; then
            bridge=''$("''$docker" network inspect homelable --format '{{ index .Options "com.docker.network.bridge.name" }}')
            subnet=''$("''$docker" network inspect homelable --format '{{ range .IPAM.Config }}{{ .Subnet }}{{ end }}')
            if [[ "''$bridge" != ${bridgeName} || "''$subnet" != ${bridgeSubnet} ]]; then
              echo "docker network homelable exists but is not ${bridgeName} on ${bridgeSubnet}" >&2
              exit 1
            fi
          else
            "''$docker" network create \
              --driver bridge \
              --subnet ${bridgeSubnet} \
              --gateway ${bridgeGateway} \
              --opt com.docker.network.bridge.name=${bridgeName} \
              homelable
          fi
        '';
      };
      docker-homelable-backend = {
        after = [ "docker-homelable-network.service" ];
        wants = [ "docker-homelable-network.service" ];
      };
      docker-homelable-frontend = {
        after = [ "docker-homelable-network.service" ];
        wants = [ "docker-homelable-network.service" ];
      };
      docker-homelable-mcp = {
        after = [ "docker-homelable-network.service" ];
        wants = [ "docker-homelable-network.service" ];
      };
    };
  };
}
