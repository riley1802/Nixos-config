{ ... }:

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

    ../../modules/hardware/graphics.nix
    ../../modules/hardware/nvidia.nix

    ../../modules/desktop/gdm.nix
    ../../modules/desktop/gnome.nix
    ../../modules/desktop/gnome-extensions.nix
    ../../modules/desktop/audio.nix

    ../../modules/programs/firefox.nix
    ../../modules/programs/steam.nix
    ../../modules/programs/games-dirs.nix
    ../../modules/programs/packages.nix

    ../../modules/services/llama-cpp.nix
    ../../modules/services/printing.nix
    ../../modules/services/searxng.nix
    ../../modules/services/tailscale.nix

    ../../modules/users/rileyt.nix
  ];
}
