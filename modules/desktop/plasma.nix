# KDE Plasma 6 on Wayland, with SDDM. Plasma (X11) stays in the session menu.
{ config, lib, ... }:
let
  cfg = config.my.desktop.plasma;
  # KWin splits KWIN_DRM_DEVICES on ":". The 3050's by-path node is
  # pci-0000:02:00.0-card, so the greeter opened three fake paths and
  # exited, and SDDM left the screen blank. This symlink has no colon.
  # https://invent.kde.org/plasma/kwin/-/blob/master/src/backends/drm/drm_backend.cpp
  displayGpu = "/run/display-gpu";
in
{
  options.my.desktop.plasma.enable = lib.mkEnableOption "KDE Plasma desktop";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.hardware.nvidia.enable;
        message = "desktop/plasma needs hardware/nvidia (nixctl enable hardware/nvidia)";
      }
      {
        assertion = !config.my.desktop.cinnamon.enable;
        message = "desktop/plasma and desktop/cinnamon each start a display manager; turn one off";
      }
    ];

    # xserver.enable loads the NVIDIA kernel modules at boot. The driver
    # package is hardware/nvidia. desktop/cinnamon sets the same xserver
    # pair. Only one desktop module can be on, because each one starts
    # its own display manager.
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

    systemd.tmpfiles.rules = [
      "L+ ${displayGpu} - - - - /dev/dri/by-path/pci-0000:02:00.0-card"
    ];
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
