# qBittorrent download client. Web page on port 8080.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.arr.qbittorrent;
  qbitConf = "/var/lib/qBittorrent/qBittorrent/config/qBittorrent.conf";
  qbitHashLine = "/var/lib/qBittorrent/qBittorrent/config/webui-password-line";
  qbitNameLine = "/var/lib/qBittorrent/qBittorrent/config/webui-username-line";
  # qBittorrent has no category priority. Unfinished tv-sonarr and radarr
  # torrents are moved to the front when one of them sits behind lidarr.
  # Stopped torrents are left alone. topPrio keeps their relative order.
  # https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API-(qBittorrent-4.1)#set-torrent-top-priority
  preferVideo = pkgs.writeShellApplication {
    name = "qbittorrent-prefer-video";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      base=http://127.0.0.1:8080
      tmp=$(mktemp)
      trap 'rm -f "$tmp" "$tmp.hashes"' EXIT

      code=$(curl -sS --max-time 20 -o "$tmp" -w '%{http_code}' \
        -H "Referer: ''${base}/" \
        "''${base}/api/v2/torrents/info" || true)
      if [[ $code == "000" || -z "$code" ]]; then
        echo "qBittorrent WebUI is not accepting local requests yet"
        exit 0
      fi
      if [[ $code != 200 ]]; then
        echo "qBittorrent WebUI returned HTTP $code" >&2
        exit 1
      fi

      echo "categories: $(jq -r '[group_by(.category)[] | "\(.[0].category)=\(length)"] | join(" ")' "$tmp")"

      decision=$(jq -c '
        def stopped:
          .state == "stoppedDL" or .state == "stoppedUP"
          or .state == "pausedDL" or .state == "pausedUP";
        def unfinished:
          (.progress < 1) and (stopped | not) and (.priority >= 0);
        def video: (.category == "tv-sonarr" or .category == "radarr");
        def music: (.category == "lidarr");
        (map(select(unfinished and video))) as $video
        | (map(select(unfinished and music))) as $music
        | if (($video | length) == 0) or (($music | length) == 0) then
            {move: false, videos: ($video | length), music: ($music | length), hashes: []}
          else
            (([$video[].priority] | max) > ([$music[].priority] | min)) as $behind
            | if $behind then
                {move: true, videos: ($video | length), music: ($music | length), hashes: [$video[].hash]}
              else
                {move: false, videos: ($video | length), music: ($music | length), hashes: []}
              end
          end
      ' "$tmp")

      videos=$(jq -r .videos <<< "$decision")
      music=$(jq -r .music <<< "$decision")
      if [[ $(jq -r .move <<< "$decision") != true ]]; then
        echo "queue already prefers movies and shows (''${videos} video, ''${music} music unfinished)"
        exit 0
      fi

      jq -j '.hashes | join("|")' <<< "$decision" > "$tmp.hashes"
      curl -fsS --max-time 30 \
        -H "Referer: ''${base}/" \
        --data-urlencode "hashes@''${tmp}.hashes" \
        "''${base}/api/v2/torrents/topPrio"
      echo "moved ''${videos} movie/show torrents ahead of ''${music} albums"
    '';
  };
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
        MaxActiveDownloads = 12;
        MaxActiveUploads = 4;
        MaxActiveTorrents = 16;
        IgnoreSlowTorrentsForQueueing = true;
        SlowTorrentsDownloadRate = 1024;
        SlowTorrentsUploadRate = 10;
        SlowTorrentsInactivityTimer = 60;
      };

      # Loopback skips the password so the queue helper can run without
      # writing that password into the nix file. Other interfaces still ask.
      # https://github.com/qbittorrent/qBittorrent/wiki/Explanation-of-Options-in-qBittorrent#bypass-authentication-for-clients-on-localhost
      serverConfig.Preferences.WebUI.LocalHostAuth = false;
    };

    # First run waits until this start has finished rewriting qBittorrent.conf.
    # After that, OnUnitInactiveSec repeats a minute after each pass.
    systemd.services.qbittorrent-prefer-video = {
      description = "Keep movies and shows ahead of music in the qBittorrent queue";
      after = [ "qbittorrent.service" ];
      serviceConfig.Type = "oneshot";
      serviceConfig.ExecStart = lib.getExe preferVideo;
    };
    systemd.timers.qbittorrent-prefer-video = {
      description = "Keep movies and shows ahead of music in the qBittorrent queue";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnActiveSec = "1min";
        OnUnitInactiveSec = "1min";
        AccuracySec = "10s";
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
