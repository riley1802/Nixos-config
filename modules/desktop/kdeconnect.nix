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

    # The package autostarts kdeconnectd only. A non-Plasma session
    # needs this indicator entry for the tray icon. Cinnamon is the
    # other desktop module; it is off while Plasma is on.
    environment.etc."xdg/autostart/org.kde.kdeconnect.nonplasma.desktop".source =
      "${config.programs.kdeconnect.package}/share/applications/org.kde.kdeconnect.nonplasma.desktop";

    # KDE Connect stays open for the phone on the home network only.
    networking.firewall.interfaces.${config.my.lanInterface} = {
      allowedTCPPortRanges = kdeConnectPorts;
      allowedUDPPortRanges = kdeConnectPorts;
    };
  };
}
