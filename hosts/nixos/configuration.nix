{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common.nix

    ../../modules/hardware/nvidia.nix
  ];

  host.gpus = [ "RTX 3050" "GTX 1660 Super" ];
  host.uptimeKumaSync = true;
}
