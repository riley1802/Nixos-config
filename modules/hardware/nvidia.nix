{ config, ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Use the proprietary NVIDIA kernel module
    open = false;

    # Modesetting for the proprietary driver (X11 / Cinnamon + LightDM).
    modesetting.enable = true;

    powerManagement.enable = false;

    # Track the stable NVIDIA driver package for the active kernel.
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
}
