{ pkgs, inputs, ... }:
let
  homeport-tray = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.homeport-tray;
in
{
  home.packages = [ homeport-tray ];

  # Autostarts hidden to tray on login; shows the Homeport dashboard window
  # and relays ntfy alerts as native notifications. NTFY_TOPIC comes from the
  # same decrypted secret uptime-kuma-sync.service uses (owner set to rileyt
  # in modules/services/uptime-kuma.nix so this user session can read it).
  systemd.user.services.homeport-tray = {
    Unit = {
      Description = "Homeport dashboard tray companion";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      EnvironmentFile = "/run/agenix/uptime-kuma-sync";
      ExecStart = "${homeport-tray}/bin/homeport-tray --start-hidden";
      Restart = "on-failure";
      RestartSec = "5s";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
