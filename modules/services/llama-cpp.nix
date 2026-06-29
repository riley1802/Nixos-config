{ lib, pkgsUnstable, ... }:

let
  llamaCppCuda = pkgsUnstable.llama-cpp.override {
    cudaSupport = true;
  };
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
      "--n-gpu-layers"
      "999"
      "--flash-attn"
      "on"
      "--ctx-size"
      "4096"
      "--parallel"
      "1"
      "--split-mode"
      "layer"
      "--tensor-split"
      "1,1"
      "--main-gpu"
      "0"
    ];
  };

}
