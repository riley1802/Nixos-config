{ lib, ... }:
let
  localOnly = {
    server.bindaddress = "127.0.0.1";
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
      settings = localOnly;
    };
    sonarr = mediaGroup // {
      enable = true;
      openFirewall = false;
      settings = localOnly;
    };
    radarr = mediaGroup // {
      enable = true;
      openFirewall = false;
      settings = localOnly;
    };
    lidarr = mediaGroup // {
      enable = true;
      openFirewall = false;
      settings = localOnly;
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
}
