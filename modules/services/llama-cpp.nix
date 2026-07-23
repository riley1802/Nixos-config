{ config
, lib
, pkgs
, pkgsUnstable
, utils
, ...
}:

# Research-loop llama.cpp stack:
# - Dual GPU (desktop): Nemotron :8084 (GPU0) + Qwen :8085 (GPU1) always-on;
#   Phi :8080 (both GPUs) exclusive — `llama-cpp-mode phi|dual`.
# - Single GPU (legion): one router on :8080 with all aliases, models-max 1.
#
# Tuned flag winners live in `tuned` below (Composer/llama-bench hardcodes).

let
  llamaCppCuda = pkgsUnstable.llama-cpp.override {
    cudaSupport = true;
  };
  llamaServer = lib.getExe' llamaCppCuda "llama-server";
  modelsDir = "/var/lib/llama-cpp/models";
  gpuCount = builtins.length config.host.gpus;
  dualGpu = gpuCount >= 2;

  # --- Tuned winners (update after benchmark sweeps) ---
  tuned = {
    flashAttn = "on";
    nGpuLayers = "999";
    parallel = "1";
    cacheTypeK = "q4_0";
    cacheTypeV = "q4_0";
    kvUnified = true;
    # Phi frees VRAM after idle; watcher then restores dual.
    phiSleepIdleSeconds = "300";
    dualSleepIdleSeconds = "1800";
    qwenSpecDraftNMax = "6";
  };

  commonFlags = [
    "--models-max"
    "1"
    "--n-gpu-layers"
    tuned.nGpuLayers
    "--flash-attn"
    tuned.flashAttn
    "--cache-type-k"
    tuned.cacheTypeK
    "--cache-type-v"
    tuned.cacheTypeV
    "--parallel"
    tuned.parallel
  ]
  ++ lib.optionals tuned.kvUnified [ "--kv-unified" ];

  mkPreset =
    { alias
    , hfRepo
    , hfFile
    , ctx
    , extra ? { }
    ,
    }:
    {
      "hf-repo" = hfRepo;
      "hf-file" = hfFile;
      inherit alias;
      jinja = "on";
      "ctx-size" = toString ctx;
    }
    // extra;

  phiRepo = "unsloth/Phi-4-reasoning-plus-GGUF";
  phiFile = "Phi-4-reasoning-plus-UD-Q4_K_XL.gguf";
  nemoRepo = "unsloth/NVIDIA-Nemotron-3-Nano-4B-GGUF";
  nemoFile = "NVIDIA-Nemotron-3-Nano-4B-UD-Q4_K_XL.gguf";
  qwenRepo = "unsloth/Qwen3.5-4B-MTP-GGUF";
  qwenFile = "Qwen3.5-4B-UD-Q4_K_XL.gguf";

  mtpExtra = {
    "spec-type" = "draft-mtp";
    "spec-draft-n-max" = tuned.qwenSpecDraftNMax;
  };

  phiPresets = {
    "phi4-8k" = mkPreset {
      alias = "phi4-8k";
      hfRepo = phiRepo;
      hfFile = phiFile;
      ctx = 8192;
    };
    "phi4-16k" = mkPreset {
      alias = "phi4-16k";
      hfRepo = phiRepo;
      hfFile = phiFile;
      ctx = 16384;
    };
  };

  nemoPresets = {
    "nemotron-8k" = mkPreset {
      alias = "nemotron-8k";
      hfRepo = nemoRepo;
      hfFile = nemoFile;
      ctx = 8192;
    };
    "nemotron-16k" = mkPreset {
      alias = "nemotron-16k";
      hfRepo = nemoRepo;
      hfFile = nemoFile;
      ctx = 16384;
    };
  };

  qwenPresets = {
    "qwen-8k" = mkPreset {
      alias = "qwen-8k";
      hfRepo = qwenRepo;
      hfFile = qwenFile;
      ctx = 8192;
      extra = mtpExtra;
    };
    "qwen-16k" = mkPreset {
      alias = "qwen-16k";
      hfRepo = qwenRepo;
      hfFile = qwenFile;
      ctx = 16384;
      extra = mtpExtra;
    };
  };

  mkPresetFile = name: presets: pkgs.writeText "llama-${name}.ini" (lib.generators.toINI { } presets);

  mkService =
    { name
    , port
    , presets
    , extraFlags ? [ ]
    , sleepIdle
    , wantedBy ? [ ]
    ,
    }:
    {
      description = "llama.cpp ${name}";
      after = [ "network.target" ];
      inherit wantedBy;
      serviceConfig = {
        Type = "idle";
        KillSignal = "SIGINT";
        User = "rileyt";
        Group = "users";
        WorkingDirectory = "/var/lib/llama-cpp";
        Environment = [ "LLAMA_CACHE=${modelsDir}" ];
        ExecStart =
          let
            args = [
              "--host"
              "127.0.0.1"
              "--port"
              (toString port)
              "--models-dir"
              modelsDir
              "--models-preset"
              (mkPresetFile name presets)
              "--sleep-idle-seconds"
              sleepIdle
            ]
            ++ commonFlags
            ++ extraFlags;
          in
          "${llamaServer} ${utils.escapeSystemdExecArgs args}";
        Restart = "on-failure";
        RestartSec = 10;
        PrivateDevices = false;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ modelsDir ];
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
      };
    };

  modeScript = pkgs.writeShellApplication {
    name = "llama-cpp-mode";
    runtimeInputs = [
      pkgs.systemd
      pkgs.coreutils
    ];
    text = ''
      set -euo pipefail
      usage() {
        echo "Usage: llama-cpp-mode <dual|phi|status>" >&2
        exit 1
      }
      [[ $# -eq 1 ]] || usage
      case "$1" in
        dual)
          systemctl stop llama-cpp-phi.service 2>/dev/null || true
          systemctl start llama-cpp-nemotron.service llama-cpp-qwen.service
          echo "mode=dual ports=8084(nemotron),8085(qwen)"
          ;;
        phi)
          systemctl stop llama-cpp-nemotron.service llama-cpp-qwen.service 2>/dev/null || true
          systemctl start llama-cpp-phi.service
          echo "mode=phi port=8080 aliases=phi4-8k,phi4-16k"
          ;;
        status)
          echo -n "nemotron="; systemctl is-active llama-cpp-nemotron.service || true
          echo -n "qwen="; systemctl is-active llama-cpp-qwen.service || true
          echo -n "phi="; systemctl is-active llama-cpp-phi.service || true
          ;;
        *) usage ;;
      esac
    '';
  };

  idleWatchScript = pkgs.writeShellApplication {
    name = "llama-cpp-phi-idle-watch";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
      pkgs.systemd
      pkgs.coreutils
    ];
    text = ''
      set -euo pipefail
      # While Phi is up: if every preset reports unloaded for grace period, restore dual.
      grace=60
      unloaded_for=0
      while systemctl is-active --quiet llama-cpp-phi.service; do
        sleep 15
        json="$(curl -fsS --max-time 3 http://127.0.0.1:8080/v1/models || true)"
        if [[ -z "$json" ]]; then
          continue
        fi
        # Count loaded instances (status.value == "loaded" or similar).
        loaded="$(echo "$json" | jq '[.data[]? | select(.status.value == "loaded")] | length' 2>/dev/null || echo 0)"
        if [[ "$loaded" == "0" ]]; then
          unloaded_for=$((unloaded_for + 15))
        else
          unloaded_for=0
        fi
        if (( unloaded_for >= grace )); then
          echo "phi idle/unloaded for ''${unloaded_for}s — restoring dual mode"
          systemctl stop llama-cpp-phi.service
          systemctl start llama-cpp-nemotron.service llama-cpp-qwen.service
          exit 0
        fi
      done
    '';
  };
