# Radarr movie library. Web page on port 7878.
{ config, lib, ... }:
let
  cfg = config.my.services.arr.radarr;
in
{
  options.my.services.arr.radarr.enable = lib.mkEnableOption "Radarr";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.services.arr.media.enable;
        message = "services/arr/radarr needs services/arr/media (nixctl enable services/arr/media)";
      }
    ];

    # Servarr accepts one bind address. "*" is what lets loopback (this
    # computer) and tailscale0 (the phone) reach the same process. The
    # firewall is what keeps every other interface closed.
    # https://wiki.servarr.com/sonarr/settings#bind-address
    services.radarr = {
      enable = true;
      openFirewall = false;
      group = "media";
      settings.server.bindaddress = "*";
    };

    # The module sets its own umask. 0002 lets the media group write new files.
    systemd.services.radarr.serviceConfig.UMask = lib.mkForce "0002";

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      7878 # Radarr
    ];
  };
}
