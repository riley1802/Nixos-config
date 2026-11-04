# MX Master 4: package, udev rules, and the login agent.
# https://openlogi.org/docs/installation
{ config, lib, ... }:
let
  cfg = config.my.apps.openlogi;
in
{
  options.my.apps.openlogi.enable = lib.mkEnableOption "OpenLogi for the MX Master 4";

  config = lib.mkIf cfg.enable {
    # OpenLogi's udev rule tags /dev/uinput for the seat user. That node is a
    # static device until the module is loaded, so the ACL is never applied
    # unless uinput is loaded at boot.
    boot.kernelModules = [ "uinput" ];

    programs.openlogi = {
      enable = true;
      launchAtLogin = true;
    };
  };
}