in
{
  systemd.tmpfiles.rules = [
    "d ${modelsDir} 0755 rileyt users -"
  ];

  environment.systemPackages = [
    llamaCppCuda
  ]
  ++ lib.optionals dualGpu [
    modeScript
  ];

  systemd.services = lib.mkMerge [
    (lib.mkIf dualGpu {
      llama-cpp-nemotron = mkService {
        name = "nemotron";
        port = 8084;
        presets = nemoPresets;
        sleepIdle = tuned.dualSleepIdleSeconds;
        wantedBy = [ "multi-user.target" ];
        extraFlags = [
          "--main-gpu"
          "0"
          "--split-mode"
          "none"
        ];
      };

      llama-cpp-qwen = mkService {
        name = "qwen";
        port = 8085;
        presets = qwenPresets;
        sleepIdle = tuned.dualSleepIdleSeconds;
        wantedBy = [ "multi-user.target" ];
        extraFlags = [
          "--main-gpu"
          "1"
          "--split-mode"
          "none"
        ];
      };

      llama-cpp-phi = mkService {
        name = "phi";
        port = 8080;
        presets = phiPresets;
        sleepIdle = tuned.phiSleepIdleSeconds;
        wantedBy = [ ];
        extraFlags = [
          "--main-gpu"
          "0"
          "--split-mode"
          "layer"
          "--tensor-split"
          (lib.concatStringsSep "," (map (_: "1") config.host.gpus))
        ];
      };

      llama-cpp-phi-idle-watch = {
        description = "Restore llama.cpp dual mode after Phi idle unload";
        after = [ "llama-cpp-phi.service" ];
        partOf = [ "llama-cpp-phi.service" ];
        wantedBy = [ "llama-cpp-phi.service" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = lib.getExe idleWatchScript;
          Restart = "no";
          User = "rileyt";
        };
      };
    })

    # Single-GPU fallback (legion): one router, all aliases, exclusive load.
    (lib.mkIf (!dualGpu) {
      llama-cpp = mkService {
        name = "all";
        port = 8080;
        presets = phiPresets // nemoPresets // qwenPresets;
        sleepIdle = tuned.dualSleepIdleSeconds;
        wantedBy = [ "multi-user.target" ];
        extraFlags = [
          "--main-gpu"
          "0"
          "--split-mode"
          "none"
        ];
      };
    })
  ];
}
