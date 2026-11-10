# Nightly copy of the Lidarr music library to Google Drive.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.arr.lidarr-drive;
  # Absent until Riley commits the agenix file. Referencing a missing
  # git path fails evaluation, so the timer stays out of the system until
  # that file exists.
  secretFile = ../../../secrets/rclone-gdrive.age;
  hasSecret = builtins.pathExists secretFile;
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

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = config.my.services.arr.media.enable;
          message = "services/arr/lidarr-drive needs services/arr/media (nixctl enable services/arr/media)";
        }
      ];

      warnings = lib.optional (!hasSecret) ''
        services/arr/lidarr-drive is on, but secrets/rclone-gdrive.age is not
        committed, so the 3:00 AM copy is not installed.
      '';
    })
    (lib.mkIf (cfg.enable && hasSecret) {
      age.secrets.rclone-gdrive = {
        file = secretFile;
        mode = "0400";
        owner = "root";
        group = "root";
      };

      environment.systemPackages = [ pkgs.rclone ];

      # copy leaves Drive files that are no longer in the library. sync would
      # delete them, including when this path is empty or not the vault mount.
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
        serviceConfig = {
          Type = "oneshot";
          TimeoutStartSec = "infinity";
          ExecStart = pkgs.writeShellScript "lidarr-drive" ''
            set -euo pipefail
            src=${lib.escapeShellArg cfg.source}
            dest=${lib.escapeShellArg cfg.destination}
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
              --config "${config.age.secrets.rclone-gdrive.path}" \
              --fast-list \
              --create-empty-src-dirs \
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
    })
  ];
}
