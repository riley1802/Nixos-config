{ lib, config, ... }:

# Per-host facts consumed by shared service modules, so one module tree can
# serve every machine. Hosts override these in hosts/<name>/configuration.nix.
{
  options.host = {
    tailnetName = lib.mkOption {
      type = lib.types.str;
      default = "${config.networking.hostName}.taile9f484.ts.net";
      description = "This machine's MagicDNS name, used for Tailscale Serve URLs.";
    };

    gpus = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "GPU" ];
      description = "Display labels for NVIDIA GPUs, index-ordered (drives llama.cpp multi-GPU flags).";
    };

    uptimeKumaSync = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable declarative Uptime Kuma monitor sync (requires the sync secret to be decryptable on this host and a Kuma admin account).";
    };
  };
}
