{ ... }:

{
  imports = [
    ./hardware-configuration.nix

    ./modules/core/boot.nix
    ./modules/core/locale.nix
    ./modules/core/networking.nix
    ./modules/core/system.nix

    ./modules/hardware/nvidia.nix

    ./modules/desktop/audio.nix
    ./modules/desktop/gnome.nix

    ./modules/programs/firefox.nix
    ./modules/programs/gaming.nix
    ./modules/programs/packages.nix

    ./modules/services/llama-cpp.nix
    ./modules/services/printing.nix
    ./modules/services/searxng.nix

    ./modules/users/rileyt.nix
  ];
}
