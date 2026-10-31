{
  description = "Minimal NixOS desktop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Cursor and Radarr are taken from here because nixos-26.05 lags behind.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-unstable, agenix, ... }: {
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;

    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        agenix.nixosModules.default
        {
          environment.systemPackages = [
            agenix.packages.x86_64-linux.default
          ];

          # Cursor and Radarr come from unstable. Lidarr's current release is
          # not packaged yet, so use the official build in lidarr-package.nix.
          # Uptime Kuma 2.5.8 is newer than both nixpkgs pins.
          # Immich comes from unstable because nixos-26.05 has 2.7.5, which
          # is marked insecure, and phone apps need 3.x. The unstable pin's
          # package is 3.3.5. machine-learning is passthru on that package,
          # and both derivations set mainProgram, so the 26.05 module's
          # lib.getExe calls keep server and ML on the same release.
          # https://github.com/NixOS/nixpkgs/blob/6713828a351efa628b025a1adf7f43cbf8597513/pkgs/by-name/im/immich/package.nix
          # https://github.com/NixOS/nixpkgs/blob/31ecbaca1bdefa45dffc409f0250bd8039ea0010/pkgs/by-name/im/immich/package.nix
          nixpkgs.overlays = [
            (final: prev:
              let
                unstable = import nixpkgs-unstable {
                  system = "x86_64-linux";
                  config.allowUnfree = true;
                };
              in
              {
                lidarr = prev.callPackage ./lidarr-package.nix { };
                # 1.12.3 rejects qBittorrent 5.2's HTTP 204 login. 1.13.1 accepts it.
                # nixos-unstable's Homepage is 2.6.0, which is a different board.
                homepage-dashboard = prev.callPackage ./homepage-package.nix { };
                # nixos-26.05's llama-cpp is build 9190. LFM3 needs v0.8.0.
                llama-cpp = prev.callPackage ./llama-cpp-package.nix { };
                uptime-kuma = prev.callPackage ./uptime-kuma-package.nix { };
                radarr = unstable.radarr;
                immich = unstable.immich;
                code-cursor = unstable.code-cursor.overrideAttrs (old: rec {
                  version = "3.27.22";
                  src = unstable.appimageTools.extract {
                    pname = "cursor";
                    inherit version;
                    src = unstable.fetchurl {
                      url = "https://downloads.cursor.com/production/b1aa50cb6db84fd3e8c808259cb172ea73425c1f/linux/x64/Cursor-3.27.22-x86_64.AppImage";
                      hash = "sha256-TbL+Na4ZIwHdWzQjedCgQavb3W2QKe/ggwCM/aoC+A4=";
                    };
                  };
                  sourceRoot = "cursor-${version}-extracted/usr/share/cursor";
                });
              })
          ];
        }
      ];
    };
  };
}
