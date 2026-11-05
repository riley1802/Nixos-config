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
  # GTX 1660 SUPER. The other unit stays installed and stopped.
  # `gtx1660 nemotron` or `gtx1660 breeze` flips the running process.
  # This line is what boots, and what the tailnet publishes.
  my.hardware.gtx1660 = "nemotron";

  # nixctl: modules (one line per module that is on; nixctl enable/disable edit these lines)
  my.apps.openlogi.enable = true;
  my.desktop.chrome.enable = true;
  my.desktop.kdeconnect.enable = true;
  my.desktop.plasma.enable = true;
  my.hardware.disks.enable = true;
  my.hardware.nvidia.enable = true;
  my.network.dnsproxy.enable = true;
  my.network.firewall.enable = true;
  my.network.networkmanager.enable = true;
  my.network.openssh.enable = true;
  my.network.pia.enable = true;
  my.network.tailscale.enable = true;
  my.services.arr.bazarr.enable = true;
  my.services.arr.cleanuparr.enable = true;
  my.services.arr.lidarr.enable = true;
  my.services.arr.media.enable = true;
  my.services.arr.prowlarr.enable = true;
  my.services.arr.qbittorrent.enable = true;
  my.services.arr.radarr.enable = true;
  my.services.arr.seerr.enable = true;
  my.services.arr.sonarr.enable = true;
  my.services.breeze-tts.enable = true;
  my.services.d1.enable = true;
  my.services.data-platform.enable = true;
  my.services.docker.enable = true;
  my.services.embeddinggemma.enable = true;
  my.services.homarr.enable = true;
  my.services.homelable.enable = true;
  my.services.immich.enable = true;
  my.services.jellyfin.enable = true;
  my.services.kokoro.enable = true;
  my.services.llama.enable = true;
  my.services.n8n.enable = true;
  my.services.nemotron.enable = true;
  my.services.ntfy.enable = true;
  my.services.open-terminal.enable = true;
  my.services.open-webui.enable = true;
  my.services.searxng.enable = true;
  my.services.uptime-kuma.enable = true;

  # Set once at install. Never change it.
  system.stateVersion = "26.05";
}
