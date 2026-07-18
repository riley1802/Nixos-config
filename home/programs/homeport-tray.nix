{ pkgs, inputs, uptimeKumaSyncEnvFile, ... }:
let
  homeport-tray = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.homeport-tray;
in
{
  home.packages = [ homeport-tray ];

  # Autostarts hidden to tray on login; shows the Homeport dashboard window
  # and relays ntfy alerts as native notifications. NTFY_TOPIC comes from the
  # same decrypted secret uptime-kuma-sync.service uses (owner set to rileyt
  # in modules/services/uptime-kuma.nix so this user session can read it).
  # uptimeKumaSyncEnvFile is threaded in from flake.nix as
  # config.age.secrets.uptime-kuma-sync.path — the canonical agenix-resolved
  # path — rather than a hand-typed "/run/agenix/uptime-kuma-sync" string, so
  # it can't silently drift if agenix's on-disk layout ever changes.
  systemd.user.services.homeport-tray = {
    Unit = {
      Description = "Homeport dashboard tray companion";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      EnvironmentFile = uptimeKumaSyncEnvFile;
      ExecStart = "${homeport-tray}/bin/homeport-tray --start-hidden";
      Restart = "on-failure";
      RestartSec = "5s";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
