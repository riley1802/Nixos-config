# NVIDIA driver. The desktop and llama.cpp use the stable package.
{ config, lib, pkgs, ... }:
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

    # Immediate flip for the 1660. systemd Conflicts= stops the other
    # process. Boot and the tailnet still follow my.hardware.gtx1660.
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "gtx1660" ''
        set -euo pipefail
        systemctl=${pkgs.systemd}/bin/systemctl
        case ''${1:-} in
          breeze|breeze-tts)
            "$systemctl" start breeze-tts.service
            ;;
          nemotron)
            "$systemctl" start llama-cpp-nemotron.service
            ;;
          status)
            for unit in breeze-tts llama-cpp-nemotron; do
              printf '%s %s\n' "$unit" "$("$systemctl" is-active "$unit.service" || true)"
            done
            exit 0
            ;;
          *)
            echo "usage: gtx1660 breeze|nemotron|status" >&2
            exit 1
            ;;
        esac
        echo "Running. Boot and the tailnet follow my.hardware.gtx1660 until that line changes and nixctl apply."
      '')
    ];
  };
}
