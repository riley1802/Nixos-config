{ config, pkgs, ... }:
{
  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";

  hardware.nvidia-container-toolkit.enable = true;

  virtualisation.oci-containers.containers.portainer = {
    image = "portainer/portainer-ce:2.39.4";
    ports = [ "127.0.0.1:9443:9443" ];
    volumes = [
      "/var/run/docker.sock:/var/run/docker.sock"
      "portainer_data:/data"
    ];
    cmd = [ "--base-url=/portainer" ];
    # Do not pass --restart here: oci-containers already uses --rm; systemd owns restarts.
  };

  # No tailscale0 firewall rule here on purpose — Portainer is only reached via nginx (port 80).
}
