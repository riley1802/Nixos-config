# Cinnamon desktop, LightDM, and PipeWire.
{ config, lib, ... }:
let
  cfg = config.my.desktop.cinnamon;
in
{
  options.my.desktop.cinnamon.enable = lib.mkEnableOption "Cinnamon desktop";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.hardware.nvidia.enable;
        message = "desktop/cinnamon needs hardware/nvidia (nixctl enable hardware/nvidia)";
      }
    ];

    services.xserver = {
      enable = true;
      videoDrivers = [ "nvidia" ];
      # Do not set ForceFullCompositionPipeline. It waits for a composed
      # frame before the cursor moves, which shows up as mouse lag.
      # https://download.nvidia.com/XFree86/Linux-x86_64/595.71.05/README/configtwinview.html
      # Coolbits 8 unlocks the PowerMizer control. Without it the driver
      # accepts a clock-mode change and then throws it away.
      # https://download.nvidia.com/XFree86/Linux-x86_64/595.71.05/README/xconfigoptions.html
      deviceSection = ''
        Option "Coolbits" "8"
      '';
      xkb = {
        layout = "us";
        variant = "";
      };
      desktopManager.cinnamon.enable = true;
      displayManager.lightdm.enable = true;
      # The LG 27GL850 is G-SYNC Compatible, and the driver turns variable
      # refresh on for the whole composited desktop. The cursor then waits
      # on that panel. This leaves it off at login.
      # Mode 2 is "prefer consistent performance". Adaptive clocks on the
      # 3050 drop to about 600 MHz between frames while it drives both
      # 144 Hz panels, so the cursor misses a frame and then catches up.
      displayManager.sessionCommands = ''
        ${config.boot.kernelPackages.nvidiaPackages.stable.settings}/bin/nvidia-settings -a AllowVRR=0
        ${config.boot.kernelPackages.nvidiaPackages.stable.settings}/bin/nvidia-settings -a "[gpu:0]/GPUPowerMizerMode=2"
      '';
    };

    services.pulseaudio.enable = false;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };

    security.rtkit.enable = true;
    programs.dconf.enable = true;
  };
}
