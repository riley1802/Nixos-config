{ config, lib, pkgsUnstable, ... }:

let
  llamaCppCuda = pkgsUnstable.llama-cpp.override {
    cudaSupport = true;
  };
  gpuCount = builtins.length config.host.gpus;
in
{
  systemd.tmpfiles.rules = [
    "d /var/lib/llama-cpp/models 0755 rileyt users -"
  ];

  environment.systemPackages = [
    llamaCppCuda
  ];

  systemd.services.llama-cpp.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "rileyt";
    Group = "users";
    Environment = lib.mkForce [
      "LLAMA_CACHE=/var/lib/llama-cpp/models"
    ];
  };

  services.llama-cpp = {
    enable = true;
    package = llamaCppCuda;

    host = "127.0.0.1";
    port = 8080;
    openFirewall = false;
    modelsDir = "/var/lib/llama-cpp/models";

    modelsPreset = {
      "gemma-4-e4b-q8" = {
        "hf-repo" = "unsloth/gemma-4-E4B-it-GGUF";
        "hf-file" = "gemma-4-E4B-it-Q8_0.gguf";
        alias = "gemma-4-e4b-q8";
        jinja = "on";
      };

      "nemotron-nano-12b-v2-q4" = {
        "hf-repo" = "MaziyarPanahi/NVIDIA-Nemotron-Nano-12B-v2-GGUF";
        "hf-file" = "NVIDIA-Nemotron-Nano-12B-v2.Q4_K_M.gguf";
        alias = "nemotron-nano-12b-v2-q4";
        jinja = "on";
      };

      "gemma-4-12b-q4-mtp" = {
        "hf-repo" = "unsloth/gemma-4-12b-it-GGUF";
        "hf-file" = "gemma-4-12b-it-Q4_K_M.gguf";
        alias = "gemma-4-12b-q4-mtp";
        jinja = "on";
        "spec-type" = "draft-mtp";
        "spec-draft-n-max" = "2";
      };
    };

    extraFlags = [
      # Only one model fits in VRAM; evict the loaded model before switching
      # instead of OOMing on a second instance.
      "--models-max"
      "1"
      "--n-gpu-layers"
      "999"
      "--flash-attn"
      "on"
      # 16k context; q8_0 KV cache is higher fidelity than q4_0.
      "--ctx-size"
      "16384"
      "--cache-type-k"
      "q8_0"
      "--cache-type-v"
      "q8_0"
      "--parallel"
      "1"
      "--kv-unified"
      "--sleep-idle-seconds"
      "1800"
    ] ++ lib.optionals (gpuCount > 1) [
      # Split layers across all GPUs (desktop only).
      "--split-mode"
      "layer"
      "--tensor-split"
      (lib.concatStringsSep "," (map (_: "1") config.host.gpus))
      "--main-gpu"
      "0"
    ];
  };

}
