{ config, ... }:
{
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
    file = ./secrets/homarr-encryption-key.age;
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
        BASE_URL = "https://nixos.taile9f484.ts.net:7575";
      };
      environmentFiles = [ config.age.secrets.homarr-encryption-key.path ];
      # Not the default bridge. --ip is only honored on a user-defined network.
      networks = [ "homarr" ];
      extraOptions = [
        "--add-host=host.docker.internal:host-gateway"
        "--ip=172.30.88.2"
      ];
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    7575 # Homarr
  ];

  # 172.30.88.0/29 is outside Docker's default pools. .1 is the gateway,
  # which host.docker.internal uses. .2 is this container. The bridge name
  # is stable so the firewall can name it. An existing network with a
  # different subnet is left in place and this unit fails, instead of
  # silently pointing --ip at the wrong range.
  systemd.services.docker-homarr-network = {
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
        if [[ "''$bridge" != br-homarr || "''$subnet" != 172.30.88.0/29 ]]; then
          echo "docker network homarr exists but is not br-homarr on 172.30.88.0/29" >&2
          exit 1
        fi
      else
        "''$docker" network create \
          --driver bridge \
          --subnet 172.30.88.0/29 \
          --gateway 172.30.88.1 \
          --opt com.docker.network.bridge.name=br-homarr \
          homarr
      fi
    '';
  };

  # Sonarr, Radarr, Lidarr, and Bazarr still listen on every interface:
  # each of those programs takes one bind address, and loopback, tailscale0,
  # and this bridge all have to reach them. The firewall is the limit.
  # Only Homarr's address is accepted, and only for the four integrations.
  # qBittorrent, Jellyfin, Seerr, Uptime Kuma, and Prowlarr are not
  # accepted here. Prowlarr's service may use only lo, pia, and tailscale0.
  # iptables stores the interface name, so the rule can be installed
  # before br-homarr exists. Homepage and Tailscale Serve use 127.0.0.1,
  # which never arrives on this bridge.
  networking.firewall.extraCommands = ''
    iptables -w -A nixos-fw -i br-homarr -s 172.30.88.2/32 -p tcp -m multiport --dports 6767,7878,8686,8989 -j nixos-fw-accept
  '';
}
