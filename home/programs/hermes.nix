{ inputs, pkgs, lib, ... }:

let
  hermesDesktop = inputs.hermes-agent.packages.${pkgs.system}.desktop;
in
{
  home.packages = [ hermesDesktop ];

  xdg.desktopEntries.hermes-desktop = {
    name = "Hermes Agent";
    comment = "Native desktop shell for Hermes Agent";
    exec = "${lib.getExe hermesDesktop}";
    terminal = false;
    categories = [
      "Network"
      "Chat"
    ];
    startupNotify = true;
  };
}
