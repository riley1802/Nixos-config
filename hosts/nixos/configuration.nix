{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common.nix

    ../../modules/hardware/nvidia.nix

    ../../modules/desktop/gdm.nix
    ../../modules/desktop/gnome.nix
    ../../modules/desktop/gnome-extensions.nix
  ];

  host.gpus = [ "RTX 3050" "GTX 1660 Super" ];
  host.uptimeKumaSync = true;
}
