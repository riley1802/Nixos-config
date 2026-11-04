# Homarr service board. Web page on port 7575.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.homarr;
  # Outside Docker's default pools. .1 is the gateway (host.docker.internal).
  # .2 is this container. The bridge name is stable so the firewall can name it.
  bridgeSubnet = "172.30.88.0/29";
  bridgeGateway = "172.30.88.1";
  bridgeAddress = "172.30.88.2";
  bridgeName = "br-homarr";
  # These listen on every interface. Homarr reaches them on the gateway.
  directPorts = [
    3001 # Uptime Kuma
    5055 # Seerr
    6767 # Bazarr
    7878 # Radarr
    8080 # qBittorrent
    8096 # Jellyfin
    8686 # Lidarr
    8989 # Sonarr
    9696 # Prowlarr
  ];
  # These listen on loopback. A proxy on the gateway forwards the ping.
  # Tailscale Serve keeps using 127.0.0.1.
  proxyPorts = {
    ntfy = 2586;
    n8n = 5678;
    llama-vl = 8081;
    llama-1_7b = 8082;
    open-webui = 8088;
  };
  # iptables multiport accepts at most 15 ports.
  homarrPorts = directPorts ++ lib.attrValues proxyPorts;
in
{
  options.my.services.homarr = {
    enable = lib.mkEnableOption "Homarr";
    bridgeSubnet = lib.mkOption {
      type = lib.types.str;
      default = bridgeSubnet;
      readOnly = true;
      description = "Docker bridge subnet for Homarr. Prowlarr keeps replies to this subnet off the VPN.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.services.docker.enable;
        message = "services/homarr needs services/docker (nixctl enable services/docker)";
      }
      {
        assertion = builtins.length homarrPorts <= 15;
        message = "services/homarr firewall rule uses iptables multiport, which allows at most 15 ports";
      }
    ];

    # Homarr is not in nixpkgs. This is the official image, pinned to the
    # current GitHub release (v2.10.1, 2026-10-30), not :latest. The linux/amd64
    # manifest is on ghcr.io. The first visit creates the admin account, the
    # same way n8n does. Do that at http://127.0.0.1:7575 before an untrusted
    # device is on the tailnet. Tiles and integrations stay in /var/lib/homarr
    # and are not committed.
    # https://github.com/homarr-labs/homarr/releases/tag/v2.10.1
    # https://homarr.dev/docs/getting-started/installation/docker/
    #
    # The published port is the bundled nginx on 7575. Homarr's own 3000 and
    # 3001 stay on the container network, so they do not collide with Uptime
    # Kuma. Host networking would put 3001 on the host. The container is on
    # its own bridge, not the default docker0 bridge, and it is the only
    # address on that bridge. 127.0.0.1 inside the container is the container,
    # so host.docker.internal is that bridge's gateway for widget calls. The
    # Docker socket is not mounted, and ENABLE_DOCKER=false hides that page.
    # Docker's daemon IP is already 127.0.0.1. The port mapping repeats it
    # because a published port bypasses the NixOS firewall.
    # https://homarr.dev/docs/advanced/environment-variables/
    # https://homarr.dev/docs/advanced/proxy/
    # https://docs.docker.com/reference/cli/docker/container/run/#add-host
    # https://docs.docker.com/engine/network/#published-ports
    #
    # The module default backend has been podman since stateVersion 22.05.
    # This machine's Docker daemon is the one already limited to loopback.
    #
    # BASE_URL is the canonical origin for MCP OAuth. The proxy docs require
    # an HTTPS origin when a proxy terminates TLS. The admin session cookie
    # does not read BASE_URL. It is Secure only when the request URL Next.js
    # sees is https, and the bundled nginx talks HTTP to the app, so
    # http://127.0.0.1:7575 can still create the admin account. Tailscale
    # Serve is still installed for the phone. HOMARR_TRUSTED_PROXIES stays
    # unset: inside the container the proxy's TCP peer is the bridge gateway,
    # not a fixed address, and the default is to ignore forwarded client
    # identity.
    # https://github.com/homarr-labs/homarr/blob/v2.10.1/apps/nextjs/src/app/api/auth/%5B...nextauth%5D/route.ts
    #
    # SECRET_ENCRYPTION_KEY is required and has to be the same key after the
    # container is recreated. It is an age secret, loaded with --env-file.
    # The entrypoint's *_FILE suffix would look for a file inside the
    # container; this env file is read by the Docker daemon on the host.
    age.secrets.homarr-encryption-key = {
      file = ../../secrets/homarr-encryption-key.age;
      mode = "0400";
      owner = "root";
      group = "root";
    };

    # Other local accounts should not read the board database.
    systemd.tmpfiles.settings.homarr."/var/lib/homarr"."d" = {
      mode = "0700";
      user = "root";
      group = "root";
    };

    virtualisation.oci-containers = {
      backend = "docker";
      containers.homarr = {
        image = "ghcr.io/homarr-labs/homarr:v2.10.1";
        ports = [ "127.0.0.1:7575:7575" ];
        volumes = [ "/var/lib/homarr:/appdata" ];
        environment = {
          ENABLE_DOCKER = "false";
          BASE_URL = "https://${config.my.tailnetHost}:7575";
        };
        environmentFiles = [ config.age.secrets.homarr-encryption-key.path ];
        # Not the default bridge. --ip is only honored on a user-defined network.
        networks = [ "homarr" ];
        extraOptions = [
          "--add-host=host.docker.internal:host-gateway"
          "--ip=${bridgeAddress}"
        ];
      };
    };

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      7575 # Homarr
    ];

    # Homarr pings from the container. host.docker.internal is the bridge
    # gateway, so the check arrives on br-homarr from the container address.
    # Anything under HTTP 500 counts as online, including a login redirect.
    # iptables stores the interface name, so the rule can be installed
    # before br-homarr exists. Tailscale Serve uses 127.0.0.1, which never
    # arrives on this bridge. docker0 is not opened.
    networking.firewall.extraCommands = ''
      iptables -w -A nixos-fw -i ${bridgeName} -s ${bridgeAddress}/32 -p tcp -m multiport --dports ${
        lib.concatMapStringsSep "," toString (builtins.sort builtins.lessThan homarrPorts)
      } -j nixos-fw-accept
    '';

    # An existing network with a different subnet is left in place and this
    # unit fails, instead of silently pointing --ip at the wrong range.
    # Loopback apps stay on 127.0.0.1. The ping proxies listen only on the
    # gateway and connect back to loopback, so the LAN and the tailnet do
    # not gain a second listener.
    systemd.services = lib.mkMerge [
      {
        docker-homarr-network = {
          description = "Docker network for Homarr widget calls";
          after = [ "docker.service" ];
          requires = [ "docker.service" ];
          requiredBy = [ "docker-homarr.service" ];
          before = [ "docker-homarr.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            set -euo pipefail
            docker=${config.virtualisation.docker.package}/bin/docker
            if "''$docker" network inspect homarr >/dev/null 2>&1; then
              bridge=''$("''$docker" network inspect homarr --format '{{ index .Options "com.docker.network.bridge.name" }}')
              subnet=''$("''$docker" network inspect homarr --format '{{ range .IPAM.Config }}{{ .Subnet }}{{ end }}')
              if [[ "''$bridge" != ${bridgeName} || "''$subnet" != ${bridgeSubnet} ]]; then
                echo "docker network homarr exists but is not ${bridgeName} on ${bridgeSubnet}" >&2
                exit 1
              fi
            else
              "''$docker" network create \
                --driver bridge \
                --subnet ${bridgeSubnet} \
                --gateway ${bridgeGateway} \
                --opt com.docker.network.bridge.name=${bridgeName} \
                homarr
            fi
          '';
        };
      }
      (lib.mapAttrs'
        (
          name: port:
            lib.nameValuePair "homarr-ping-${name}" {
              description = "Homarr ping proxy to ${name}";
              after = [ "docker-homarr-network.service" ];
              wants = [ "docker-homarr-network.service" ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig = {
                ExecStart = "${pkgs.socat}/bin/socat TCP4-LISTEN:${toString port},bind=${bridgeGateway},fork,reuseaddr TCP4:127.0.0.1:${toString port}";
                Restart = "on-failure";
                RestartSec = "2s";
                DynamicUser = true;
              };
            }
        )
        proxyPorts)
      # RestrictNetworkInterfaces records the index at start. pia.nix names
      # lo, pia, and tailscale0. The bridge has to exist first or this name
      # is dropped for the life of the process.
      (lib.mkIf config.my.services.arr.qbittorrent.enable {
        qbittorrent = {
          after = [ "docker-homarr-network.service" ];
          wants = [ "docker-homarr-network.service" ];
          serviceConfig.RestrictNetworkInterfaces = [ bridgeName ];
        };
      })
      (lib.mkIf config.my.services.arr.prowlarr.enable {
        prowlarr = {
          after = [ "docker-homarr-network.service" ];
          wants = [ "docker-homarr-network.service" ];
          serviceConfig.RestrictNetworkInterfaces = [ bridgeName ];
        };
      })
    ];

  };
}
