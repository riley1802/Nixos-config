# EmbeddingGemma 2 Q8_0 embeddings via llama.cpp. Loopback on port 8090.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.embeddinggemma;
  server = "${pkgs.llama-cpp}/bin/llama-server";
  # Text-only Q8_0 from ggml-org. Verified sha256 on 2026-11-05.
  # https://huggingface.co/ggml-org/embeddinggemma-2-GGUF
  model = pkgs.fetchurl {
    url = "https://huggingface.co/ggml-org/embeddinggemma-2-GGUF/resolve/main/embeddinggemma-2-Q8_0.gguf";
    hash = "sha256-IYisHeykt33/79YDwndqnXbZ107AGEE5KYLruECwkTU=";
  };
  llamaExec = name: args:
    pkgs.writeShellScript name ''
      set -euo pipefail
      exec ${lib.escapeShellArgs args} --api-key-file "''${CREDENTIALS_DIRECTORY}/llama-api-key"
    '';
in
{
  options.my.services.embeddinggemma.enable =
    lib.mkEnableOption "EmbeddingGemma 2 llama.cpp embedding server";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.services.llama.enable;
        message = "services/embeddinggemma needs services/llama (nixctl enable services/llama)";
      }
    ];

    # CPU-only on loopback. The 3050 runs LFM3-Omni and the desktop; the
    # 1660 is the gtx1660 switch. Open WebUI RAG uses the OpenAI-compatible
    # /v1/embeddings endpoint with model alias embeddinggemma-2.
    # https://huggingface.co/google/embeddinggemma-2
    systemd.services.llama-cpp-embeddinggemma = {
      description = "llama.cpp server for EmbeddingGemma 2 embeddings";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ config.age.secrets.llama-api-key.file ];
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
        ExecStart = llamaExec "llama-cpp-embeddinggemma" [
          server
          "--host"
          "127.0.0.1"
          "--port"
          "8090"
          "-m"
          model
          "--alias"
          "embeddinggemma-2"
          "--embeddings"
          "--pooling"
          "mean"
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
          "8"
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
