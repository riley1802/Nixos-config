# Tailscale, and one writer for every HTTPS route on the tailnet.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.network.tailscale;
  # One list, so the serve lines, the serve-off lines, and the status
  # check cannot drift. A route with `on = false` is one this machine
  # used to publish. tailscaled keeps it until `serve off`.
  # 3010 was Homepage. 19999 was Netdata.
  # 3000 homelable, 7575 homarr, 8081–8082 llama.cpp,
  # 8084–8085 breeze-tts, 8087 kokoro, 8088 open-webui were retired with those modules.
  routes = [
    { port = 2283; on = config.my.services.immich.enable; }
    { port = 5678; on = config.my.services.n8n.enable; }
    { port = 2586; on = config.my.services.ntfy.enable; }
    { port = 3001; on = config.my.services.uptime-kuma.enable; }
    { port = 8083; on = config.my.services.nemotron.enable; }
    { port = 11011; on = config.my.services.arr.cleanuparr.enable; }
  ];
  active = builtins.filter (route: route.on) routes;
  retiredPortsExplicit = [
    3010
    19999
    3000
    7575
    8081
    8082
    8084
    8085
    8087
    8088
  ];
  retired = retiredPortsExplicit ++ map (route: route.port) (builtins.filter (route: !route.on) routes);
  serveOn = lib.concatMapStrings
    (route: ''
      "$ts" serve --bg --yes --https=${toString route.port} http://127.0.0.1:${toString route.port}
    '')
    active;
  serveOff = lib.concatMapStrings
    (port: ''
      if "$ts" serve status | ${pkgs.gnugrep}/bin/grep -q ':${toString port}'; then
        "$ts" serve --https=${toString port} --yes off
      fi
    '')
    retired;
  activePorts = lib.concatMapStringsSep " " (route: toString route.port) active;
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
        # Optional routes are their own statements. A Nix indented string
        # drops its opening newline, so appending one to the previous
        # command glues the two tailscale invocations into one line.
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
          ${serveOn}
          # `off` errors once that handler is already gone, so check first.
          ${serveOff}
          status=$("$ts" serve status)
          for port in ${activePorts}; do
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
