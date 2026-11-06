# NVIDIA driver. The desktop uses the stable package.
{ config, lib, ... }:
let
  cfg = config.my.hardware.nvidia;
in
{
  options.my.hardware.nvidia.enable = lib.mkEnableOption "NVIDIA driver";

  config = lib.mkIf cfg.enable {
    hardware = {
      enableRedistributableFirmware = true;
      graphics.enable = true;
      nvidia = {
        open = false;
        modesetting.enable = true;
        powerManagement.enable = false;
        videoAcceleration = false;
        package = config.boot.kernelPackages.nvidiaPackages.stable;
      };
    };
  };
}
