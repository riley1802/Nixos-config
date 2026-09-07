{ lib, pkgs, ... }:

let
  llamaCpp = pkgs.llama-cpp.override { cudaSupport = true; };
  modelDir = "/home/rileyt/.local/share/llama.cpp/models";
  gemmaModelName = "gemma-4-12B-it-qat-UD-Q4_K_XL.gguf";
  gemmaModelPath = "${modelDir}/${gemmaModelName}";
  gemmaModelRevision = "980b060c40a8539ac159e0501a3e0f66a6365af3";
  gemmaModelSha256 = "90fd44e29e0d7cffeb0fd00dc73cfdab9ed0b0e95306ecf7821ea634c940c370";
  gemmaModelUrl = "https://huggingface.co/unsloth/gemma-4-12B-it-qat-GGUF/resolve/${gemmaModelRevision}/${gemmaModelName}";

  qwenModelName = "Qwen3.5-2B-UD-Q8_K_XL.gguf";
  qwenModelPath = "${modelDir}/${qwenModelName}";
  qwenModelRevision = "e05864f8066d874d5f85aaff007ae57a2a7d1efe";
  qwenModelSha256 = "1eb01bfc3fbb04323e03fe6123d1d396f531474985b5d06e851ddf0522192f52";
  qwenModelUrl = "https://huggingface.co/unsloth/Qwen3.5-2B-MTP-GGUF/resolve/${qwenModelRevision}/${qwenModelName}";

  makeModelFetcher =
    {
      name,
      displayName,
      modelPath,
      modelSha256,
      modelUrl,
    }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        pkgs.coreutils
        pkgs.curl
      ];
      text = ''
        model_path=${lib.escapeShellArg modelPath}
        partial_path="$model_path.part"
        expected_sha=${lib.escapeShellArg modelSha256}

        mkdir -p ${lib.escapeShellArg modelDir}

        if [ -f "$model_path" ]; then
          if echo "$expected_sha  $model_path" | sha256sum --check --status; then
            echo ${lib.escapeShellArg "${displayName} is already present and verified."}
            exit 0
          fi

          echo "Removing model with an invalid checksum: $model_path" >&2
          rm -f "$model_path"
        fi

        curl \
          --fail \
          --location \
          --retry 5 \
          --retry-all-errors \
          --retry-delay 5 \
          --continue-at - \
          --output "$partial_path" \
          ${lib.escapeShellArg modelUrl}

        echo "$expected_sha  $partial_path" | sha256sum --check --status
        chmod 0644 "$partial_path"
        mv -f "$partial_path" "$model_path"
        echo "Installed and verified $model_path"
      '';
    };

  fetchGemmaModel = makeModelFetcher {
    name = "llama-cpp-fetch-gemma4";
    displayName = "Gemma 4 model";
    modelPath = gemmaModelPath;
    modelSha256 = gemmaModelSha256;
    modelUrl = gemmaModelUrl;
  };

  fetchQwenModel = makeModelFetcher {
    name = "llama-cpp-fetch-qwen35";
    displayName = "Qwen 3.5 model";
    modelPath = qwenModelPath;
    modelSha256 = qwenModelSha256;
    modelUrl = qwenModelUrl;
  };

in
{
  environment.systemPackages = [
    llamaCpp
    fetchGemmaModel
    fetchQwenModel
  ];

  systemd.tmpfiles.rules = [
    "d /home/rileyt/.local/share/llama.cpp 0755 rileyt users - -"
    "d ${modelDir} 0755 rileyt users - -"
  ];

  systemd.services.llama-cpp-gemma4-model = {
    description = "Download and verify the Gemma 4 12B GGUF";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "rileyt";
      Group = "users";
      UMask = "0022";
      ExecStart = lib.getExe fetchGemmaModel;
      RemainAfterExit = true;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = false;
      ReadWritePaths = [ modelDir ];
    };
  };

  systemd.services.llama-cpp-gemma4 = {
    description = "Gemma 4 12B llama.cpp server";
    requires = [ "llama-cpp-gemma4-model.service" ];
    after = [ "llama-cpp-gemma4-model.service" ];
    conflicts = [ "llama-cpp-qwen35.service" ];

    serviceConfig = {
      Type = "simple";
      User = "rileyt";
      Group = "users";
      WorkingDirectory = modelDir;
      ExecStart = lib.escapeShellArgs [
        "${llamaCpp}/bin/llama-server"
        "--model"
        gemmaModelPath
        "--alias"
        "gemma-4-12b-it-qat"
        "--host"
        "127.0.0.1"
        "--port"
        "8080"
        "--ctx-size"
        "65536"
        "--parallel"
        "1"
        "--fit"
        "off"
        "--n-gpu-layers"
        "99"
        "--split-mode"
        "layer"
        "--main-gpu"
        "0"
        "--device"
        "CUDA0,CUDA1"
        "--flash-attn"
        "on"
        "--cache-type-k"
        "q8_0"
        "--cache-type-v"
        "q8_0"
        "--threads"
        "8"
        "--batch-size"
        "2048"
        "--ubatch-size"
        "512"
        "--metrics"
      ];
      Restart = "on-failure";
      RestartSec = "5s";
      TimeoutStartSec = "10min";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = false;
      ReadOnlyPaths = [ modelDir ];
    };
  };

  systemd.services.llama-cpp-qwen35-model = {
    description = "Download and verify the Qwen 3.5 2B MTP GGUF";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "rileyt";
      Group = "users";
      UMask = "0022";
      ExecStart = lib.getExe fetchQwenModel;
      RemainAfterExit = true;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = false;
      ReadWritePaths = [ modelDir ];
    };
  };

  systemd.services.llama-cpp-qwen35 = {
    description = "Qwen 3.5 2B MTP llama.cpp server";
    requires = [ "llama-cpp-qwen35-model.service" ];
    after = [ "llama-cpp-qwen35-model.service" ];
    conflicts = [ "llama-cpp-gemma4.service" ];

    serviceConfig = {
      Type = "simple";
      User = "rileyt";
      Group = "users";
      WorkingDirectory = modelDir;
      ExecStart = lib.escapeShellArgs [
        "${llamaCpp}/bin/llama-server"
        "--model"
        qwenModelPath
        "--alias"
        "qwen3.5-2b-mtp"
        "--host"
        "127.0.0.1"
        "--port"
        "8080"
        "--ctx-size"
        "34816"
        "--parallel"
        "1"
        "--fit"
        "off"
        "--n-gpu-layers"
        "99"
        "--split-mode"
        "layer"
        "--main-gpu"
        "0"
        "--device"
        "CUDA0,CUDA1"
        "--flash-attn"
        "on"
        "--cache-type-k"
        "q8_0"
        "--cache-type-v"
        "q8_0"
        "--spec-type"
        "draft-mtp"
        "--spec-draft-n-max"
        "6"
        "--spec-draft-type-k"
        "q8_0"
        "--spec-draft-type-v"
        "q8_0"
        "--threads"
        "8"
        "--batch-size"
        "2048"
        "--ubatch-size"
        "512"
        "--metrics"
      ];
      Restart = "on-failure";
      RestartSec = "5s";
      TimeoutStartSec = "10min";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = false;
      ReadOnlyPaths = [ modelDir ];
    };
  };
}
