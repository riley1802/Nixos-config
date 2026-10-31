{ lib, ... }:
let
  # Servarr accepts one bind address. "*" is what lets loopback (Homepage
  # and this computer), tailscale0 (the phone), and the Homarr bridge in
  # homarr.nix reach the same process. The firewall is what keeps every
  # other interface closed. Prowlarr is further limited to lo, pia, and
  # tailscale0 by pia-wireguard.nix.
  # https://wiki.servarr.com/sonarr/settings#bind-address
  tailnet = {
    server.bindaddress = "*";
  };
  mediaGroup = {
    group = "media";
  };
in
{
  # Jellyseerr's NixOS module was renamed to Seerr. The old name still works.
  services = {
    prowlarr = {
      enable = true;
      openFirewall = false;
      settings = tailnet;
    };
    sonarr = mediaGroup // {
      enable = true;
      openFirewall = false;
      settings = tailnet;
    };
    radarr = mediaGroup // {
      enable = true;
      openFirewall = false;
      settings = tailnet;
    };
    lidarr = mediaGroup // {
      enable = true;
      openFirewall = false;
      settings = tailnet;
    };
    bazarr = mediaGroup // {
      enable = true;
      openFirewall = false;
    };
    jellyfin = mediaGroup // {
      enable = true;
      openFirewall = false;
    };
    seerr = {
      enable = true;
      openFirewall = false;
    };
  };

  # Sonarr's config must stay private even though new media files are group-writable.
  systemd.services.sonarr.preStart = ''
    if [[ -d /var/lib/sonarr/.config/NzbDrone ]]; then
      chmod 700 /var/lib/sonarr/.config /var/lib/sonarr/.config/NzbDrone
      chmod 600 /var/lib/sonarr/.config/NzbDrone/config.xml /var/lib/sonarr/.config/NzbDrone/sonarr.db 2>/dev/null || true
    fi
  '';
  systemd.services.sonarr.serviceConfig.UMask = lib.mkForce "0002";
  systemd.services.radarr.serviceConfig.UMask = lib.mkForce "0002";
  systemd.services.lidarr.serviceConfig.UMask = "0002";
  systemd.services.bazarr.serviceConfig.UMask = "0002";
  systemd.services.jellyfin.serviceConfig.UMask = lib.mkForce "0002";
  # The module's TimeoutSec=15 also covers shutdown. The library is on
  # the USB disk. Killing Jellyfin at 15 seconds leaves its database
  # half written, and the next boot opens a broken library.
  systemd.services.jellyfin.serviceConfig.TimeoutStopSec = "2min";

  # Web UIs only. The torrent port stays on the VPN interface.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    5055 # Seerr
    6767 # Bazarr
    7878 # Radarr
    8686 # Lidarr
    8989 # Sonarr
    9696 # Prowlarr
  ];
}
