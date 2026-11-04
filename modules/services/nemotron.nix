# Nemotron 3.5 Bolt E4B llama.cpp server. Web page on port 8083. Runs when the 1660 switch is nemotron.
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
  # on the process list. services/llama owns the secret.
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
        assertion = config.my.services.llama.enable;
        message = "services/nemotron needs services/llama (nixctl enable services/llama)";
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
    # The file is 6,180,446,208 bytes (about 5.76 GiB). The GTX 1660 SUPER
    # has 6 GiB and is otherwise idle, so -ngl all plus a q8_0 KV cache
    # does not fit. Context is 16384. --fit-ctx keeps that window and
    # --fit on moves layers to the CPU instead of shrinking it.
    # Measured 2026-11-04 with this MTP head, n-max 1, q8_0 KV: a 15811
    # token prompt at 16384 was 186.7 tok/s prefill and 55.9 tok/s
    # generation; a 32218 token prompt at 32768 was 157.0 and 42.8.
    # The unit stays at 16384. -ngl is left unset.
    # The RTX 3050 already runs LFM3-Omni and the desktop.
    #
    # Sampling is NVIDIA's: temperature 1.0, top_p 0.95, thinking on.
    # https://huggingface.co/nvidia/NVIDIA-Nemotron-3.5-Bolt-E4B-4GB
    #
    # Loopback only. Tailscale Serve, Open WebUI, and the Homarr ping
    # proxy add port 8083 when the 1660 switch is nemotron. 8080 is qBittorrent,
    # 8081 and 8082 are the LFM3 servers, and 8088 is Open WebUI.
    # The same API key as those servers. /health stays open.
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
      wantedBy = lib.optional (config.my.hardware.gtx1660 == "nemotron") "multi-user.target";
      # https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html#Conflicts=
      conflicts = [ "breeze-tts.service" ];
      restartTriggers = [ config.age.secrets.llama-api-key.file ];
      unitConfig.ConditionPathExists = "${models}/${modelFile}";
      environment = {
        # GTX 1660 SUPER, from `nvidia-smi -L` on this machine.
        # my.hardware.gtx1660 picks the process that boots. Conflicts stops
        # Breeze when this unit starts.
        CUDA_VISIBLE_DEVICES = "GPU-f2ae9716-6783-f900-4fed-c05b9cb3a6aa";
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
          "16384"
          "-np"
          "1"
          "--fit"
          "on"
          "--fit-ctx"
          "16384"
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

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = lib.optionals (config.my.hardware.gtx1660 == "nemotron") [
      8083 # Nemotron 3.5 Bolt E4B
    ];
  };
}
