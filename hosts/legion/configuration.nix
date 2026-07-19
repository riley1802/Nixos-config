{ lib, ... }:

{
  imports = [
    ./hardware-configuration.nix

    ../../modules/core/boot.nix
    ../../modules/core/locale.nix
    ../../modules/core/hostname.nix
    ../../modules/core/networkmanager.nix
    ../../modules/core/openssh.nix
    ../../modules/core/agenix.nix
    ../../modules/core/nix.nix
    ../../modules/core/nixpkgs.nix
    ../../modules/core/state-version.nix
    ../../modules/core/polkit-pkexec.nix

    ../../modules/hardware/graphics.nix
    ../../modules/hardware/nvidia-prime.nix

    ../../modules/desktop/gdm.nix
    ../../modules/desktop/gnome.nix
    ../../modules/desktop/gnome-extensions.nix
    ../../modules/desktop/audio.nix

    ../../modules/programs/firefox.nix
    ../../modules/programs/steam.nix
    ../../modules/programs/games-dirs.nix
    ../../modules/programs/packages.nix

    ../../modules/services/llama-cpp.nix
    ../../modules/services/whisper-cpp.nix
    ../../modules/services/piper.nix
    ../../modules/services/searxng.nix
    ../../modules/services/tailscale.nix
    ../../modules/services/postgresql.nix
    ../../modules/services/n8n.nix

    ../../modules/users/rileyt.nix
  ];

  networking.hostName = "legion";

  # No Tailscale Serve on the laptop — n8n is plain http on localhost here,
  # not behind the desktop's HTTPS front end.
  services.n8n.environment = {
    N8N_HOST = lib.mkForce "localhost";
    N8N_PROTOCOL = lib.mkForce "http";
    WEBHOOK_URL = lib.mkForce "http://localhost:5678/";
  };
}
