{ config, lib, pkgs, ... }:

let
  cfg = config.services.rust-lan-server;
  stateDir = "/var/lib/rust-server";
  serverDir = "${stateDir}/server";
  identity = "nixos-lan-pve";
  rconSecret = config.sops.secrets."rust-server/rcon-password".path;
  pluginManifest = import ./rust-server/plugins.nix { inherit pkgs; };
  customPlugins = [
    {
      name = "NixosCore.cs";
      source = ./rust-server/custom-plugins/NixosCore.cs;
    }
    {
      name = "NixosEconomy.cs";
      source = ./rust-server/custom-plugins/NixosEconomy.cs;
    }
    {
      name = "NixosWorld.cs";
      source = ./rust-server/custom-plugins/NixosWorld.cs;
    }
  ];
  pluginConfigs = [
    {
      name = "Backpacks.json";
      source = ./rust-server/config/Backpacks.json;
    }
    {
      name = "RecycleManager.json";
      source = ./rust-server/config/RecycleManager.json;
    }
    {
      name = "RemoverTool.json";
      source = ./rust-server/config/RemoverTool.json;
    }
  ];

  installServer = pkgs.writeShellApplication {
    name = "rust-server-install";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.gzip
      pkgs.gnused
      pkgs.jq
      pkgs.steamcmd
      pkgs.gnutar
    ];
    text = ''
      install -d -m 0750 "${serverDir}"
      steamcmd \
        +force_install_dir "${serverDir}" \
        +login anonymous \
        +app_update 258550 validate \
        +quit

      install -d -m 0750 "${stateDir}/.steam/sdk64"
      ln -sfn \
        "${stateDir}/.local/share/Steam/linux64/steamclient.so" \
        "${stateDir}/.steam/sdk64/steamclient.so"

      ${lib.optionalString cfg.enableCarbon ''
        carbon_temp="$(mktemp -d)"
        trap 'rm -rf "$carbon_temp"' EXIT

        release_json="$(
          curl --fail --silent --show-error --location \
            https://api.github.com/repos/CarbonCommunity/Carbon/releases/tags/production_build
        )"
        archive_url="$(
          jq --raw-output \
            '.assets[] | select(.name == "Carbon.Linux.Release.tar.gz") | .browser_download_url' \
            <<<"$release_json"
        )"
        expected_digest="$(
          jq --raw-output \
            '.assets[] | select(.name == "Carbon.Linux.Release.tar.gz") | .digest // empty' \
            <<<"$release_json" |
            sed 's/^sha256://'
        )"

        if [[ -z "$archive_url" || -z "$expected_digest" ]]; then
          echo "Carbon production release metadata is incomplete" >&2
          exit 1
        fi

        curl --fail --silent --show-error --location \
          "$archive_url" \
          --output "$carbon_temp/carbon.tar.gz"
        actual_digest="$(sha256sum "$carbon_temp/carbon.tar.gz" | cut -d' ' -f1)"

        if [[ "$actual_digest" != "$expected_digest" ]]; then
          echo "Carbon archive digest mismatch" >&2
          exit 1
        fi

        tar -xzf "$carbon_temp/carbon.tar.gz" -C "${serverDir}"
        install -d -m 0750 "${serverDir}/carbon/plugins"
        ${lib.concatMapStringsSep "\n" (plugin: ''
          install -m 0644 "${plugin.source}" \
            "${serverDir}/carbon/plugins/${plugin.name}"
        '') pluginManifest}
      ''}
    '';
  };

  startServer = pkgs.writeShellApplication {
    name = "rust-server-start";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.gawk
      pkgs.iproute2
      pkgs.jq
      pkgs.steam-run
    ];
    text = ''
      server_ip="$(
        ip -4 -o address show dev "${cfg.lanInterface}" |
          awk 'NR == 1 { split($4, address, "/"); print address[1] }'
      )"

      if [[ -z "$server_ip" ]]; then
        echo "No IPv4 address found on ${cfg.lanInterface}" >&2
        exit 1
      fi

      rcon_password="$(<"${rconSecret}")"
      if [[ -z "$rcon_password" ]]; then
        echo "The RCON password is empty" >&2
        exit 1
      fi

      rm -f "${serverDir}/server/${identity}/cfg/server.cfg"

      ${if cfg.enableCarbon then ''
        install -d -m 0750 "${serverDir}/carbon/plugins" "${serverDir}/carbon/configs"
        rm -f \
          "${serverDir}/carbon/plugins/"*-NixosCore.cs \
          "${serverDir}/carbon/plugins/"*-NixosEconomy.cs \
          "${serverDir}/carbon/configs/"*-Backpacks.json \
          "${serverDir}/carbon/configs/"*-RecycleManager.json \
          "${serverDir}/carbon/configs/"*-RemoverTool.json
        ${lib.concatMapStringsSep "\n" (plugin: ''
          install -m 0644 "${plugin.source}" \
            "${serverDir}/carbon/plugins/${plugin.name}"
        '') customPlugins}
        ${lib.concatMapStringsSep "\n" (pluginConfig: ''
          install -m 0644 "${pluginConfig.source}" \
            "${serverDir}/carbon/configs/${pluginConfig.name}"
        '') pluginConfigs}

        if [[ -f "${serverDir}/carbon/config.json" ]]; then
          carbon_config="$(mktemp)"
          jq \
            '.Analytics.Enabled = false
             | .SelfUpdating.Enabled = true
             | .SelfUpdating.HookUpdates = true' \
            "${serverDir}/carbon/config.json" \
            > "$carbon_config"
          install -m 0640 "$carbon_config" "${serverDir}/carbon/config.json"
          rm -f "$carbon_config"
        fi
        launcher=(steam-run bash "${serverDir}/carbon.sh")
      '' else ''
        launcher=(steam-run "${serverDir}/RustDedicated")
      ''}

      exec "''${launcher[@]}" \
        -batchmode \
        -nographics \
        -insecure \
        -logfile "${stateDir}/logs/rust.log" \
        +server.ip "$server_ip" \
        +server.port ${toString cfg.gamePort} \
        +server.queryport ${toString cfg.queryPort} \
        +server.identity "${identity}" \
        +server.level "Procedural Map" \
        +server.seed ${toString cfg.seed} \
        +server.worldsize 4000 \
        +server.maxplayers 4 \
        +clan.enabled false \
        +server.hostname "NixOS LAN PvE 100x" \
        +server.description "Private LAN PvE; EAC disabled; boosted rates after client validation; use /help for rules." \
        +server.saveinterval 300 \
        +rcon.ip "$server_ip" \
        +rcon.port ${toString cfg.rconPort} \
        +rcon.password "$rcon_password" \
        +rcon.web 1 \
        +app.port 1-
    '';
  };

  rconCommand = pkgs.writeShellApplication {
    name = "rust-server-rcon";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.iproute2
      pkgs.jq
      pkgs.websocat
    ];
    text = ''
      if [[ "$#" -eq 0 ]]; then
        echo "usage: rust-server-rcon <command>" >&2
        exit 2
      fi

      server_ip="$(
        ip -4 -o address show dev "${cfg.lanInterface}" |
          awk 'NR == 1 { split($4, address, "/"); print address[1] }'
      )"
      rcon_password="$(<"${rconSecret}")"
      encoded_password="$(jq -rn --arg value "$rcon_password" '$value | @uri')"
      request="$(
        jq -cn --arg command "$*" \
          '{Identifier: 1, Message: $command, Name: "nixos-operations"}'
      )"

      printf '%s\n' "$request" |
        timeout 5s websocat -t -n -1 \
          "ws://$server_ip:${toString cfg.rconPort}/$encoded_password"
    '';
  };

  backupServer = pkgs.writeShellApplication {
    name = "rust-server-backup";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnutar
      pkgs.zstd
    ];
    text = ''
      backup_class="''${1:-rolling}"
      case "$backup_class" in
        rolling|pre-wipe) ;;
        *)
          echo "backup class must be rolling or pre-wipe" >&2
          exit 2
          ;;
      esac

      save_mode="''${2:-online}"
      case "$save_mode" in
        online)
          "${lib.getExe rconCommand}" server.save >/dev/null 2>&1 || true
          sleep 3
          ;;
        offline) ;;
        *)
          echo "save mode must be online or offline" >&2
          exit 2
          ;;
      esac

      timestamp="$(date --utc +%Y%m%dT%H%M%SZ)"
      destination="${stateDir}/backups/$backup_class-$timestamp.tar.zst"
      temporary="$destination.partial"
      rm -f "$temporary"
      trap 'rm -f "$temporary"' EXIT
      candidates=(
        "server/server/${identity}"
        "server/carbon/configs"
        "server/carbon/data"
        "server/carbon/users"
      )
      paths=()
      for candidate in "''${candidates[@]}"; do
        if [[ -e "${stateDir}/$candidate" ]]; then
          paths+=("$candidate")
        fi
      done

      tar -C "${stateDir}" -cf - "''${paths[@]}" |
        zstd -T0 -10 -o "$temporary"
      mv "$temporary" "$destination"
      trap - EXIT

      find "${stateDir}/backups" -maxdepth 1 -type f \
        -name 'rolling-*.tar.zst' -mtime +14 -delete
      find "${stateDir}/backups" -maxdepth 1 -type f \
        -name 'pre-wipe-*.tar.zst' -mtime +90 -delete
      echo "$destination"
    '';
  };

  maintainServer = pkgs.writeShellApplication {
    name = "rust-server-maintain";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.bash
      pkgs.systemd
    ];
    text = ''
      announce() {
        "${lib.getExe rconCommand}" "say <color=#ffd479>$1</color>" ||
          echo "warning: could not send RCON announcement: $1" >&2
      }

      announce "Daily update and restart in 30 minutes."
      sleep 20m
      announce "Daily update and restart in 10 minutes."
      sleep 5m
      announce "Daily update and restart in 5 minutes."
      sleep 4m
      announce "Daily update and restart in 1 minute."
      sleep 1m
      announce "Saving now for the daily update and restart."
      "${lib.getExe rconCommand}" server.save || true
      sleep 5

      restart_on_failure() {
        systemctl start rust-lan-server.service || true
      }
      trap restart_on_failure EXIT
      systemctl stop rust-lan-server.service
      "${lib.getExe backupServer}" rolling offline
      systemctl restart rust-lan-server-install.service
      systemctl start rust-lan-server.service
      deadline=$((SECONDS + 600))
      until "${lib.getExe healthServer}" strict; do
        if (( SECONDS >= deadline )); then
          echo "Rust server failed its post-maintenance health gate" >&2
          exit 1
        fi
        sleep 10
      done
      trap - EXIT
    '';
  };

  healthServer = pkgs.writeShellApplication {
    name = "rust-server-health";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.iproute2
      pkgs.systemd
    ];
    text = ''
      install -d -m 0750 -o rust-server -g rust-server "${stateDir}/metrics"
      output="$(mktemp)"
      active=0
      listening=0
      if systemctl is-active --quiet rust-lan-server.service; then
        active=1
      fi
      if ss -H -lun | awk '{print $4}' | grep -Eq ':${toString cfg.gamePort}$'; then
        listening=1
      fi
      memory="$(systemctl show rust-lan-server.service -p MemoryCurrent --value)"
      restarts="$(systemctl show rust-lan-server.service -p NRestarts --value)"
      timestamp="$(date +%s)"

      {
        echo "# TYPE rust_server_active gauge"
        echo "rust_server_active $active"
        echo "# TYPE rust_server_game_port_listening gauge"
        echo "rust_server_game_port_listening $listening"
        echo "# TYPE rust_server_memory_bytes gauge"
        echo "rust_server_memory_bytes ''${memory:-0}"
        echo "# TYPE rust_server_restarts counter"
        echo "rust_server_restarts_total ''${restarts:-0}"
        echo "# TYPE rust_server_health_check_timestamp_seconds gauge"
        echo "rust_server_health_check_timestamp_seconds $timestamp"
      } >"$output"
      install -o rust-server -g rust-server -m 0640 \
        "$output" "${stateDir}/metrics/rust-server.prom"
      rm -f "$output"

      if [[ "$active" -ne 1 || "$listening" -ne 1 ]]; then
        systemd-cat --identifier=rust-server-health --priority=warning \
          echo "Rust health check failed: active=$active listening=$listening"
        if [[ "''${1:-}" == "strict" ]]; then
          exit 1
        fi
      fi
    '';
  };

  wipeServer = pkgs.writeShellApplication {
    name = "rust-server-wipe";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.bash
      pkgs.systemd
    ];
    text = ''
      if [[ ! -t 0 ]]; then
        echo "rust-server-wipe requires an interactive terminal" >&2
        exit 2
      fi
      echo "This removes the current map/save/player-state files."
      echo "Blueprints, Carbon data, homes, and backpacks are retained."
      read -r -p 'Type WIPE to continue: ' confirmation
      if [[ "$confirmation" != "WIPE" ]]; then
        echo "Wipe cancelled."
        exit 1
      fi

      "${lib.getExe rconCommand}" \
        "say <color=#ff9c8f>Manual map wipe starting in 60 seconds.</color>" ||
        true
      sleep 60
      "${lib.getExe rconCommand}" server.save || true
      sleep 5

      restart_on_failure() {
        systemctl start rust-lan-server.service || true
      }
      trap restart_on_failure EXIT
      systemctl stop rust-lan-server.service
      "${lib.getExe backupServer}" pre-wipe offline

      identity_dir="${serverDir}/server/${identity}"
      rm -f \
        "$identity_dir"/proceduralmap.*.map \
        "$identity_dir"/proceduralmap.*.sav \
        "$identity_dir"/proceduralmap.*.sav.* \
        "$identity_dir"/clans.*.db* \
        "$identity_dir"/player.deaths.*.db* \
        "$identity_dir"/player.identities.*.db* \
        "$identity_dir"/player.states.*.db* \
        "$identity_dir"/player.tokens.db* \
        "$identity_dir"/relationship.*.db* \
        "$identity_dir"/sv.files.*.db*

      systemctl start rust-lan-server.service
      deadline=$((SECONDS + 600))
      until "${lib.getExe healthServer}" strict; do
        if (( SECONDS >= deadline )); then
          echo "Rust server failed its post-wipe health gate" >&2
          exit 1
        fi
        sleep 10
      done
      trap - EXIT
      echo "Wipe complete; blueprints and plugin data were retained."
    '';
  };
