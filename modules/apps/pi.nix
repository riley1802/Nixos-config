# Pi coding agent, using the Nemotron server on port 8083.
# Config is /etc/nixos/pi so it is in this repo. PI_CODING_AGENT_DIR makes
# that the agent directory from any working directory.
# https://pi.dev/docs/latest/configuration
{ config, lib, pkgs, ... }:
let
  cfg = config.my.apps.pi;
  agentDir = "/etc/nixos/pi";
  sessionDir = "/home/${config.my.user}/.local/state/pi/sessions";

  piNemotronKey = pkgs.writeShellApplication {
    name = "pi-nemotron-key";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      tr -d '\n\r' < /run/agenix/llama-api-key
    '';
  };

  # The store binary defaults to ~/.pi/agent. This wrapper is the `pi` on
  # PATH, so a shell that never sourced /etc/profile still uses the repo.
  pi = pkgs.writeShellScriptBin "pi" ''
    export PI_CODING_AGENT_DIR=${agentDir}
    export PI_CODING_AGENT_SESSION_DIR=${sessionDir}
    exec ${lib.getExe pkgs.pi-coding-agent} "$@"
  '';
in
{
  options.my.apps.pi.enable = lib.mkEnableOption "Pi coding agent on Nemotron";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.services.nemotron.enable;
        message = "apps/pi needs services/nemotron (nixctl enable services/nemotron)";
      }
    ];

    environment.sessionVariables = {
      PI_CODING_AGENT_DIR = agentDir;
      PI_CODING_AGENT_SESSION_DIR = sessionDir;
    };

    environment.systemPackages = [
      pi
      piNemotronKey
    ];
  };
}
