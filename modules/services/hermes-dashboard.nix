{ config, inputs, lib, pkgs, ... }:

let
  cfg = config.services.hermes-dashboard;
  agentCfg = config.services.hermes-agent;
  hermesPkg = agentCfg.package;
in
{
  options.services.hermes-dashboard = {
    enable = lib.mkEnableOption "Hermes Agent web dashboard (localhost UI on port 9119)";

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Bind address. Keep on loopback unless you add auth and a reverse proxy.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9119;
      description = "Dashboard HTTP port.";
    };
  };

  config = lib.mkIf (cfg.enable && agentCfg.enable) {
    systemd.services.hermes-dashboard = {
      description = "Hermes Agent Web Dashboard";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network-online.target"
        "hermes-agent.service"
      ];
      wants = [ "network-online.target" ];

      environment = {
        HOME = agentCfg.stateDir;
        HERMES_HOME = "${agentCfg.stateDir}/.hermes";
        HERMES_MANAGED = "true";
      };

      serviceConfig = {
        User = agentCfg.user;
        Group = agentCfg.group;
        WorkingDirectory = agentCfg.workingDirectory;

        ExecStart = lib.concatStringsSep " " [
          "${hermesPkg}/bin/hermes"
          "dashboard"
          "--host"
          cfg.host
          "--port"
          "${toString cfg.port}"
          "--no-open"
        ];

        Restart = "on-failure";
        RestartSec = 5;

        UMask = "0007";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = false;
        ReadWritePaths = [
          agentCfg.stateDir
          agentCfg.workingDirectory
        ];
        PrivateTmp = true;
      };
    };
  };
}
