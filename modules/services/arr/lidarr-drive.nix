# Nightly copy of missing Lidarr library files to Google Drive (user rclone config).
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.arr.lidarr-drive;
  rcloneConf = "/home/${config.my.user}/.config/rclone/rclone.conf";
in
{
  options.my.services.arr.lidarr-drive = {
    enable = lib.mkEnableOption "nightly copy of the Lidarr music library to Google Drive";

    source = lib.mkOption {
      type = lib.types.str;
      default = "/vault/media/library/music";
      description = "Lidarr library directory to copy.";
    };

    destination = lib.mkOption {
      type = lib.types.str;
      default = "gdrive:Lidarr";
      description = "rclone destination folder, not the remote root.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.services.arr.media.enable;
        message = "services/arr/lidarr-drive needs services/arr/media (nixctl enable services/arr/media)";
      }
    ];

    environment.systemPackages = [ pkgs.rclone ];

    # copy leaves Drive files that are no longer in the library. sync would
    # delete them, including when this path is empty or not the vault mount.
    # --ignore-existing skips paths already on Drive (no re-upload).
    # https://rclone.org/commands/rclone_copy/
    systemd.services.lidarr-drive = {
      description = "Copy the Lidarr music library to Google Drive";
      after = [
        "network-online.target"
        "vault-media.service"
        "media-directories.service"
      ];
      wants = [
        "network-online.target"
        "vault-media.service"
        "media-directories.service"
      ];
      # Skipped, not failed, when /vault/media is not a mount point.
      unitConfig.ConditionPathIsMountPoint = "/vault/media";
      environment.HOME = "/home/${config.my.user}";
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = "infinity";
        User = config.my.user;
        Group = "media";
        ExecStart = pkgs.writeShellScript "lidarr-drive" ''
          set -euo pipefail
          src=${lib.escapeShellArg cfg.source}
          dest=${lib.escapeShellArg cfg.destination}
          conf=${lib.escapeShellArg rcloneConf}
          if [[ ! -f "$conf" ]]; then
            echo "lidarr-drive: rclone config is missing: $conf" >&2
            exit 1
          fi
          if [[ ! -d "$src" ]]; then
            echo "lidarr-drive: source is missing: $src" >&2
            exit 1
          fi
          child=$(${pkgs.findutils}/bin/find "$src" -mindepth 1 -print -quit)
          if [[ -z "$child" ]]; then
            echo "lidarr-drive: source has no children: $src" >&2
            exit 1
          fi
          mount=$(${pkgs.util-linux}/bin/findmnt -n -o TARGET --target "$src" || true)
          if [[ "$mount" != /vault/media ]]; then
            echo "lidarr-drive: source is not on /vault/media (findmnt: ''${mount:-none})" >&2
            exit 1
          fi
          exec ${pkgs.rclone}/bin/rclone copy "$src" "$dest" \
            --config "$conf" \
            --fast-list \
            --create-empty-src-dirs \
            --ignore-existing \
            --transfers 4 \
            --stats 1m \
            --log-level INFO
        '';
      };
    };

    # Persistent runs the missed 03:00 slot after a night the machine was off.
    # https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html#Persistent=
    systemd.timers.lidarr-drive = {
      description = "Nightly copy of the Lidarr music library to Google Drive";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 03:00:00";
        Timezone = "America/Chicago";
        Persistent = true;
        AccuracySec = "1min";
      };
    };
  };
}
