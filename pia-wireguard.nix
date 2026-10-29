{ pkgs, lib, ... }:
let
  # Public PIA material. Credentials stay in the agenix secret.
  piaCert = ./pia/ca.rsa.4096.crt;
  piaServers = ./pia/pia-servers.json;
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
    export PATH=${lib.makeBinPath [ pkgs.iproute2 pkgs.iptables ]}:$PATH
    cgroup=/sys/fs/cgroup/${prowlarrCgroupPath}
    if [[ ! -d $cgroup ]]; then
      exit 0
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
    # Tailscale browser has to go back over the tailnet; everything else
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
    iptables -t nat -D POSTROUTING -m cgroup --path ${prowlarrCgroupPath} -o pia -j MASQUERADE 2>/dev/null || true
    ip rule del fwmark 0x7072 lookup 51820 priority 110 2>/dev/null || true
  '';
in
{
  # Torrent replies arrive through pia while normal traffic still uses the
  # router, so strict reverse-path filtering would drop the torrent replies.
  networking.firewall.checkReversePath = "loose";

  systemd.services.pia-wireguard = {
    description = "PIA WireGuard tunnel for qBittorrent";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
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

  # Interface = pia binds the torrent traffic. This also covers qBittorrent's
  # own HTTP requests (RSS, .torrent URLs), which do not use that binding.
  systemd.services.qbittorrent = {
    wants = [ "pia-wireguard.service" ];
    after = [ "pia-wireguard.service" ];
    serviceConfig.RestrictNetworkInterfaces = [ "lo" "pia" "tailscale0" ];
  };

  systemd.services.prowlarr-vpn-route = {
    description = "Send Prowlarr lookups through the VPN";
    after = [ "prowlarr.service" "pia-wireguard.service" "firewall.service" ];
    wants = [ "pia-wireguard.service" ];
    partOf = [ "prowlarr.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = prowlarrVpnRoute;
      ExecStop = prowlarrVpnRouteStop;
    };
  };

  # Kill switch. The mark above only works while table 51820 has a route
  # and only covers IPv4. Anything that would leave through the home
  # interface instead (tunnel down, startup before the mark, IPv6) is
  # dropped. Loopback reaches the other apps and DNS; tailscale0 serves the
  # web pages to the tailnet.
  systemd.services.prowlarr = {
    wants = [ "prowlarr-vpn-route.service" ];
    before = [ "prowlarr-vpn-route.service" ];
    serviceConfig.RestrictNetworkInterfaces = [ "lo" "pia" "tailscale0" ];
  };

  systemd.services.pia-port-forward = {
    description = "Refresh the PIA forwarded-port binding";
    after = [ "pia-wireguard.service" ];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = 60;
      ExecStart = refreshPort;
    };
  };

  systemd.timers.pia-port-forward = {
    description = "Refresh the PIA forwarded port every 15 minutes";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "15min";
      AccuracySec = "30s";
      Persistent = true;
    };
  };
}
