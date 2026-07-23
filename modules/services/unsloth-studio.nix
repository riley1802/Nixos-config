{ config, ... }:

# Unsloth Studio via official Docker image (native install.sh needs apt).
# Studio UI :8000 — Jupyter left unmapped (host :8888 is SearXNG).
# GPU via nvidia-container-toolkit (see docker.nix).
let
  dataDir = "/var/lib/unsloth-studio";

  # Host-side script (#!/usr/bin/env bash) mounted into the container.
  # Must not use pkgs.writeShellScript — that shebang points at /nix/store bash.
  llamaServerWrapText = ''
    #!/usr/bin/env bash
    set -euo pipefail
    real="/home/unsloth/.unsloth/llama.cpp/build/bin/llama-server"
    max_ctx="''${UNSLOTH_MAX_CTX:-8192}"
    allow_mmproj="''${UNSLOTH_ALLOW_MMPROJ:-0}"

    args=()
    skip=0
    has_ctx=0
    has_cache_k=0
    has_cache_v=0

    is_int() { case "$1" in ""|*[!0-9]*) return 1 ;; *) return 0 ;; esac; }

    while [ "$#" -gt 0 ]; do
      if [ "$skip" -eq 1 ]; then
        skip=0
        shift
        continue
      fi
      case "$1" in
        --mmproj)
          if [ "$allow_mmproj" = "1" ]; then
            args+=("$1")
            if [ "$#" -ge 2 ]; then args+=("$2"); shift; fi
          else
            skip=1
          fi
          ;;
        --mmproj=*)
          if [ "$allow_mmproj" = "1" ]; then
            args+=("$1")
          fi
          ;;
        -c|--ctx-size)
          has_ctx=1
          if [ "$#" -ge 2 ] && is_int "$2"; then
            ctx="$2"
            if [ "$ctx" -gt "$max_ctx" ]; then ctx="$max_ctx"; fi
            args+=("$1" "$ctx")
            shift
          else
            args+=("$1")
          fi
          ;;
        -c*)
          has_ctx=1
          ctx="''${1#-c}"
          if is_int "$ctx"; then
            if [ "$ctx" -gt "$max_ctx" ]; then ctx="$max_ctx"; fi
            args+=("-c" "$ctx")
          else
            args+=("$1")
          fi
          ;;
        --ctx-size=*)
          has_ctx=1
          ctx="''${1#--ctx-size=}"
          if is_int "$ctx"; then
            if [ "$ctx" -gt "$max_ctx" ]; then ctx="$max_ctx"; fi
            args+=("--ctx-size" "$ctx")
          else
            args+=("$1")
          fi
          ;;
        --cache-type-k|--cache-type-k=*)
          has_cache_k=1
          args+=("$1")
          case "$1" in
            --cache-type-k)
              if [ "$#" -ge 2 ]; then args+=("$2"); shift; fi
              ;;
          esac
          ;;
        --cache-type-v|--cache-type-v=*)
          has_cache_v=1
          args+=("$1")
          case "$1" in
            --cache-type-v)
              if [ "$#" -ge 2 ]; then args+=("$2"); shift; fi
              ;;
          esac
          ;;
        *)
          args+=("$1")
          ;;
      esac
      shift
    done

    if [ "$has_ctx" -eq 0 ]; then
      args+=("-c" "$max_ctx")
    fi
    if [ "$has_cache_k" -eq 0 ]; then
      args+=("--cache-type-k" "q8_0")
    fi
    if [ "$has_cache_v" -eq 0 ]; then
      args+=("--cache-type-v" "q8_0")
    fi

    exec "$real" "''${args[@]}"
  '';
in
{
  age.secrets.unsloth-studio-env = {
    file = ../../secrets/unsloth-studio.env.age;
    mode = "0400";
  };

  # Mounted into the container; shebang must resolve inside the image.
  environment.etc."unsloth-studio/llama-server-wrap" = {
    mode = "0755";
    text = llamaServerWrapText;
  };

  systemd.tmpfiles.rules = [
    "d ${dataDir} 0755 1000 1000 -"
    "d ${dataDir}/work 0755 1000 1000 -"
    "d ${dataDir}/exports 0755 1000 1000 -"
    "d ${dataDir}/outputs 0755 1000 1000 -"
    "d ${dataDir}/auth 0755 1000 1000 -"
    "d ${dataDir}/cache 0755 1000 1000 -"
    "d ${dataDir}/hf-cache 0755 1000 1000 -"
  ];

  virtualisation.oci-containers.containers.unsloth-studio = {
    image = "unsloth/unsloth:latest";
    ports = [ "127.0.0.1:8000:8000" ];
    volumes = [
      "${dataDir}/work:/workspace/work"
      "${dataDir}/exports:/workspace/studio/exports"
      "${dataDir}/outputs:/workspace/studio/outputs"
      "${dataDir}/auth:/workspace/studio/auth"
      "${dataDir}/cache:/workspace/studio/cache"
      "${dataDir}/hf-cache:/workspace/.cache"
      "/etc/unsloth-studio/llama-server-wrap:/usr/local/bin/unsloth-llama-server-wrap:ro"
    ];
    environment = {
      # HF Xet/hf_transfer stall Hub downloads (stuck .incomplete + lock);
      # force plain HTTPS. See unsloth#4712 / #6858 and lessons.md.
      HF_HUB_DISABLE_XET = "1";
      HF_HUB_ENABLE_HF_TRANSFER = "0";
      # Stable GPU ordinals; prefer RTX 3050 (Ampere) over GTX 1660 for flash-attn.
      CUDA_DEVICE_ORDER = "PCI_BUS_ID";
      CUDA_VISIBLE_DEVICES = "0";
      # Studio honors this instead of the bundled llama-server binary.
      LLAMA_SERVER_PATH = "/usr/local/bin/unsloth-llama-server-wrap";
      UNSLOTH_MAX_CTX = "8192";
      # Vision projector costs ~0.9 GiB and tanks text TPS on 6 GB cards.
      UNSLOTH_ALLOW_MMPROJ = "0";
    };
    environmentFiles = [ config.age.secrets.unsloth-studio-env.path ];
    # Do not pass --restart: oci-containers uses --rm; systemd owns restarts.
    # Prefer CDI device (nvidia.com/gpu=all). Plain --gpus=all fails on this
    # host with "AMD CDI spec not found" despite NVIDIA GPUs being present.
    extraOptions = [ "--device=nvidia.com/gpu=all" ];
  };
}
