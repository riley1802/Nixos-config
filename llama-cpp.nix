{ lib, pkgs, ... }:

let
  llamaCpp = pkgs.llama-cpp.override { cudaSupport = true; };
  modelDir = "/home/rileyt/.local/share/llama.cpp/models";
  modelName = "gemma-4-12B-it-qat-UD-Q4_K_XL.gguf";
  modelPath = "${modelDir}/${modelName}";
  modelRevision = "980b060c40a8539ac159e0501a3e0f66a6365af3";
  modelSha256 = "90fd44e29e0d7cffeb0fd00dc73cfdab9ed0b0e95306ecf7821ea634c940c370";
  modelUrl = "https://huggingface.co/unsloth/gemma-4-12B-it-qat-GGUF/resolve/${modelRevision}/${modelName}";

  fetchModel = pkgs.writeShellApplication {
    name = "llama-cpp-fetch-gemma4";
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
          echo "Gemma 4 model is already present and verified."
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

in
{
  environment.systemPackages = [
    llamaCpp
    fetchModel
  ];

  systemd.tmpfiles.rules = [
    "d /home/rileyt/.local/share/llama.cpp 0755 rileyt users - -"
    "d ${modelDir} 0755 rileyt users - -"
  ];

  systemd.services.llama-cpp-gemma4-model = {
    description = "Download and verify the Gemma 4 12B GGUF";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "rileyt";
      Group = "users";
      UMask = "0022";
      ExecStart = lib.getExe fetchModel;
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
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "rileyt";
      Group = "users";
      WorkingDirectory = modelDir;
      ExecStart = lib.escapeShellArgs [
        "${llamaCpp}/bin/llama-server"
        "--model"
        modelPath
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
}
