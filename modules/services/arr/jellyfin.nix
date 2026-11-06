# Jellyfin media player. Web page on port 8096.
{ config, lib, ... }:
let
  cfg = config.my.services.arr.jellyfin;
in
{
  options.my.services.arr.jellyfin.enable = lib.mkEnableOption "Jellyfin";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.services.arr.media.enable;
        message = "services/arr/jellyfin needs services/arr/media (nixctl enable services/arr/media)";
      }
    ];

    services.jellyfin = {
      enable = true;
      openFirewall = false;
      group = "media";
    };

    # The module sets its own umask. 0002 lets the media group write new files.
    systemd.services.jellyfin.serviceConfig.UMask = lib.mkForce "0002";
    # The module's TimeoutSec=15 also covers shutdown. The library is on
    # the USB disk. Killing Jellyfin at 15 seconds leaves its database
    # half written, and the next boot opens a broken library.
    systemd.services.jellyfin.serviceConfig.TimeoutStopSec = "2min";

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      8096 # Jellyfin. The home LAN rule below is also intentional.
    ];
    networking.firewall.interfaces.${config.my.lanInterface}.allowedTCPPorts = [
      # Home Wi-Fi playback is intentional. Players on the LAN use
      # http://192.168.50.101:8096. Tailnet clients use tailscale0.
      # The VPN interface stays closed.
      8096
    ];
  };
}
