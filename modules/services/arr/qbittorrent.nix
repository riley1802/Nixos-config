# qBittorrent download client. Web page on port 8080.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.arr.qbittorrent;
  qbitConf = "/var/lib/qBittorrent/qBittorrent/config/qBittorrent.conf";
  qbitHashLine = "/var/lib/qBittorrent/qBittorrent/config/webui-password-line";
  qbitNameLine = "/var/lib/qBittorrent/qBittorrent/config/webui-username-line";
in
{
  options.my.services.arr.qbittorrent.enable = lib.mkEnableOption "qBittorrent";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.services.arr.media.enable;
        message = "services/arr/qbittorrent needs services/arr/media (nixctl enable services/arr/media)";
      }
      {
        assertion = config.my.network.pia.enable;
        message = "services/arr/qbittorrent needs network/pia (nixctl enable network/pia)";
      }
    ];

    services.qbittorrent = {
      enable = true;
      webuiPort = 8080;
      torrentingPort = 53644;
      openFirewall = false;
      extraArgs = [ "--confirm-legal-notice" ];

      serverConfig.BitTorrent.Session = {
        Interface = "pia";
        InterfaceName = "pia";
        DefaultSavePath = "/vault/media/downloads";
        TempPathEnabled = true;
        TempPath = "/vault/media/downloads/incomplete";
        # A torrent under 1 MB/s does not use up a download slot, so a
        # nearly stopped album cannot keep every movie waiting.
        QueueingSystemEnabled = true;
        MaxActiveDownloads = 8;
        MaxActiveUploads = 4;
        MaxActiveTorrents = 16;
        IgnoreSlowTorrentsForQueueing = true;
        SlowTorrentsDownloadRate = 1024;
        SlowTorrentsUploadRate = 10;
        SlowTorrentsInactivityTimer = 60;
      };
    };

    users.users.qbittorrent.extraGroups = [ "media" ];
    systemd.services.qbittorrent.serviceConfig.UMask = "0002";

    # The NixOS module rewrites qBittorrent.conf on every start. Keep the WebUI
    # username and password hash beside that file so they are not committed
    # to Git.
    systemd.services.qbittorrent.preStart = ''
      set -euo pipefail
      conf=${qbitConf}
      saved=${qbitHashLine}
      saved_user=${qbitNameLine}
      # The client rewrites its config world-readable. Keep the directory private.
      chmod 700 /var/lib/qBittorrent/qBittorrent /var/lib/qBittorrent/qBittorrent/config
      umask 077
      if [[ -f $conf ]] && grep -q 'Password_PBKDF2=' "$conf"; then
        grep 'Password_PBKDF2=' "$conf" > "$saved"
      fi
      if [[ -f $conf ]] && grep -q 'WebUI\Username=' "$conf"; then
        grep 'WebUI\Username=' "$conf" > "$saved_user"
      fi
    '';
    systemd.services.qbittorrent.serviceConfig.ExecStartPre = lib.mkAfter [
      (pkgs.writeShellScript "qbittorrent-restore-webui-password" ''
        set -euo pipefail
        conf=${qbitConf}
        saved=${qbitHashLine}
        saved_user=${qbitNameLine}
        restore=0
        if [[ -s $saved ]] && ! grep -q 'Password_PBKDF2=' "$conf"; then
          restore=1
        fi
        if [[ -s $saved_user ]] && ! grep -q 'WebUI\Username=' "$conf"; then
          restore=1
        fi
        if [[ $restore == 1 ]]; then
          printf '\n[Preferences]\n' >> "$conf"
          if [[ -s $saved ]] && ! grep -q 'Password_PBKDF2=' "$conf"; then
            cat "$saved" >> "$conf"
          fi
          if [[ -s $saved_user ]] && ! grep -q 'WebUI\Username=' "$conf"; then
            cat "$saved_user" >> "$conf"
          fi
        fi
      '')
    ];

    # Web UI on the tailnet. The torrent port stays on the VPN interface.
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      8080 # qBittorrent WebUI
    ];
    networking.firewall.interfaces.pia = {
      allowedTCPPorts = [ 53644 ];
      allowedUDPPorts = [ 53644 ];
    };
  };
}
