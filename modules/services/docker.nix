# Docker, bound to loopback so published ports stay off the home network.
{ config, lib, ... }:
let
  cfg = config.my.services.docker;
in
{
  options.my.services.docker.enable = lib.mkEnableOption "Docker";

  config = lib.mkIf cfg.enable {
    # Docker's own iptables rules bypass the NixOS firewall, so a published
    # port (-p 8000:8000) would otherwise be open on the home network.
    # `-p 0.0.0.0:8000:8000` still opens one on purpose.
    virtualisation.docker = {
      enable = true;
      daemon.settings.ip = "127.0.0.1";
    };
  };
}
