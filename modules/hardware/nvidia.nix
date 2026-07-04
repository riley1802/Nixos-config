{ config, ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Use the proprietary NVIDIA kernel module
    open = false;

    # Required for modern NVIDIA Wayland support through GDM/GNOME.
    modesetting.enable = true;

    powerManagement.enable = false;

    # Track the stable NVIDIA driver package for the active kernel.
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
}
