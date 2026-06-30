{ ... }:

{
  imports = [
    ./hardware-configuration.nix

    ../../modules/core/locale.nix
    ../../modules/core/networking-pi.nix
    ../../modules/core/openssh-pi.nix
    ../../modules/core/agenix.nix
    ../../modules/core/system.nix

    ../../modules/hardware/raspberry-pi-4.nix

    ../../modules/desktop/audio.nix
    ../../modules/desktop/xfce.nix

    ../../modules/programs/firefox.nix
    ../../modules/programs/packages.nix

    ../../modules/services/homepage.nix
    ../../modules/services/tailscale.nix
    ../../modules/services/uptime-kuma.nix

    ../../modules/users/rileyt-pi.nix
  ];
}
