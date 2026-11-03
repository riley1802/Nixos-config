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
      xkb = {
        layout = "us";
        variant = "";
      };
      desktopManager.cinnamon.enable = true;
      displayManager.lightdm.enable = true;
      # The LG 27GL850 is G-SYNC Compatible, and the driver turns variable
      # refresh on for the whole composited desktop. The cursor then waits
      # on that panel. This leaves it off at login.
      displayManager.sessionCommands = ''
        ${config.boot.kernelPackages.nvidiaPackages.stable.settings}/bin/nvidia-settings -a AllowVRR=0
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
