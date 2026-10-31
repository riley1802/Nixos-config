{ config, ... }:
{
  # Homarr is not in nixpkgs. This is the official image, pinned to the
  # current GitHub release (v2.10.1, 2026-10-30), not :latest. The linux/amd64
  # manifest is on ghcr.io. The first visit creates the admin account, the
  # same way n8n does. Tiles and integrations stay in /var/lib/homarr and
  # are not committed.
  # https://github.com/homarr-labs/homarr/releases/tag/v2.10.1
  # https://homarr.dev/docs/getting-started/installation/docker/
  #
  # The published port is the bundled nginx on 7575. Homarr's own 3000 and
  # 3001 stay on the container network, so they do not collide with Uptime
  # Kuma. Bridge networking is the docker run default. Host networking would
  # put 3001 on the host. 127.0.0.1 inside the container is the container, so
  # host.docker.internal is the host gateway for later widget calls. The
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
      extraOptions = [
        "--add-host=host.docker.internal:host-gateway"
      ];
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    7575 # Homarr
  ];

  # The container uses bridge networking, so a widget call to
  # host.docker.internal arrives on docker0. These services listen on every
  # address, and this is the interface that would otherwise drop that
  # traffic. The home network stays closed. Loopback-only services are not
  # listed, because docker0 cannot reach 127.0.0.1. Prowlarr is not listed
  # either: that service may use only lo, pia, and tailscale0.
  networking.firewall.interfaces.docker0.allowedTCPPorts = [
    3001 # Uptime Kuma
    5055 # Seerr
    6767 # Bazarr
    7878 # Radarr
    8080 # qBittorrent
    8096 # Jellyfin
    8686 # Lidarr
    8989 # Sonarr
  ];
}