in
{
  options.services.rust-lan-server = {
    enable = lib.mkEnableOption "the private Rust LAN server";

    enableCarbon = lib.mkEnableOption "Carbon and the confirmed modded ruleset";

    lanInterface = lib.mkOption {
      type = lib.types.str;
      default = "enp132s0";
      description = "Interface on which the Rust server listens.";
    };

    gamePort = lib.mkOption {
      type = lib.types.port;
      default = 28015;
    };

    rconPort = lib.mkOption {
      type = lib.types.port;
      default = 28016;
    };

    queryPort = lib.mkOption {
      type = lib.types.port;
      default = 28017;
    };

    seed = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 1337;
      description = "Curated size-4000 seed with balanced biomes, dense monuments, caves, roads, and coastline.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.all lib.isInt [
          cfg.gamePort
          cfg.rconPort
          cfg.queryPort
        ];
        message = "Rust server ports must be integers.";
      }
      {
        assertion =
          cfg.gamePort != cfg.rconPort
          && cfg.gamePort != cfg.queryPort
          && cfg.rconPort != cfg.queryPort;
        message = "Rust game, query, and RCON ports must be distinct.";
      }
    ];

    users.groups.rust-server = { };
    users.users.rust-server = {
      isSystemUser = true;
      group = "rust-server";
      home = stateDir;
      createHome = true;
      shell = "${pkgs.shadow}/bin/nologin";
    };

    sops = {
      defaultSopsFile = ./secrets/rust-server.yaml;
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      secrets."rust-server/rcon-password" = {
        owner = "rust-server";
        group = "rust-server";
        mode = "0400";
        restartUnits = [ "rust-lan-server.service" ];
      };
    };

    services.avahi = {
      enable = true;
      nssmdns4 = true;
      allowInterfaces = [ cfg.lanInterface ];
      openFirewall = false;
    };

    networking.firewall.interfaces.${cfg.lanInterface} = {
      allowedUDPPorts = [
        cfg.gamePort
        cfg.queryPort
        5353
      ];
      allowedTCPPorts = [ cfg.rconPort ];
    };

    systemd.tmpfiles.rules = [
      "d ${stateDir} 0750 rust-server rust-server - -"
      "d ${serverDir} 0750 rust-server rust-server - -"
      "d ${stateDir}/backups 0750 rust-server rust-server - -"
      "d ${stateDir}/logs 0750 rust-server rust-server - -"
      "d ${stateDir}/metrics 0750 rust-server rust-server - -"
    ];

    systemd.services.rust-lan-server-install = {
      description = "Install or update the Rust dedicated server";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "rust-server";
        Group = "rust-server";
        Environment = [
          "HOME=${stateDir}"
          "STEAM_HOME=${stateDir}/.steam"
        ];
        ExecStart = lib.getExe installServer;
        UMask = "0027";
        Nice = 5;
      };
    };

    systemd.services.rust-lan-server = {
      description = "Private EAC-disabled Rust LAN server";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "rust-lan-server-install.service"
        "sops-nix.service"
      ];
      wants = [
        "network-online.target"
        "rust-lan-server-install.service"
      ];
      startLimitIntervalSec = 900;
      startLimitBurst = 5;

      serviceConfig = {
        Type = "simple";
        User = "rust-server";
        Group = "rust-server";
        WorkingDirectory = serverDir;
        Environment = [
          "HOME=${stateDir}"
          "DOTNET_CLI_HOME=${stateDir}"
        ];
        ExecStart = lib.getExe startServer;
        Restart = "on-failure";
        RestartSec = "15s";
        TimeoutStartSec = "30min";
        TimeoutStopSec = "5min";
        KillSignal = "SIGINT";
        UMask = "0027";
        LimitNOFILE = 100000;
        MemoryMax = "20G";
        Nice = -5;
        CPUWeight = 750;
        IOWeight = 750;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ stateDir ];
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        LockPersonality = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
        ];
      };
    };

    systemd.services.rust-lan-server-backup = {
      description = "Back up Rust world and persistent plugin data";
      serviceConfig = {
        Type = "oneshot";
        User = "rust-server";
        Group = "rust-server";
        ExecStart = "${lib.getExe backupServer} rolling";
        UMask = "0027";
        Nice = 10;
        IOSchedulingClass = "idle";
      };
    };

    systemd.timers.rust-lan-server-backup = {
      description = "Six-hour Rust server backup schedule";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 00,06,12,18:00:00";
        Persistent = true;
        RandomizedDelaySec = "5m";
        Unit = "rust-lan-server-backup.service";
      };
    };

    systemd.services.rust-lan-server-maintenance = {
      description = "Warn, update, back up, and restart the Rust server";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe maintainServer;
        TimeoutStartSec = "45min";
        UMask = "0027";
      };
    };

    systemd.timers.rust-lan-server-maintenance = {
      description = "Daily Rust update and restart warning schedule";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 03:30:00";
        Persistent = true;
        Unit = "rust-lan-server-maintenance.service";
      };
    };

    systemd.services.rust-lan-server-health = {
      description = "Record and alert on local Rust server health";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe healthServer;
      };
    };

    systemd.timers.rust-lan-server-health = {
      description = "Rust server health check schedule";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5m";
        OnUnitActiveSec = "5m";
        Unit = "rust-lan-server-health.service";
      };
    };

    environment.systemPackages = [
      rconCommand
      backupServer
      wipeServer
    ];

    services.logrotate.settings.rust-lan-server = {
      files = "${stateDir}/logs/*.log";
      frequency = "daily";
      rotate = 30;
      compress = true;
      delaycompress = true;
      missingok = true;
      notifempty = true;
      su = "rust-server rust-server";
    };
  };
}
