# Sonarr TV library. Web page on port 8989.
{ config, lib, ... }:
let
  cfg = config.my.services.arr.sonarr;
in
{
  options.my.services.arr.sonarr.enable = lib.mkEnableOption "Sonarr";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.services.arr.media.enable;
        message = "services/arr/sonarr needs services/arr/media (nixctl enable services/arr/media)";
      }
    ];

    # Servarr accepts one bind address. "*" is what lets loopback (this
    # computer) and tailscale0 (the phone) reach the same process. The
    # firewall is what keeps every other interface closed.
    # https://wiki.servarr.com/sonarr/settings#bind-address
    services.sonarr = {
      enable = true;
      openFirewall = false;
      group = "media";
      settings.server.bindaddress = "*";
    };

    # Sonarr's config must stay private even though new media files are group-writable.
    systemd.services.sonarr.preStart = ''
      if [[ -d /var/lib/sonarr/.config/NzbDrone ]]; then
        chmod 700 /var/lib/sonarr/.config /var/lib/sonarr/.config/NzbDrone
        chmod 600 /var/lib/sonarr/.config/NzbDrone/config.xml /var/lib/sonarr/.config/NzbDrone/sonarr.db 2>/dev/null || true
      fi
    '';
    # The module sets its own umask. 0002 lets the media group write new files.
    systemd.services.sonarr.serviceConfig.UMask = lib.mkForce "0002";

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      8989 # Sonarr
    ];
  };
}
