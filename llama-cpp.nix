{ config, lib, pkgs, ... }:
let
  models = "/var/lib/llama-cpp/models";
  # Fastest generation in the 8/12/16/20 sweep was 12 threads
  # (30.9 t/s). 20 threads won the short prefill and lost generation.
  cpuThreads = 12;
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
  # llama.cpp v0.8.0 from llama-cpp-package.nix. One process cannot be
  # GPU-only for one model and CPU-only for the other, so these are two
  # services.
  #
  # LFM3-VL-2B replaced LFM3-Omni-2B. The VL server is pinned to the RTX
  # 3050 by GPU UUID, so a change in nvidia-smi order cannot move it onto
  # the 1660 SUPER. The 3050 has 6GB and also drives the desktop, so the
  # 1.7B server is refused every GPU. The 1660 SUPER stays idle. Both
  # servers use Q8_0 weights and a q8_0 KV cache. Quantized KV needs flash
  # attention.
  #
  # VL thinks before it answers. Liquid's llama.cpp sampling is
  # --temp 0.1 --top-p 1.0 --top-k 50 --min-p 0.0 --repeat-penalty 1.1
  # and --no-reasoning-preserve.
  # https://docs.liquid.ai/lfm/models/lfm3-vl-2b
  #
  # The servers listen on loopback. Chrome forces HTTPS for *.ts.net, so
  # plain HTTP on the tailnet name times out. Tailscale Serve terminates
  # TLS on 8081 and 8082 and proxies to these loopback ports.
  # tailscale-serve.nix installs those routes. Uptime Kuma still probes
  # loopback /health, which stays public. 8080 is qBittorrent.
  #
  # Every other route, including /v1, requires the age secret. Both
  # servers use the same key. Open WebUI sends it. n8n stores its own
  # copy in the OpenAI credential and does not read this file.
  # https://github.com/ggml-org/llama.cpp/blob/v0.8.0/common/arg.cpp
  # https://github.com/ggml-org/llama.cpp/blob/v0.8.0/tools/server/server.cpp
  age.secrets.llama-api-key = {
    file = ./secrets/llama-api-key.age;
    mode = "0400";
    owner = "root";
    group = "root";
  };

  users.groups.llama = { };
  users.users.llama = {
    isSystemUser = true;
    group = "llama";
    home = "/var/lib/llama-cpp";
    createHome = true;
  };

  # The weights are downloaded to the home directory first. This runs as
  # root during nixos-rebuild and copies them into the service directory.
  system.activationScripts.llama-cpp-models.text = ''
    install -d -m 0755 /var/lib/llama-cpp/models /var/lib/llama-cpp/cache
    src=/home/rileyt/llama-models
    rm -f \
      /var/lib/llama-cpp/models/LFM3-Omni-2B-Q8_0.gguf \
      /var/lib/llama-cpp/models/mmproj-LFM3-Omni-2B-Q8_0.gguf
    for f in LFM3-1.7B-Q8_0.gguf LFM3-VL-2B-Q8_0.gguf mmproj-LFM3-VL-2B-Q8_0.gguf; do
      if [[ -f $src/$f ]]; then
        # cmp is diffutils, which is not on the activation PATH.
        if [[ ! -f /var/lib/llama-cpp/models/$f ]] || ! ${pkgs.diffutils}/bin/cmp -s "$src/$f" "/var/lib/llama-cpp/models/$f"; then
          cp -a "$src/$f" "/var/lib/llama-cpp/models/$f"
          chmod 644 "/var/lib/llama-cpp/models/$f"
        fi
      fi
    done
  '';

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

  systemd.services.llama-cpp-vl = {
    description = "llama.cpp server for LFM3-VL-2B";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    restartTriggers = [ config.age.secrets.llama-api-key.file ];
    # Video input needs ffmpeg on PATH. Image input does not.
    path = [ pkgs.ffmpeg ];
    unitConfig.ConditionPathExists = [
      "${models}/LFM3-VL-2B-Q8_0.gguf"
      "${models}/mmproj-LFM3-VL-2B-Q8_0.gguf"
    ];
    environment = {
      # RTX 3050, from `nvidia-smi -L` on this machine.
      CUDA_VISIBLE_DEVICES = "GPU-d80211d0-ecb1-e279-4f4d-34c53d278895";
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
      ExecStart = llamaExec "llama-cpp-vl" [
        server
        "--host"
        "127.0.0.1"
        "--port"
        "8081"
        "-m"
        "${models}/LFM3-VL-2B-Q8_0.gguf"
        "--alias"
        "lfm3-vl"
        "--mmproj"
        "${models}/mmproj-LFM3-VL-2B-Q8_0.gguf"
        "-c"
        "32768"
        "-np"
        "1"
        "-ngl"
        "all"
        "--fit"
        "off"
        "--cache-type-k"
        "q8_0"
        "--cache-type-v"
        "q8_0"
        "--flash-attn"
        "on"
        "--temp"
        "0.1"
        "--top-p"
        "1.0"
        "--top-k"
        "50"
        "--min-p"
        "0.0"
        "--repeat-penalty"
        "1.1"
        "--no-reasoning-preserve"
        "--jinja"
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

  systemd.services."llama-cpp-1.7b" = {
    description = "llama.cpp server for LFM3-1.7B";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    restartTriggers = [ config.age.secrets.llama-api-key.file ];
    unitConfig.ConditionPathExists = "${models}/LFM3-1.7B-Q8_0.gguf";
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
      ExecStart = llamaExec "llama-cpp-1.7b" [
        server
        "--host"
        "127.0.0.1"
        "--port"
        "8082"
        "-m"
        "${models}/LFM3-1.7B-Q8_0.gguf"
        "--alias"
        "lfm3-1.7b"
        "-c"
        "32768"
        "-np"
        "1"
        "-ngl"
        "0"
        "--device"
        "none"
        "--fit"
        "off"
        "-t"
        (toString cpuThreads)
        "--cache-type-k"
        "q8_0"
        "--cache-type-v"
        "q8_0"
        "--flash-attn"
        "on"
        "--temp"
        "0.1"
        "--top-k"
        "50"
        "--repeat-penalty"
        "1.1"
        "--jinja"
      ];
      Restart = "on-failure";
      RestartSec = 5;
      KillSignal = "SIGINT";
      MemoryDenyWriteExecute = false;
      PrivateUsers = false;
      PrivateDevices = true;
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    8081 # LFM3-VL-2B
    8082 # LFM3-1.7B
  ];
}
