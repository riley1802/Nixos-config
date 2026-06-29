{ config, ... }:

{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.graphics = {
    enable = true;

    # Required for Steam, Proton, and many 32-bit game/runtime libraries.
    enable32Bit = true;
  };

  hardware.nvidia = {
    # Use the proprietary NVIDIA kernel module, matching your existing setup.
    open = false;

    # Required for modern NVIDIA Wayland support through GDM/GNOME.
    modesetting.enable = true;

    powerManagement.enable = false;

    # Track the stable NVIDIA driver package for the active kernel.
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
}
