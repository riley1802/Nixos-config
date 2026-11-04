# Bazarr subtitles. Web page on port 6767.
{ config, lib, ... }:
let
  cfg = config.my.services.arr.bazarr;
in
{
  options.my.services.arr.bazarr.enable = lib.mkEnableOption "Bazarr";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.services.arr.media.enable;
        message = "services/arr/bazarr needs services/arr/media (nixctl enable services/arr/media)";
      }
    ];

    services.bazarr = {
      enable = true;
      openFirewall = false;
      group = "media";
    };

    systemd.services.bazarr.serviceConfig.UMask = "0002";

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      6767 # Bazarr
    ];
  };
}
