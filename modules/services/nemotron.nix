# Nemotron 3.5 Bolt E4B llama.cpp server. Web page on port 8083.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.nemotron;
  models = "/var/lib/llama-cpp/models";
  modelFile = "Nemotron-3.5-Bolt-E4B-Q4_K_M.gguf";
  # Gemma 4 E4B MTP assistant, Q8_0. Same gemma4 draft path as the target.
  # sha256 b6a723115efa510d3b3215db1e26790dae84cd08c2134a764f3d194f1f0c3376
  # https://huggingface.co/unsloth/gemma-4-E4B-it-GGUF/blob/main/MTP/README.md
  draftFile = "mtp-gemma-4-E4B-it-Q8_0.gguf";
  server = "${pkgs.llama-cpp}/bin/llama-server";
  # The age file is copied into this unit's credential directory. The
  # script only passes that path, so the key is not in the store or
  # on the process list.
  llamaExec = name: args:
    pkgs.writeShellScript name ''
      set -euo pipefail
      exec ${lib.escapeShellArgs args} --api-key-file "''${CREDENTIALS_DIRECTORY}/llama-api-key"
    '';
in
{
  options.my.services.nemotron.enable = lib.mkEnableOption "Nemotron 3.5 Bolt E4B llama.cpp server";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.hardware.nvidia.enable;
        message = "services/nemotron needs hardware/nvidia (nixctl enable hardware/nvidia)";
      }
    ];

    # NVIDIA's Q4_K_M GGUF of Nemotron 3.5 Bolt E4B (Gemma 4 E4B). Text
    # only. The draft is the Gemma 4 E4B MTP assistant, not NVIDIA's DFlash
    # drafter. On this 1660, 2026-11-04, the same prompt and seed:
    # no draft 57.4 tok/s; n-max 1 74.7 tok/s (acceptance 0.67, mean len
    # 1.67); n-max 2 65.4; n-max 3 61.4; n-max 4 53.3. n-max 1 is the one
    # that is faster here. Unsloth's n-max 4 was measured on a B200.
    # https://huggingface.co/nvidia/NVIDIA-Nemotron-3.5-Bolt-E4B-4GB
    # https://huggingface.co/unsloth/gemma-4-E4B-it-GGUF/blob/main/MTP/README.md
    #
    # The file is 6,180,446,208 bytes (about 5.76 GiB). gemma4.context_length is
    # 65536. Neither 6 GiB card holds the weights plus a 64k q8_0 KV cache.
    # CUDA_VISIBLE_DEVICES lists the GTX 1660 SUPER first, then the RTX 3050, so
    # llama.cpp CUDA0 is the 1660 and CUDA1 is the display card.
    # --split-mode stays the default, layer. The cards are Turing 7.5 and
    # Ampere 8.6. --fit on. --fit-target is 512,2048 in CUDA order: CUDA0 is
    # the 1660 and CUDA1 is the 3050. After that load the 1660 had about
    # 2060 MiB free and the 3050 about 900 MiB free. Swapping the list to
    # 2048,512 packed the 3050, and llama-server exited with cudaMalloc
    # out of memory on device 1. Keep 512,2048.
    # Do not set --tensor-split; it fights --fit.
    # --fit-ctx 65536 keeps that window and --fit moves layers to the CPU
    # instead of shrinking it. -ngl stays unset.
    # Measured 2026-11-04 with this MTP head, n-max 1, q8_0 KV: a 15811
    # token prompt at 16384 was 186.7 tok/s prefill and 55.9 tok/s
    # generation; a 32218 token prompt at 32768 was 157.0 and 42.8.
    # The 2026-11-04 numbers were measured on the 1660 alone.
    #
    # Sampling is NVIDIA's: temperature 1.0, top_p 0.95, thinking on.
    # https://huggingface.co/nvidia/NVIDIA-Nemotron-3.5-Bolt-E4B-4GB
    #
    # Loopback only. Tailscale Serve on port 8083 when this module is on.
    # The same API key as the retired llama servers. /health stays open.
    # The desktop user runs Pi and reads this file; it stays out of the Nix store.
    age.secrets.llama-api-key = {
      file = ../../secrets/llama-api-key.age;
      mode = "0440";
      owner = "root";
      group = "users";
    };

    users.groups.llama = { };
    users.users.llama = {
      isSystemUser = true;
      group = "llama";
      home = "/var/lib/llama-cpp";
      createHome = true;
    };

    systemd.tmpfiles.settings.llama-cpp = {
      "/var/lib/llama-cpp/models".d = {
        mode = "0755";
        user = "root";
        group = "root";
      };
      "/var/lib/llama-cpp/cache".d = {
        mode = "0755";
        user = "llama";
        group = "llama";
      };
    };

    system.activationScripts.nemotron-model.text = ''
      install -d -m 0755 /var/lib/llama-cpp/models /var/lib/llama-cpp/cache
      src=/home/${config.my.user}/llama-models
      for f in ${modelFile} ${draftFile}; do
        if [[ -f $src/$f ]]; then
          if [[ ! -f /var/lib/llama-cpp/models/$f ]] || ! ${pkgs.diffutils}/bin/cmp -s "$src/$f" "/var/lib/llama-cpp/models/$f"; then
            cp -a "$src/$f" "/var/lib/llama-cpp/models/$f"
            chmod 644 "/var/lib/llama-cpp/models/$f"
          fi
        fi
      done
    '';

    systemd.services.llama-cpp-nemotron = {
      description = "llama.cpp server for Nemotron 3.5 Bolt E4B";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ config.age.secrets.llama-api-key.file ];
      unitConfig.ConditionPathExists = "${models}/${modelFile}";
      environment = {
        # 1660 SUPER first (CUDA0), then RTX 3050 (CUDA1). UUIDs from
        # `nvidia-smi -L` on this machine.
        CUDA_VISIBLE_DEVICES = "GPU-f2ae9716-6783-f900-4fed-c05b9cb3a6aa,GPU-d80211d0-ecb1-e279-4f4d-34c53d278895";
        LLAMA_CACHE = "/var/lib/llama-cpp/cache";
      };
      serviceConfig = {
        User = "llama";
        Group = "llama";
        WorkingDirectory = "/var/lib/llama-cpp";
        # The NVIDIA nodes show up when the module loads. systemd does not
        # track them as device units, so wait on the files. A start before
        # they exist fails, then Restart brings the server back.
        ExecStartPre = pkgs.writeShellScript "llama-wait-nvidia" ''
          set -euo pipefail
          for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
            [[ -e /dev/nvidia0 && -e /dev/nvidiactl ]] && exit 0
            ${pkgs.coreutils}/bin/sleep 1
          done
          echo "NVIDIA device nodes are not present" >&2
          exit 1
        '';
        LoadCredential = [
          "llama-api-key:${config.age.secrets.llama-api-key.path}"
        ];
        ExecStart = llamaExec "llama-cpp-nemotron" [
          server
          "--host"
          "127.0.0.1"
          "--port"
          "8083"
          "-m"
          "${models}/${modelFile}"
          "--alias"
          "nemotron-bolt"
          "-c"
          "65536"
          "-np"
          "1"
          "--fit"
          "on"
          "--device"
          "CUDA0,CUDA1"
          "--fit-target"
          "512,2048"
          "--fit-ctx"
          "65536"
          "--cache-type-k"
          "q8_0"
          "--cache-type-v"
          "q8_0"
          "--flash-attn"
          "on"
          "--temp"
          "1.0"
          "--top-p"
          "0.95"
          "--jinja"
          "--reasoning"
          "on"
          "--spec-type"
          "draft-mtp"
          "--spec-draft-model"
          "${models}/${draftFile}"
          "--spec-draft-n-max"
          "1"
        ];
        Restart = "on-failure";
        RestartSec = 5;
        KillSignal = "SIGINT";
        # CUDA JIT and the driver need writable executable pages, and the
        # GPU device nodes are not visible inside a user namespace.
        MemoryDenyWriteExecute = false;
        PrivateUsers = false;
        PrivateDevices = false;
      };
    };

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      8083 # Nemotron 3.5 Bolt E4B
    ];
  };
}
