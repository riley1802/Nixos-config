# Lidarr music library. Web page on port 8686.
{ config, lib, ... }:
let
  cfg = config.my.services.arr.lidarr;
in
{
  options.my.services.arr.lidarr.enable = lib.mkEnableOption "Lidarr";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.services.arr.media.enable;
        message = "services/arr/lidarr needs services/arr/media (nixctl enable services/arr/media)";
      }
    ];

    # Servarr accepts one bind address. "*" is what lets loopback (this
    # computer), tailscale0 (the phone), and the Homarr bridge reach the
    # same process. The firewall is what keeps every other interface closed.
    # https://wiki.servarr.com/sonarr/settings#bind-address
    services.lidarr = {
      enable = true;
      openFirewall = false;
      group = "media";
      settings.server.bindaddress = "*";
    };

    systemd.services.lidarr.serviceConfig.UMask = "0002";
    # The package is a pinned tarball. An in-app update would not replace
    # the store path, so Servarr must treat updates as external.
    # https://wiki.servarr.com/lidarr/settings#updates
    systemd.services.lidarr.environment.LIDARR__UPDATE__MECHANISM = "external";

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      8686 # Lidarr
    ];
  };
}
