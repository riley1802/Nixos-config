# Chatterbox Turbo TTS on the GTX 1660 SUPER. Loopback HTTP on port 8084.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.chatterbox;
  nvidia = config.boot.kernelPackages.nvidiaPackages.stable;
  gpu1660 = "GPU-f2ae9716-6783-f900-4fed-c05b9cb3a6aa";
  data = "/var/lib/chatterbox";
  venvPython = "${data}/venv/bin/python";
  runServer = pkgs.writeShellScript "chatterbox-run" ''
    set -euo pipefail
    export LD_LIBRARY_PATH="${lib.makeLibraryPath [
      nvidia
      pkgs.stdenv.cc.cc
      pkgs.zlib
      pkgs.libsndfile
      pkgs.glib
    ]}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export CUDA_VISIBLE_DEVICES="${gpu1660}"
    export HF_HUB_DISABLE_XET=1
    export HF_HOME="${data}/huggingface"
    export CHATTERBOX_DEVICE=cuda
    export CHATTERBOX_REF="${data}/ref.wav"
    export CHATTERBOX_HOST=127.0.0.1
    export CHATTERBOX_PORT=${toString cfg.port}
    exec ${venvPython} ${pkgs.chatterbox-tts-server}
  '';
in
{
  options.my.services.chatterbox = {
    enable = lib.mkEnableOption "Chatterbox Turbo TTS (1660 SUPER)";
    port = lib.mkOption {
      type = lib.types.port;
      default = 8084;
      description = "Loopback HTTP port for /health and /tts.";
    };
  };

  config = lib.mkIf cfg.enable {
    # ResembleAI/chatterbox-turbo weights and a pip venv live under /var/lib.
    # The bootstrap copies Riley's HF cache and the benchmark venv when present.
    users.groups.chatterbox = { };
    users.users.chatterbox = {
      isSystemUser = true;
      group = "chatterbox";
      home = data;
      createHome = true;
    };

    systemd.tmpfiles.settings.chatterbox = {
      "${data}".d = {
        mode = "0755";
        user = "chatterbox";
        group = "chatterbox";
      };
      "${data}/huggingface".d = {
        mode = "0755";
        user = "chatterbox";
        group = "chatterbox";
      };
    };

    system.activationScripts.chatterbox-bootstrap.text = ''
      install -d -m 0755 ${data} ${data}/huggingface
      chown chatterbox:chatterbox ${data} ${data}/huggingface
      if [[ ! -f ${data}/ref.wav ]]; then
        ${pkgs.curl}/bin/curl -fsSL -o ${data}/ref.wav \
          "https://storage.googleapis.com/chatterbox-demo-samples/prompts/female_random_podcast.wav"
        chown chatterbox:chatterbox ${data}/ref.wav
        chmod 644 ${data}/ref.wav
      fi
      src_hf=/home/${config.my.user}/.cache/huggingface
      if [[ -d "$src_hf/hub" ]] && [[ ! -d ${data}/huggingface/hub ]]; then
        ${pkgs.rsync}/bin/rsync -a "$src_hf/" ${data}/huggingface/
        chown -R chatterbox:chatterbox ${data}/huggingface
      fi
      if [[ ! -x ${venvPython} ]] && [[ -x /tmp/chatterbox-bench/.venv/bin/python ]]; then
        ${pkgs.rsync}/bin/rsync -a /tmp/chatterbox-bench/.venv/ ${data}/venv/
        chown -R chatterbox:chatterbox ${data}/venv
      fi
    '';

    systemd.services.chatterbox-tts = {
      description = "Chatterbox Turbo TTS (GTX 1660 SUPER)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      unitConfig.ConditionPathExists = [
        venvPython
        "${data}/ref.wav"
      ];
      environment = {
        CUDA_VISIBLE_DEVICES = gpu1660;
        HF_HUB_DISABLE_XET = "1";
        HF_HOME = "${data}/huggingface";
      };
      serviceConfig = {
        User = "chatterbox";
        Group = "chatterbox";
        WorkingDirectory = data;
        ExecStartPre = pkgs.writeShellScript "chatterbox-wait-nvidia" ''
          set -euo pipefail
          for _ in $(seq 1 30); do
            [[ -e /dev/nvidia0 && -e /dev/nvidiactl ]] && exit 0
            ${pkgs.coreutils}/bin/sleep 1
          done
          echo "NVIDIA device nodes are not present" >&2
          exit 1
        '';
        ExecStart = runServer;
        Restart = "on-failure";
        RestartSec = 10;
        MemoryDenyWriteExecute = false;
        PrivateUsers = false;
        PrivateDevices = false;
      };
    };
  };
}
