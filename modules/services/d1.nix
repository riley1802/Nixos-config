# Liquid AI d1-2B decision server on port 8086.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.d1;
  models = "/var/lib/llama-cpp/models";
  modelFile = "d1-2B-Q8_0.gguf";
  cpuThreads = 12;
  server = "${pkgs.llama-cpp}/bin/llama-server";
  llamaExec = name: args:
    pkgs.writeShellScript name ''
      set -euo pipefail
      exec ${lib.escapeShellArgs args} --api-key-file "''${CREDENTIALS_DIRECTORY}/llama-api-key"
    '';
in
{
  options.my.services.d1.enable = lib.mkEnableOption "Liquid AI d1-2B decision server on port 8086";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.services.llama.enable;
        message = "services/d1 needs services/llama (nixctl enable services/llama)";
      }
    ];

    # Liquid d1-2B routes and classifies with POST /v1/systemone, not chat.
    # Text-only Q8_0 weights (~1.85 GiB). CPU-only so the GPUs stay on Omni
    # and Nemotron. Loopback on 8086 only; no Tailscale Serve or Open WebUI.
    # https://huggingface.co/LiquidAI/d1-2B-GGUF
    system.activationScripts.d1-model.text = ''
      install -d -m 0755 /var/lib/llama-cpp/models /var/lib/llama-cpp/cache
      src=/home/${config.my.user}/llama-models
      f=${modelFile}
      if [[ -f $src/$f ]]; then
        if [[ ! -f /var/lib/llama-cpp/models/$f ]] || ! ${pkgs.diffutils}/bin/cmp -s "$src/$f" "/var/lib/llama-cpp/models/$f"; then
          cp -a "$src/$f" "/var/lib/llama-cpp/models/$f"
          chmod 644 "/var/lib/llama-cpp/models/$f"
        fi
      fi
    '';

    systemd.services.llama-cpp-d1 = {
      description = "llama.cpp server for Liquid AI d1-2B";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ config.age.secrets.llama-api-key.file ];
      unitConfig.ConditionPathExists = "${models}/${modelFile}";
      environment = {
        CUDA_VISIBLE_DEVICES = "";
        LLAMA_CACHE = "/var/lib/llama-cpp/cache";
      };
      serviceConfig = {
        User = "llama";
        Group = "llama";
        WorkingDirectory = "/var/lib/llama-cpp";
        LoadCredential = [
          "llama-api-key:${config.age.secrets.llama-api-key.path}"
        ];
        ExecStart = llamaExec "llama-cpp-d1" [
          server
          "--host"
          "127.0.0.1"
          "--port"
          "8086"
          "-m"
          "${models}/${modelFile}"
          "--alias"
          "d1-2b"
          "-c"
          "8192"
          "-b"
          "8192"
          "-ub"
          "8192"
          "-np"
          "1"
          "-ngl"
          "0"
          "--device"
          "none"
          "--fit"
          "off"
          "-t"
          (toString cpuThreads)
          "--cache-type-k"
          "q8_0"
          "--cache-type-v"
          "q8_0"
          "--flash-attn"
          "on"
        ];
        Restart = "on-failure";
        RestartSec = 5;
        KillSignal = "SIGINT";
        MemoryDenyWriteExecute = false;
        PrivateUsers = false;
        PrivateDevices = true;
      };
    };
  };
}
