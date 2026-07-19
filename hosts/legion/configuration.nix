{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../common.nix

    ../../modules/hardware/nvidia-prime.nix

    ../../modules/desktop/cinnamon.nix
  ];

  networking.hostName = "legion";

  host.gpus = [ "RTX 3070 Ti" ];
  # Monitor sync needs secrets/uptime-kuma-sync.env.age rekeyed for this host
  # and a Kuma admin account created in the UI first — then flip to true.
  host.uptimeKumaSync = false;
}
