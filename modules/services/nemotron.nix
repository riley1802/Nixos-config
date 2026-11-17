# Spark-X2.6-4B llama.cpp server with a DSpark drafter. Web page on port 8083.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.nemotron;
  models = "/var/lib/llama-cpp/models";
  modelFile = "Spark-X2.6-4B-Q4_K_M.gguf";
  draftFile = "Spark-X2.6-4B-DSpark.gguf";
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
  options.my.services.nemotron.enable = lib.mkEnableOption "Spark-X2.6-4B llama.cpp server";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.hardware.nvidia.enable;
        message = "services/nemotron needs hardware/nvidia (nixctl enable hardware/nvidia)";
      }
    ];

    # Main is Q4_K_M from https://huggingface.co/XHToken/Spark-X2.6-4B-GGUF
    # Draft is https://huggingface.co/XHToken/Spark-X2.6-4B-DSpark-GGUF (BF16,
    # one file; there is no Q4 drafter). llama.cpp must be the XHToken fork
    # because of draft-dspark. GTX 1660 SUPER is 6 GB. Do not set -ngl 999.
    # --fit on may move layers to the CPU instead of shrinking the 32768 context.
    # KV is q8_0 for the target and the draft.
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
            tmp="/var/lib/llama-cpp/models/.$f.partial"
            cp -a "$src/$f" "$tmp"
            mv -f "$tmp" "/var/lib/llama-cpp/models/$f"
            chmod 644 "/var/lib/llama-cpp/models/$f"
          fi
        fi
      done
    '';

    systemd.services.llama-cpp-nemotron = {
      description = "llama.cpp server for Spark-X2.6-4B";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ config.age.secrets.llama-api-key.file ];
      unitConfig.ConditionPathExists = [
        "${models}/${modelFile}"
        "${models}/${draftFile}"
      ];
      environment = {
        # GTX 1660 SUPER, from `nvidia-smi -L` on this machine.
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
          "spark"
          "-c"
          "32768"
          "-np"
          "1"
          "--fit"
          "on"
          "--fit-ctx"
          "32768"
          "--cache-type-k"
          "q8_0"
          "--cache-type-v"
          "q8_0"
          "--cache-type-k-draft"
          "q8_0"
          "--cache-type-v-draft"
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
          "draft-dspark"
          "--spec-draft-model"
          "${models}/${draftFile}"
          "--spec-draft-n-max"
          "7"
          "--spec-draft-sampling"
          "greedy"
          "--spec-draft-p-min"
          "0"
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
      8083 # Spark-X2.6-4B
    ];
  };
}
