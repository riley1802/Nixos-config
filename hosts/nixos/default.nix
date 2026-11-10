# Control panel for the computer "nixos": which modules are on, plus
# settings that belong to this machine only.
{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./packages.nix
  ];

  networking.hostName = "nixos";
  my.user = "rileyt";
  my.tailnetHost = "nixos.taile9f484.ts.net";
  my.lanInterface = "enp132s0";

  # nixctl: modules (one line per module that is on; nixctl enable/disable edit these lines)
  my.apps.rustdesk.enable = true;
  my.dev.shell.enable = true;
  my.apps.openlogi.enable = true; # OpenLogi: Logitech MX Master 4 support (https://openlogi.org)
  my.desktop.chrome.enable = true; # Chrome/Chromium DNS policy tweaks for this machine
  my.desktop.kdeconnect.enable = true; # KDE Connect: link phone and desktop (SMS, notifications, etc.)
  my.desktop.plasma.enable = true; # KDE Plasma desktop session and related defaults
  my.hardware.disks.enable = true; # Mount or wire up “vault” disk and game drive
  my.hardware.nvidia.enable = true; # Proprietary NVIDIA graphics driver stack
  my.network.dnsproxy.enable = true; # Encrypted DNS forwarder (e.g. DoH/DoT upstream)
  my.network.firewall.enable = true; # Keep global port ranges empty; each service opens its own interface
  my.network.networkmanager.enable = true; # NetworkManager for wired/wifi/VPN UI and profiles
  my.network.openssh.enable = true; # SSH server, restricted for Tailscale access
  my.network.pia.enable = true; # Private Internet Access VPN via WireGuard with split tunneling
  my.network.tailscale.enable = true; # Tailscale mesh VPN / remote access
  my.services.arr.bazarr.enable = true; # Bazarr: subtitle downloads for Sonarr/Radarr libraries
  my.services.arr.cleanuparr.enable = true; # Cleanuparr: clean up media the *arr stack no longer tracks
  my.services.arr.jellyfin.enable = true; # Jellyfin: home media server (stream your library)
  my.services.arr.lidarr.enable = true; # Lidarr: music collection automation (“Sonarr for music”)
  my.services.arr.media.enable = true; # Shared media library paths (storage layout for *arr)
  my.services.arr.prowlarr.enable = true; # Prowlarr: indexer manager for the *arr apps
  my.services.arr.qbittorrent.enable = true; # qBittorrent: torrent client used by *arr
  my.services.arr.radarr.enable = true; # Radarr: movie library automation
  my.services.arr.seerr.enable = true; # Seerr (Jellyseerr): request UI for Jellyfin + *arr
  my.services.arr.sonarr.enable = true; # Sonarr: TV library automation
  my.services.docker.enable = true; # Docker Engine for containers
  my.services.immich.enable = true; # Immich: self-hosted photo/video backup and gallery
  my.services.ntfy.enable = true; # ntfy: simple HTTP-based push notifications
  my.services.uptime-kuma.enable = true; # Uptime Kuma: uptime monitoring and status pages

  # Set once at install. Never change it.
  system.stateVersion = "26.05";
}
