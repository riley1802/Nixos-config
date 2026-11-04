# Shared media directories for the arr stack, qBittorrent, and Jellyfin.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.arr.media;
in
{
  options.my.services.arr.media.enable = lib.mkEnableOption "shared media directories";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.hardware.disks.enable;
        message = "services/arr/media needs hardware/disks (nixctl enable hardware/disks)";
      }
    ];

    users.groups.media = { };

    # local-fs already waits up to the device timeout above. If the disk
    # appears after that, start the mount and the services that bind to it.
    # The timer stops once that succeeds, and it gives up after a few tries.
    systemd.services.media-stack-boot = {
      description = "Start media services once the game drive is mounted";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = "5min";
        ExecStart = pkgs.writeShellScript "media-stack-boot" ''
          set -euo pipefail
          export PATH=${pkgs.lib.makeBinPath [ pkgs.systemd pkgs.coreutils ]}:$PATH
          attempts=/run/media-stack-boot.attempts
          n=0
          if [[ -f $attempts ]]; then
            n=$(cat "$attempts")
          fi
          n=$((n + 1))
          printf '%s\n' "$n" > "$attempts"
          if (( n > 6 )); then
            echo "game drive is still not mounted; media services stay down" >&2
            systemctl stop media-stack-boot.timer
            exit 1
          fi
          systemctl start "$(systemd-escape -p --suffix=mount /mnt/game-drive)"
          systemctl start vault-media.service media-directories.service
          for s in qbittorrent sonarr radarr lidarr bazarr jellyfin cleanuparr; do
            if systemctl is-enabled --quiet "$s.service" && ! systemctl is-active --quiet "$s.service"; then
              systemctl start "$s.service"
            fi
          done
        '';
      };
    };
    systemd.timers.media-stack-boot = {
      description = "Retry media services until the game drive is mounted";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitInactiveSec = "30s";
        AccuracySec = "5s";
      };
    };

    # bindfs publishes only the media directory to the media group.
    # "old stuff" stays on the NTFS mount, outside this view.
    # The volume itself is rileyt:users mode 0700, and ntfs-3g ignores chmod.
    # mirror-only=@media left that group in place and then cleared every
    # permission bit for accounts it did not treat as members. Sonarr and
    # Lidarr got EACCES on the category folders and reported that they
    # could not see them. force-group makes the view group media, mode
    # 0770, which is the group those services already run as. Setgid does
    # not work on FUSE, so new files are put in the media group here.
    # https://bindfs.org/docs/bindfs.1.html
    systemd.services.vault-media = {
      description = "Media group view of the game drive";
      # The hyphen in /mnt/game-drive is escaped in the systemd unit name.
      wants = [ "mnt-game\\x2ddrive.mount" ];
      after = [ "mnt-game\\x2ddrive.mount" "vault.mount" ];
      bindsTo = [ "mnt-game\\x2ddrive.mount" "vault.mount" ];
      serviceConfig = {
        Type = "simple";
        ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /vault/media";
        ExecStart = "${pkgs.bindfs}/bin/bindfs -f -o force-group=media,perms=u=rwX:g=rwX:o=,create-for-user=rileyt,create-for-group=media,create-with-perms=u=rwX:g=rwX:o=,chown-ignore,chgrp-ignore,chmod-ignore,multithreaded /mnt/game-drive/media /vault/media";
        Restart = "on-failure";
        RestartSec = "3s";
      };
      unitConfig = {
        StartLimitIntervalSec = "60";
        StartLimitBurst = "5";
      };
    };
    systemd.services.media-directories = {
      description = "Create the shared media directories";
      wants = [ "vault-media.service" ];
      after = [ "vault-media.service" ];
      bindsTo = [ "vault-media.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        install -d -m 0775 -o root -g media \
          /vault/media/downloads \
          /vault/media/downloads/incomplete \
          /vault/media/downloads/tv \
          /vault/media/downloads/movies \
          /vault/media/downloads/music \
          /vault/media/library \
          /vault/media/library/tv \
          /vault/media/library/movies \
          /vault/media/library/music
      '';
    };

    systemd.services.qbittorrent.wants = [ "media-directories.service" ];
    systemd.services.qbittorrent.after = [ "media-directories.service" ];
    systemd.services.qbittorrent.bindsTo = [ "media-directories.service" ];
    systemd.services.sonarr.wants = [ "media-directories.service" ];
    systemd.services.sonarr.after = [ "media-directories.service" ];
    systemd.services.sonarr.bindsTo = [ "media-directories.service" ];
    systemd.services.radarr.wants = [ "media-directories.service" ];
    systemd.services.radarr.after = [ "media-directories.service" ];
    systemd.services.radarr.bindsTo = [ "media-directories.service" ];
    systemd.services.lidarr.wants = [ "media-directories.service" ];
    systemd.services.lidarr.after = [ "media-directories.service" ];
    systemd.services.lidarr.bindsTo = [ "media-directories.service" ];
    systemd.services.jellyfin.wants = [ "media-directories.service" ];
    systemd.services.jellyfin.after = [ "media-directories.service" ];
    systemd.services.jellyfin.bindsTo = [ "media-directories.service" ];
    systemd.services.bazarr.wants = [ "media-directories.service" ];
    systemd.services.bazarr.after = [ "media-directories.service" ];
    systemd.services.bazarr.bindsTo = [ "media-directories.service" ];

    # Only the mountpoint, and not group-writable. The real directories are
    # created after bindfs is up. Creating them here would put them on the
    # vault disk and bindfs would refuse to cover a non-empty directory.
    systemd.tmpfiles.settings.media."/vault/media"."d" = {
      mode = "0755";
      user = "root";
      group = "root";
    };
  };
}
