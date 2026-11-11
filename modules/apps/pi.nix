# Pi coding agent, using the Nemotron server on port 8083.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.apps.pi;

  skillFull = builtins.readFile ../../agent/nixos-managing/SKILL.md;
  skillPart1 = builtins.head (lib.splitString "\n<!-- END OF CORE" skillFull);

  piNemotronKey = pkgs.writeShellApplication {
    name = "pi-nemotron-key";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      tr -d '\n\r' < /run/agenix/llama-api-key
    '';
  };

  piModelsJson = pkgs.writeText "pi-models.json" ''
    {
      "$schema": "https://pi.dev/schemas/models.schema.json",
      "providers": {
        "nemotron": {
          "name": "Nemotron",
          "baseUrl": "http://127.0.0.1:8083/v1",
          "api": "openai-completions",
          "apiKey": "!/run/current-system/sw/bin/pi-nemotron-key",
          "authHeader": true,
          "models": [
            {
              "id": "nemotron-bolt",
              "name": "Nemotron 3.5 Bolt",
              "reasoning": true,
              "input": ["text"],
              "contextWindow": 32768,
              "maxTokens": 8192,
              "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
              "samplingParams": { "temperature": 1.0, "top_p": 0.95 }
            }
          ]
        }
      }
    }
  '';

  piSkillMd = pkgs.writeText "nixos-managing-SKILL.md" skillPart1;

  piSettingsJson = pkgs.writeText "pi-settings.json" ''
    {
      "$schema": "https://pi.dev/schemas/settings.schema.json",
      "defaultProvider": "nemotron",
      "defaultModel": "nemotron-bolt",
      "extensions": ["-builtin:llama.cpp"]
    }
  '';

  piAppendSystemMd = pkgs.writeText "pi-APPEND_SYSTEM.md" ''
    For changes to this computer, follow the nixos-managing skill. Start with nixctl map. Force it with /skill:nixos-managing.
  '';

  piAgentSeed = pkgs.writeShellApplication {
    name = "pi-agent-seed";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      set -euo pipefail
      home=/home/${config.my.user}
      agent="$home/.pi/agent"
      mkdir -p "$agent/skills/nixos-managing"
      cp -f ${piModelsJson} "$agent/models.json"
      cp -f ${piSkillMd} "$agent/skills/nixos-managing/SKILL.md"
      if [[ ! -f "$agent/settings.json" ]]; then
        cp -f ${piSettingsJson} "$agent/settings.json"
      fi
      if [[ ! -f "$agent/APPEND_SYSTEM.md" ]]; then
        cp -f ${piAppendSystemMd} "$agent/APPEND_SYSTEM.md"
      fi
    '';
  };
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

    environment.systemPackages = [
      pkgs.pi-coding-agent
      piNemotronKey
    ];

    systemd.services.pi-agent-seed = {
      description = "Seed Pi agent config for Nemotron";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = config.my.user;
        ExecStart = "${piAgentSeed}/bin/pi-agent-seed";
      };
    };
  };
}
