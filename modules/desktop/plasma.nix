# KDE Plasma 6 on Wayland, with SDDM. Plasma (X11) stays in the session menu.
{ config, lib, ... }:
let
  cfg = config.my.desktop.plasma;
  # Both panels are on the RTX 3050. The Intel iGPU and the GTX 1660
  # SUPER have no displays, and KWin can still pick the iGPU.
  # https://invent.kde.org/plasma/kwin/-/blob/master/src/backends/drm/drm_backend.cpp
  displayGpu = "/dev/dri/by-path/pci-0000:02:00.0-card";
in
{
  options.my.desktop.plasma.enable = lib.mkEnableOption "KDE Plasma desktop";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.hardware.nvidia.enable;
        message = "desktop/plasma needs hardware/nvidia (nixctl enable hardware/nvidia)";
      }
    ];

    # "nvidia" in videoDrivers is what turns hardware.nvidia on, and
    # xserver.enable is what loads those kernel modules at boot. The
    # desktop and CUDA both need that. desktop/cinnamon sets the same
    # pair; only one of these two modules can be on, because each one
    # starts its own display manager.
    # https://github.com/NixOS/nixpkgs/blob/6713828a351efa628b025a1adf7f43cbf8597513/nixos/modules/hardware/video/nvidia.nix
    services.xserver = {
      enable = true;
      videoDrivers = [ "nvidia" ];
      xkb = {
        layout = "us";
        variant = "";
      };
    };

    services.desktopManager.plasma6.enable = true;
    services.displayManager.sddm.enable = true;
    # Wayland session. Plasma (X11) is still listed by SDDM.
    services.displayManager.defaultSession = "plasma";

    systemd.services.display-manager.environment.KWIN_DRM_DEVICES = displayGpu;
    environment.sessionVariables.KWIN_DRM_DEVICES = displayGpu;

    services.pulseaudio.enable = false;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };
    security.rtkit.enable = true;
  };
}
