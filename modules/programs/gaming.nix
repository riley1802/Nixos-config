{ ... }:

{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = false;
  };

  systemd.tmpfiles.rules = [
    "d /games 0755 root root - -"
    "d /games/steam-library 0755 rileyt users - -"
  ];
}
