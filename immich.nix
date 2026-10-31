{ ... }:
{
  # Immich 3.3.5 from the nixpkgs-unstable pin in flake.nix. nixos-26.05
  # packages 2.7.5, which is marked insecure, and current phone apps need
  # 3.x. This file keeps the 26.05 services.immich module. That module
  # enables PostgreSQL, Redis, pgvector, and VectorChord 1.1.1. It starts
  # the server with `lib.getExe cfg.package` and machine learning with
  # `lib.getExe cfg.package.machine-learning`. The overlaid package sets
  # mainProgram to "server". Its passthru machine-learning derivation sets
  # mainProgram to "machine-learning", so those calls resolve and both
  # parts stay on 3.3.5. settings stays at the module default, null, so
  # the first visit creates the admin account in the web UI.
  #
  # The process listens on 127.0.0.1:2283. Tailscale Serve in
  # tailscale-serve.nix presents HTTPS for nixos.taile9f484.ts.net:2283
  # and proxies here. The phone app uses that URL. openFirewall stays
  # false: that option would open the port on every interface. TCP 2283
  # is accepted on tailscale0 only. The home LAN and the VPN stay closed.
  #
  # Photos live in /vault/immich, mode 0700, owned by the immich user and
  # group the module creates. Postgres data stays on the root NVMe at the
  # module default. Redis is the module's local unix socket. Machine
  # learning stays enabled and runs on CPU. The module already sets
  # MACHINE_LEARNING_WORKERS to 1. accelerationDevices stays at the empty
  # default, which turns PrivateDevices on. The RTX 3050 runs the desktop
  # and llama.cpp.
  # https://docs.immich.app/
  # https://docs.immich.app/features/mobile-backup
  # https://github.com/NixOS/nixpkgs/blob/6713828a351efa628b025a1adf7f43cbf8597513/nixos/modules/services/web-apps/immich.nix
  # https://github.com/NixOS/nixpkgs/blob/6713828a351efa628b025a1adf7f43cbf8597513/pkgs/by-name/im/immich/package.nix
  # https://github.com/NixOS/nixpkgs/blob/31ecbaca1bdefa45dffc409f0250bd8039ea0010/pkgs/by-name/im/immich/package.nix
  # https://github.com/NixOS/nixpkgs/blob/31ecbaca1bdefa45dffc409f0250bd8039ea0010/pkgs/by-name/im/immich-machine-learning/package.nix
  services.immich = {
    enable = true;
    host = "127.0.0.1";
    port = 2283;
    mediaLocation = "/vault/immich";
    openFirewall = false;
  };

  # The module's tmpfiles rule for mediaLocation is type "e". That adjusts
  # an existing directory and leaves a non-default path for us to create.
  # The immich user and group come from the module.
  # https://github.com/NixOS/nixpkgs/issues/491953
  systemd.services.immich-media-directory = {
    description = "Create the Immich library on the vault disk";
    after = [ "vault.mount" ];
    bindsTo = [ "vault.mount" ];
    before = [ "immich-server.service" ];
    # Requires from immich-server, so a failed create keeps the server down.
    requiredBy = [ "immich-server.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      install -d -m 0700 -o immich -g immich /vault/immich
    '';
  };

  # List options merge with the module, so postgresql.target stays in
  # `after` and this unit is appended.
  systemd.services.immich-server.after = [ "immich-media-directory.service" ];
  systemd.services.immich-server.wants = [ "immich-media-directory.service" ];

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    2283 # Immich
  ];
}
