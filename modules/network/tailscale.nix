# Tailscale, and one writer for every HTTPS route on the tailnet.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.network.tailscale;
in
{
  options.my.network.tailscale.enable = lib.mkEnableOption "Tailscale";

  config = lib.mkIf cfg.enable {
    services.tailscale.enable = true;

    # One writer for every Tailscale HTTPS route. Separate services used to
    # call `tailscale serve` at the same time, and each call reads and writes
    # one config, so a boot can drop a route. A failed one-shot also stayed
    # failed. tailscaled restores the last good config from its state file;
    # this rewrites that config once the node is actually connected.
    # https://tailscale.com/kb/1242/tailscale-serve
    systemd.services.tailscale-serve = {
      description = "Tailscale HTTPS for local services";
      after = [
        "tailscaled.service"
        "network-online.target"
      ];
      wants = [
        "tailscaled.service"
        "network-online.target"
      ];
      wantedBy = [ "multi-user.target" ];
      # A few minutes of retries when the network is late. A normal boot
      # succeeds on the first attempt. tailscaled also restores the last
      # serve config from its own state.
      startLimitIntervalSec = 900;
      startLimitBurst = 6;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "10s";
        TimeoutStartSec = 150;
        ExecStart = pkgs.writeShellScript "tailscale-serve" ''
          set -euo pipefail
          ts=${pkgs.tailscale}/bin/tailscale
          jq=${pkgs.jq}/bin/jq
          sleep=${pkgs.coreutils}/bin/sleep
          deadline=$((SECONDS + 120))
          until "$ts" status --json | "$jq" -e '.BackendState == "Running"' >/dev/null; do
            if (( SECONDS >= deadline )); then
              echo "tailscaled is not connected yet" >&2
              exit 1
            fi
            "$sleep" 2
          done
          "$ts" serve --bg --yes --https=2283 http://127.0.0.1:2283
          "$ts" serve --bg --yes --https=2586 http://127.0.0.1:2586
          "$ts" serve --bg --yes --https=5678 http://127.0.0.1:5678
          "$ts" serve --bg --yes --https=7575 http://127.0.0.1:7575
          "$ts" serve --bg --yes --https=8081 http://127.0.0.1:8081
          "$ts" serve --bg --yes --https=8082 http://127.0.0.1:8082${lib.optionalString config.my.services.nemotron.enable ''
          "$ts" serve --bg --yes --https=8083 http://127.0.0.1:8083''}
          "$ts" serve --bg --yes --https=8088 http://127.0.0.1:8088
          "$ts" serve --bg --yes --https=11011 http://127.0.0.1:11011
          # Homepage used 3010, Netdata used 19999. tailscaled keeps the last
          # serve config, and `off` errors once that handler is already gone.
          if "$ts" serve status | ${pkgs.gnugrep}/bin/grep -q ':3010'; then
            "$ts" serve --https=3010 --yes off
          fi
          if "$ts" serve status | ${pkgs.gnugrep}/bin/grep -q ':19999'; then
            "$ts" serve --https=19999 --yes off
          fi
          status=$("$ts" serve status)
          for port in 2283 2586 5678 7575 8081 8082${lib.optionalString config.my.services.nemotron.enable " 8083"} 8088 11011; do
            printf '%s\n' "$status" | ${pkgs.gnugrep}/bin/grep -q ":$port" || {
              echo "missing Tailscale serve route for port $port" >&2
              exit 1
            }
          done
        '';
      };
    };
  };
}
