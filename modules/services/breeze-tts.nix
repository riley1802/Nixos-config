# Breeze TTS 2 Q8 on the GTX 1660 SUPER. Web page on port 8084. Runs when the 1660 switch is breeze-tts.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.breeze-tts;
  # Vulkan device 1 is the 1660 SUPER when only the NVIDIA ICD is loaded.
  # Device 0 is the RTX 3050, which drives the desktop and LFM3-Omni.
  # UUID GPU-f2ae9716-6783-f900-4fed-c05b9cb3a6aa. CUDA_VISIBLE_DEVICES does
  # not select a Vulkan device. Checked with vulkaninfo on 2026-11-04.
  # https://github.com/ggml-org/ggml/blob/36da57138425487184aa1da2eee2cde155909c6f/src/ggml-vulkan/ggml-vulkan.cpp
  gpu1660 = "1";
  nvidiaIcd = "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json";
in
{
  options.my.services.breeze-tts.enable = lib.mkEnableOption "Breeze TTS 2 Q8 (1660 SUPER)";

  config = lib.mkIf cfg.enable {
    # Q8_0 is about 3.3 GB on disk and about 4 GB of VRAM, which fits the
    # 6 GB 1660. The upstream unit downloads breeze-tts-2-q8_0.gguf on first
    # start and checks the sha256 pinned in that module. The weights are
    # research and non-commercial. The server does not authenticate, so it
    # stays on loopback and Tailscale Serve is the only way in.
    # https://github.com/HoppouAI/Breeze-TTS-2.cpp/blob/v0.1.6/nix/module.nix
    # https://github.com/HoppouAI/Breeze-TTS-2.cpp/blob/v0.1.6/docs/server.md
    services.breeze-tts = {
      enable = true;
      model = "q8_0";
      host = "127.0.0.1";
      port = 8084;
      wsPort = 8085;
      webui = true;
    };

    users.groups.breeze = { };
    users.users.breeze = {
      isSystemUser = true;
      group = "breeze";
      home = "/var/lib/breeze-tts";
      createHome = false;
    };

    # The first activation created this directory, then the switch rolled
    # back and deleted the user. The files stayed, owned by that old uid.
    # systemd does not chown a StateDirectory that already exists.
    system.activationScripts.breeze-tts-state = {
      deps = [ "users" "groups" ];
      text = ''
        if [[ -d /var/lib/breeze-tts ]]; then
          chown -R breeze:breeze /var/lib/breeze-tts
        fi
      '';
    };

    # The upstream unit is wanted by multi-user. The 1660 switch replaces
    # that. Starting this unit stops Nemotron, and the reverse.
    # https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html#Conflicts=
    systemd.services.breeze-tts = {
      wantedBy = lib.mkForce (lib.optional (config.my.hardware.gtx1660 == "breeze-tts") "multi-user.target");
      conflicts = [ "llama-cpp-nemotron.service" ];
      serviceConfig = {
        User = "breeze";
        Group = "breeze";
        # The render node is group-owned. The NVIDIA device nodes are
        # world-writable, and Vulkan still opens the DRM node.
        SupplementaryGroups = [
          "render"
          "video"
        ];
        # The first start downloads a 3.3 GB GGUF in ExecStartPre. The
        # default start timeout is 90s, which is not enough.
        TimeoutStartSec = "30min";
        ExecStartPre = lib.mkAfter [
          (pkgs.writeShellScript "breeze-wait-nvidia" ''
            set -euo pipefail
            for _ in $(seq 1 30); do
              [[ -e /dev/nvidia0 && -e /dev/nvidiactl ]] && exit 0
              ${pkgs.coreutils}/bin/sleep 1
            done
            echo "NVIDIA device nodes are not present" >&2
            exit 1
          '')
        ];
      };
      environment = {
        GGML_VK_VISIBLE_DEVICES = gpu1660;
        # The upstream unit points this at the whole icd.d directory, which
        # also loads lavapipe and the other Mesa drivers. Device 1 is the
        # 1660 only when the NVIDIA ICD is the only one loaded.
        VK_ICD_FILENAMES = lib.mkForce nvidiaIcd;
      };
    };

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = lib.optionals (config.my.hardware.gtx1660 == "breeze-tts") [
      8084 # Breeze TTS HTTP and web UI
      8085 # Breeze TTS WebSocket
    ];
  };
}
