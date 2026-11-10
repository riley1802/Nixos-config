# PIA WireGuard split tunnel for qBittorrent and Prowlarr.
{ config, pkgs, lib, ... }:
let
  cfg = config.my.network.pia;
  # Public PIA material. Credentials stay in the agenix secret.
  piaCert = ../../pia/ca.rsa.4096.crt;
  piaServers = ../../pia/pia-servers.json;
  # vancouver438: the first Vancouver server was much slower.
  piaRegion = "ca_vancouver";
  piaServer = "vancouver438";
  # iptables --path. The directory check prefixes /sys/fs/cgroup/.
  prowlarrCgroupPath = "system.slice/prowlarr.service";

  tools = lib.makeBinPath [
    pkgs.coreutils
    pkgs.curl
    pkgs.gawk
    pkgs.gnused
    pkgs.iproute2
    pkgs.jq
    pkgs.wireguard-tools
  ];

  # Secrets reach curl on stdin (`curl -K -`), never on its command line,
  # where every local account could read them with ps.
  curlConfig = ''
    curl_config() {
      local value=$2
      value=''${value//\\/\\\\}
      value=''${value//\"/\\\"}
      printf '%s = "%s"\n' "$1" "$value"
    }
  '';

  # The tunnel only captures traffic sourced from the tunnel address.
  # Desktop traffic keeps the normal route.
  connect = pkgs.writeShellScript "pia-wireguard-connect" ''
    set -euo pipefail
    umask 077
    export PATH=${tools}:$PATH
    ${curlConfig}

    creds=/run/agenix/pia-credentials
    region=${piaRegion}
    server=${piaServer}
    table=51820
    rule_priority=100

    cleanup() {
      trap - ERR
      if ip link show dev pia >/dev/null 2>&1; then
        wg-quick down pia || ip link delete dev pia || true
      fi
    }
    trap cleanup ERR

    if ip link show dev pia >/dev/null 2>&1; then
      wg-quick down pia || ip link delete dev pia
    fi
    ip rule del priority "$rule_priority" 2>/dev/null || true

    read -r meta_cn meta_ip < <(jq -r --arg id "$region" --arg cn "$server" \
      '.regions[] | select(.id == $id) | .servers.meta[] | select(.cn == $cn) | .cn + " " + .ip' \
      ${piaServers})
    read -r wg_cn wg_ip < <(jq -r --arg id "$region" --arg cn "$server" \
      '.regions[] | select(.id == $id) | .servers.wg[] | select(.cn == $cn) | .cn + " " + .ip' \
      ${piaServers})
    test -n "$meta_cn" && test -n "$meta_ip" && test -n "$wg_cn" && test -n "$wg_ip"

    user=$(sed -n '1p' "$creds")
    pass=$(sed -n '2p' "$creds")
    token=$(curl_config user "$user:$pass" | curl -fsS --max-time 20 -K - \
      --connect-to "$meta_cn::$meta_ip:" \
      --cacert ${piaCert} \
      "https://$meta_cn/authv3/generateToken" | jq -er .token)
    unset user pass

    private_key=$(wg genkey)
    public_key=$(printf '%s\n' "$private_key" | wg pubkey)
    key_json=$(curl_config data-urlencode "pt=$token" | curl -fsS --max-time 20 -G -K - \
      --connect-to "$wg_cn::$wg_ip:" \
      --cacert ${piaCert} \
      --data-urlencode "pubkey=$public_key" \
      "https://$wg_cn:1337/addKey")
    unset token public_key

    test "$(jq -r .status <<< "$key_json")" = OK
    peer_ip=$(jq -er .peer_ip <<< "$key_json")
    peer_addr=''${peer_ip%%/*}
    server_key=$(jq -er .server_key <<< "$key_json")
    server_port=$(jq -er .server_port <<< "$key_json")
    # wg-quick runs PostUp through eval as root, so the server's answer
    # must be an address, a WireGuard key, and a port before it goes there.
    if ! [[ $peer_ip =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}(/[0-9]{1,2})?$ &&
      $server_key =~ ^[A-Za-z0-9+/]{43}=$ &&
      $server_port =~ ^[0-9]{1,5}$ ]]; then
      echo "PIA addKey returned an unexpected peer_ip, server_key, or server_port" >&2
      exit 1
    fi

    install -d -m 700 /etc/wireguard
    cat > /etc/wireguard/pia.conf <<EOF
    [Interface]
    Address = $peer_ip
    PrivateKey = $private_key
    Table = $table
    PostUp = ip rule add from $peer_addr/32 lookup $table priority $rule_priority
    PostUp = ip route replace $wg_ip via $(ip -4 route show default | awk 'NR==1 { print $3 }') dev $(ip -4 route show default | awk 'NR==1 { print $5 }') table $table
    PreDown = ip route del $wg_ip table $table || true
    PreDown = ip rule del from $peer_addr/32 lookup $table priority $rule_priority || true

    [Peer]
    PublicKey = $server_key
    AllowedIPs = 0.0.0.0/0
    Endpoint = $wg_ip:$server_port
    PersistentKeepalive = 25
    EOF
    unset private_key key_json
    chmod 600 /etc/wireguard/pia.conf

    wg-quick up pia
    trace=$(curl -fsS --max-time 20 --interface pia https://1.1.1.1/cdn-cgi/trace)
    vpn_ip=$(printf '%s\n' "$trace" | awk -F= '$1 == "ip" { print $2 }')
    vpn_loc=$(printf '%s\n' "$trace" | awk -F= '$1 == "loc" { print $2 }')
    echo "PIA tunnel pia is up via $wg_cn ($wg_ip); qBittorrent source $peer_addr exits at $vpn_ip ($vpn_loc)"
    test "$vpn_loc" = CA
  '';

  # pia is destroyed and created again on every tunnel start, so its index
  # changes. RestrictNetworkInterfaces saved the old index. Restart clients
  # that are already up; on boot they are not up yet, and --no-block returns
  # before they start so this service does not wait on them.
  refreshClients = pkgs.writeShellScript "pia-client-refresh" ''
    set -euo pipefail
    export PATH=${lib.makeBinPath [ pkgs.systemd ]}:$PATH
    systemctl try-restart --no-block prowlarr.service qbittorrent.service
  '';

  disconnect = pkgs.writeShellScript "pia-wireguard-disconnect" ''
    set -euo pipefail
    export PATH=${tools}:$PATH
    if ip link show dev pia >/dev/null 2>&1; then
      wg-quick down pia
    fi
  '';

  # The saved PIA payload contains a token, so it stays in /var/lib/pia,
  # never in this Git repository. A missing file requests one port assignment.
  # Later runs only refresh that assignment; they do not request a replacement.
  refreshPort = pkgs.writeShellScript "pia-port-forward" ''
    set -euo pipefail
    umask 077
    export PATH=${tools}:$PATH
    ${curlConfig}

    state=/var/lib/pia/port-forward.json
    creds=/run/agenix/pia-credentials
    region=${piaRegion}
    server=${piaServer}
    install -d -m 700 /var/lib/pia

    endpoint=$(wg show pia endpoints | awk 'NR == 1 { print $2 }')
    test -n "$endpoint"
    gateway=''${endpoint%:*}
    hostname=$(jq -er --arg id "$region" --arg cn "$server" \
      '.regions[] | select(.id == $id) | .servers.wg[] | select(.cn == $cn) | .cn' \
      ${piaServers})

    if [[ ! -s $state ]]; then
      user=$(sed -n '1p' "$creds")
      pass=$(sed -n '2p' "$creds")
      meta_ip=$(jq -er --arg id "$region" --arg cn "$server" \
        '.regions[] | select(.id == $id) | .servers.meta[] | select(.cn == $cn) | .ip' \
        ${piaServers})
      token=$(curl_config user "$user:$pass" | curl -fsS --max-time 20 -K - \
        --connect-to "$hostname::$meta_ip:" \
        --cacert ${piaCert} \
        "https://$hostname/authv3/generateToken" | jq -er .token)
      unset user pass
      signature_json=$(curl_config data-urlencode "token=$token" | curl -fsS --max-time 20 -G -K - \
        --interface pia \
        --connect-to "$hostname::$gateway:" \
        --cacert ${piaCert} \
        "https://$hostname:19999/getSignature")
      unset token
      test "$(jq -r .status <<< "$signature_json")" = OK
      jq -e '{payload, signature}' <<< "$signature_json" > "$state"
      chmod 600 "$state"
    fi

    payload=$(jq -er .payload "$state")
    signature=$(jq -er .signature "$state")
    port=$(printf '%s' "$payload" | base64 -d | jq -er .port)
    expires_at=$(printf '%s' "$payload" | base64 -d | jq -er .expires_at)
    bind_json=$({
      curl_config data-urlencode "payload=$payload"
      curl_config data-urlencode "signature=$signature"
    } | curl -fsS --max-time 20 -G -K - \
      --interface pia \
      --connect-to "$hostname::$gateway:" \
      --cacert ${piaCert} \
      "https://$hostname:19999/bindPort")
    test "$(jq -r .status <<< "$bind_json")" = OK
    echo "Forwarded port $port refreshed; expires $expires_at"
  '';

  prowlarrVpnRoute = pkgs.writeShellScript "prowlarr-vpn-route" ''
    set -euo pipefail
    export PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.iproute2 pkgs.iptables ]}:$PATH
    cgroup=/sys/fs/cgroup/${prowlarrCgroupPath}
    # Exiting 0 here used to mark the unit successful with no rules, so
    # Prowlarr lookups left through the home connection after a boot race.
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
      [[ -d $cgroup ]] && break
      sleep 0.5
    done
    if [[ ! -d $cgroup ]]; then
      echo "prowlarr cgroup $cgroup is not ready" >&2
      exit 1
    fi
    while iptables -t mangle -D OUTPUT -m cgroup --path ${prowlarrCgroupPath} ! -d 127.0.0.0/8 -p tcp -j MARK --set-mark 0x7072 2>/dev/null; do
      true
    done
    while iptables -t mangle -D OUTPUT -m cgroup --path ${prowlarrCgroupPath} ! -d 127.0.0.0/8 -j MARK --set-mark 0x7072 2>/dev/null; do
      true
    done
    while iptables -t mangle -D OUTPUT -m cgroup --path ${prowlarrCgroupPath} -j PROWLARR-VPN 2>/dev/null; do
      true
    done
    iptables -t mangle -N PROWLARR-VPN 2>/dev/null || true
    iptables -t mangle -F PROWLARR-VPN
    # Localhost and the tailnet stay on the normal route. A reply to a
    # Tailscale browser has to go back over the tailnet. Everything else
    # Prowlarr sends is a lookup and goes through the VPN.
    iptables -t mangle -A PROWLARR-VPN -d 127.0.0.0/8 -j RETURN
    iptables -t mangle -A PROWLARR-VPN -d 100.64.0.0/10 -j RETURN
    iptables -t mangle -A PROWLARR-VPN -j MARK --set-mark 0x7072
    iptables -t mangle -A OUTPUT -m cgroup --path ${prowlarrCgroupPath} -j PROWLARR-VPN
    iptables -t nat -C POSTROUTING -o pia -m mark --mark 0x7072 -j MASQUERADE 2>/dev/null || \
      iptables -t nat -A POSTROUTING -o pia -m mark --mark 0x7072 -j MASQUERADE
    ip rule show | grep -q 'fwmark 0x7072 lookup 51820' || ip rule add fwmark 0x7072 lookup 51820 priority 110
  '';

  prowlarrVpnRouteStop = pkgs.writeShellScript "prowlarr-vpn-route-stop" ''
    set -euo pipefail
    export PATH=${lib.makeBinPath [ pkgs.iproute2 pkgs.iptables ]}:$PATH
    iptables -t mangle -D OUTPUT -m cgroup --path ${prowlarrCgroupPath} ! -d 127.0.0.0/8 -p tcp -j MARK --set-mark 0x7072 2>/dev/null || true
    iptables -t mangle -D OUTPUT -m cgroup --path ${prowlarrCgroupPath} ! -d 127.0.0.0/8 -j MARK --set-mark 0x7072 2>/dev/null || true
    while iptables -t mangle -D OUTPUT -m cgroup --path ${prowlarrCgroupPath} -j PROWLARR-VPN 2>/dev/null; do
      true
    done
    iptables -t mangle -F PROWLARR-VPN 2>/dev/null || true
    iptables -t mangle -X PROWLARR-VPN 2>/dev/null || true
    iptables -t nat -D POSTROUTING -o pia -m mark --mark 0x7072 -j MASQUERADE 2>/dev/null || true
    # Older boots masqueraded the cgroup itself. The start script now
    # masquerades the mark. Delete the old rule if it is still installed.
    iptables -t nat -D POSTROUTING -m cgroup --path ${prowlarrCgroupPath} -o pia -j MASQUERADE 2>/dev/null || true
    ip rule del fwmark 0x7072 lookup 51820 priority 110 2>/dev/null || true
  '';

  # pia-wireguard is a oneshot that stays "active" after the session dies.
  # Prowlarr then times out and disables every indexer. This probe restarts
  # the tunnel, and only a probe that fails and then returns loc=CA clears
  # the backoff. A later healthy tick must not touch the databases.
  piaHealth = pkgs.writeShellScript "pia-health" ''
    set -euo pipefail
    export PATH=${lib.makeBinPath [
      pkgs.coreutils
      pkgs.curl
      pkgs.findutils
      pkgs.gawk
      pkgs.gnused
      pkgs.sqlite
      pkgs.systemd
      pkgs.util-linux
    ]}:$PATH

    exec 9>/run/pia-health.lock
    flock -n 9 || {
      echo "pia-health is already running"
      exit 0
    }

    if [[ $(systemctl show -p ActiveState --value pia-wireguard.service) == activating ]]; then
      echo "pia-wireguard is still starting"
      exit 0
    fi

    probe() {
      local trace loc
      trace=$(curl -4 -fsS --max-time 20 --interface pia https://1.1.1.1/cdn-cgi/trace 2>/dev/null || true)
      loc=$(printf '%s\n' "$trace" | awk -F= '$1 == "loc" { print $2; exit }')
      [[ $loc == CA ]]
    }

    # /var/lib/prowlarr is a symlink into /var/lib/private. find does not
    # follow that unless -H is set, and the first run skipped Prowlarr.
    # The apps then stored a fresh backoff. One healthy tick clears that
    # once; later healthy ticks only probe.
    clear_indexers() {
      local db has owner
      systemctl stop sonarr.service radarr.service lidarr.service prowlarr.service
      while IFS= read -r db; do
        [[ -n $db && -f $db ]] || continue
        has=$(sqlite3 "$db" "SELECT 1 FROM sqlite_master WHERE type='table' AND name='IndexerStatus' LIMIT 1;" || true)
        [[ $has == 1 ]] || continue
        owner=$(stat -c %U "$db")
        echo "clearing IndexerStatus in $db"
        runuser -u "$owner" -- sqlite3 "$db" "DELETE FROM IndexerStatus;" || echo "could not clear $db"
      done < <(find -H /var/lib/prowlarr /var/lib/sonarr /var/lib/radarr /var/lib/lidarr -name '*.db' -type f 2>/dev/null || true)

      # Prowlarr has to be answering before the apps start, or their startup
      # RSS records another long backoff.
      systemctl start prowlarr.service
      for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
        if curl -fsS -o /dev/null --max-time 3 http://127.0.0.1:9696/ping; then
          break
        fi
        sleep 2
      done
      systemctl start sonarr.service radarr.service lidarr.service
    }

    # Sonarr 4 and Radarr 6 take commands on /api/v3. Lidarr still uses v1.
    # The key stays in the process and is never printed.
    trigger_rss() {
      local name=$1 port=$2 root=$3 api=$4 cfg key code i
      cfg=$(find -H "$root" -name config.xml -type f -print -quit 2>/dev/null || true)
      if [[ -z $cfg ]]; then
        echo "no config.xml under $root; skipped $name"
        return 0
      fi
      key=$(awk -F '[<>]' '/<ApiKey>/ { print $3; exit }' "$cfg")
      if [[ -z $key ]]; then
        echo "no api key for $name; skipped"
        return 0
      fi
      for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
        if curl -fsS -o /dev/null --max-time 3 "http://127.0.0.1:''${port}/ping"; then
          break
        fi
        sleep 2
      done
      code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 30 -X POST \
        -H 'Content-Type: application/json' \
        -H "X-Api-Key: $key" \
        -d '{"name":"RssSync"}' \
        "http://127.0.0.1:''${port}/api/''${api}/command" || true)
      unset key
      echo "$name rss sync http $code"
    }

    stamp=/var/lib/pia/arr-indexer-backoff-cleared
    if probe; then
      if [[ ! -f $stamp ]]; then
        echo "clearing indexer backoff once; Prowlarr's database was skipped"
        clear_indexers
        trigger_rss sonarr 8989 /var/lib/sonarr v3
        trigger_rss radarr 7878 /var/lib/radarr v3
        trigger_rss lidarr 8686 /var/lib/lidarr v1
        install -d -m 700 /var/lib/pia
        : > "$stamp"
      fi
      echo "PIA tunnel is passing traffic (loc=CA)"
      exit 0
    fi

    echo "PIA tunnel is not passing traffic; restarting pia-wireguard"
    before=$(systemctl show -p ExecMainStartTimestamp --value pia-wireguard.service)
    systemctl reset-failed pia-wireguard.service >/dev/null 2>&1 || true
    systemctl restart --no-block pia-wireguard.service || true

    recovered=0
    probes=0
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60; do
      state=$(systemctl show -p ActiveState --value pia-wireguard.service)
      started=$(systemctl show -p ExecMainStartTimestamp --value pia-wireguard.service)
      if [[ $state == failed ]]; then
        break
      fi
      if [[ $state == active && -n $started && $started != "$before" ]]; then
        probes=$((probes + 1))
        if probe; then
          recovered=1
          break
        fi
        [[ $probes -ge 3 ]] && break
      fi
      sleep 2
    done

    if [[ $recovered != 1 ]]; then
      systemctl reset-failed pia-wireguard.service >/dev/null 2>&1 || true
      echo "PIA tunnel did not recover; will try again on the next check"
      exit 0
    fi

    echo "PIA tunnel recovered; clearing indexer failure backoff"
    # The refresh unit restarts qBittorrent. The apps are stopped inside
    # clear_indexers so sqlite is not open.
    systemctl start pia-client-refresh.service || true
    clear_indexers
    trigger_rss sonarr 8989 /var/lib/sonarr v3
    trigger_rss radarr 7878 /var/lib/radarr v3
    trigger_rss lidarr 8686 /var/lib/lidarr v1
    install -d -m 700 /var/lib/pia
    : > "$stamp"

    if systemctl start pia-port-forward.service; then
      echo "forwarded port refreshed"
    else
      echo "port-forward refresh failed"
    fi
  '';
in
{
  options.my.network.pia.enable = lib.mkEnableOption "PIA WireGuard split tunnel";

  config = lib.mkIf cfg.enable {
    age.secrets."pia-credentials" = {
      file = ../../secrets/pia-credentials.age;
      mode = "0400";
      owner = "root";
      group = "root";
    };

    # Torrent replies arrive through pia while normal traffic still uses the
    # router, so strict reverse-path filtering would drop the torrent replies.
    networking.firewall.checkReversePath = "loose";

    systemd.services.pia-wireguard = {
      description = "PIA WireGuard tunnel for qBittorrent and Prowlarr";
      wantedBy = [ "multi-user.target" ];
      wants = [
        "network-online.target"
        "pia-client-refresh.service"
        # Bind the forwarded port once the interface exists. The timer below
        # keeps refreshing it; this covers the first bind at boot.
        "pia-port-forward.service"
      ];
      after = [ "network-online.target" ];
      before = [
        "pia-client-refresh.service"
        "pia-port-forward.service"
      ];
      startLimitIntervalSec = 300;
      startLimitBurst = 5;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = 90;
        Restart = "on-failure";
        RestartSec = "15s";
        ExecStart = connect;
        ExecStop = disconnect;
      };
    };

    systemd.services.pia-client-refresh = {
      description = "Restart VPN clients after the pia interface is created";
      after = [ "pia-wireguard.service" ];
      requires = [ "pia-wireguard.service" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = refreshClients;
      };
    };

    # Interface = pia binds the torrent traffic. This also covers qBittorrent's
    # own HTTP requests (RSS, .torrent URLs), which do not use that binding.
    # after pia-client-refresh: that oneshot restarts this service when pia
    # already existed, then this start records the new interface index.
    # RestrictNetworkInterfaces resolves names once, at start. tailscale0
    # has to exist by then or the WebUI is unreachable on the tailnet until
    # the process is restarted.
    # mkAfter keeps these after the media-directory dependency. The unit
    # file lists that one first, then the tunnel.
    systemd.services.qbittorrent = {
      wants = lib.mkAfter [
        "pia-wireguard.service"
        "sys-subsystem-net-devices-tailscale0.device"
      ];
      after = lib.mkAfter [
        "pia-wireguard.service"
        "pia-client-refresh.service"
        "tailscaled.service"
        "sys-subsystem-net-devices-tailscale0.device"
      ];
      serviceConfig = {
        RestrictNetworkInterfaces = [ "lo" "pia" "tailscale0" ];
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    systemd.services.prowlarr-vpn-route = {
      description = "Send Prowlarr lookups through the VPN";
      after = [ "prowlarr.service" "pia-wireguard.service" "firewall.service" ];
      wants = [ "pia-wireguard.service" ];
      partOf = [ "prowlarr.service" ];
      startLimitIntervalSec = 60;
      startLimitBurst = 10;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "2s";
        ExecStart = prowlarrVpnRoute;
        ExecStop = prowlarrVpnRouteStop;
      };
    };

    # Kill switch. The mark above only works while table 51820 has a route
    # and only covers IPv4. Anything that would leave through the home
    # interface instead (tunnel down, startup before the mark, IPv6) is
    # dropped. Loopback reaches the other apps and DNS; tailscale0 serves the
    # web pages to the tailnet.
    # RestrictNetworkInterfaces resolves interface names once, at start. If pia
    # does not exist yet, systemd omits it for the life of the process, so
    # this unit waits until the tunnel service has created the interface.
    # pia-client-refresh restarts the process when that interface is replaced.
    systemd.services.prowlarr = {
      wants = [
        "prowlarr-vpn-route.service"
        "pia-wireguard.service"
        "sys-subsystem-net-devices-tailscale0.device"
      ];
      after = [
        "pia-wireguard.service"
        "pia-client-refresh.service"
        "tailscaled.service"
        "sys-subsystem-net-devices-tailscale0.device"
      ];
      before = [ "prowlarr-vpn-route.service" ];
      serviceConfig.RestrictNetworkInterfaces = [ "lo" "pia" "tailscale0" ];
    };

    systemd.services.pia-port-forward = {
      description = "Refresh the PIA forwarded-port binding";
      after = [ "pia-wireguard.service" ];
      requires = [ "pia-wireguard.service" ];
      serviceConfig = {
        Type = "oneshot";
        # Includes waiting for the tunnel, which retries for a few minutes
        # when the network is late.
        TimeoutStartSec = 180;
        ExecStart = refreshPort;
      };
    };

    systemd.timers.pia-port-forward = {
      description = "Refresh the PIA forwarded port every 15 minutes";
      wantedBy = [ "timers.target" ];
      # OnBootSec plus OnUnitActiveSec can come up already elapsed: the boot
      # delay is in the past if this unit starts late, and OnUnitActiveSec
      # cannot arm until the oneshot has run once. A calendar spec always has
      # a future elapse. Persistent runs one missed slot if the timer was
      # inactive (machine off), which monotonic timers do not.
      # https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html#OnCalendar=
      timerConfig = {
        OnCalendar = "*:0/15";
        AccuracySec = "30s";
        Persistent = true;
      };
    };

    # Runs once when this unit is started, then every 5 minutes. A calendar
    # spec stays in the future when the timer is installed on a long-running
    # boot. The service itself is what runs during switch.
    # https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html#OnCalendar=
    systemd.services.pia-health = {
      description = "Reconnect PIA when the tunnel stops passing traffic";
      after = [ "pia-wireguard.service" ];
      wants = [ "pia-wireguard.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = 600;
        ExecStart = piaHealth;
      };
    };

    systemd.timers.pia-health = {
      description = "Check the PIA tunnel every 5 minutes";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/5";
        AccuracySec = "30s";
      };
    };
  };
}
