{ config, ... }:

# Unsloth Studio via official Docker image (native install.sh needs apt).
# Studio UI :8000 — Jupyter left unmapped (host :8888 is SearXNG).
# GPU via nvidia-container-toolkit (see docker.nix).
let
  dataDir = "/var/lib/unsloth-studio";
in
{
  age.secrets.unsloth-studio-env = {
    file = ../../secrets/unsloth-studio.env.age;
    mode = "0400";
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
    ];
    environmentFiles = [ config.age.secrets.unsloth-studio-env.path ];
    # Do not pass --restart: oci-containers uses --rm; systemd owns restarts.
    # Prefer CDI device (nvidia.com/gpu=all). Plain --gpus=all fails on this
    # host with "AMD CDI spec not found" despite NVIDIA GPUs being present.
    extraOptions = [ "--device=nvidia.com/gpu=all" ];
  };
}
