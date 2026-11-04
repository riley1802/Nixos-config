# NetworkManager for the desktop.
{ config, lib, ... }:
let
  cfg = config.my.network.networkmanager;
in
{
  options.my.network.networkmanager.enable = lib.mkEnableOption "NetworkManager";

  config = lib.mkIf cfg.enable {
    networking.networkmanager.enable = true;
  };
}
