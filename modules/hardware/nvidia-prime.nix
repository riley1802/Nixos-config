{ config, ... }:

# Hybrid AMD iGPU + NVIDIA dGPU (Optimus) for the Legion 5 Pro 16ARH7H.
# Offload mode: render on the iGPU by default, run apps on the dGPU with
# `nvidia-offload <cmd>` (or prime-run env vars).
#
# REQUIRES the BIOS "GPU Working Mode" set to Hybrid. In Discrete/dGPU-only
# mode the MUX wires the internal panel (eDP-1) to the NVIDIA card, the iGPU
# has no connected outputs, and X11 (LightDM/Cinnamon) renders to an invisible
# dummy framebuffer — black screen at boot.
{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    open = false;
    modesetting.enable = true;

    # Fine-grained power management lets the dGPU power down when idle.
    powerManagement.enable = true;
    powerManagement.finegrained = true;

    package = config.boot.kernelPackages.nvidiaPackages.stable;

    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true; # provides `nvidia-offload`
      };
      amdgpuBusId = "PCI:53:0:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };
}
