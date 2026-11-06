# KDE Connect for the phone on the home network.
{ config, lib, ... }:
let
  cfg = config.my.desktop.kdeconnect;
  kdeConnectPorts = [
    {
      from = 1714;
      to = 1764;
    }
  ];
in
{
  options.my.desktop.kdeconnect.enable = lib.mkEnableOption "KDE Connect";

  config = lib.mkIf cfg.enable {
    programs.kdeconnect.enable = true;

    # The package autostarts kdeconnectd. Plasma draws its own tray icon,
    # and this indicator is NotShowIn=KDE, so it is installed only with
    # the Cinnamon module.
    environment.etc = lib.mkIf config.my.desktop.cinnamon.enable {
      "xdg/autostart/org.kde.kdeconnect.nonplasma.desktop".source =
        "${config.programs.kdeconnect.package}/share/applications/org.kde.kdeconnect.nonplasma.desktop";
    };

    # KDE Connect stays open for the phone on the home network only.
    networking.firewall.interfaces.${config.my.lanInterface} = {
      allowedTCPPortRanges = kdeConnectPorts;
      allowedUDPPortRanges = kdeConnectPorts;
    };
  };
}
