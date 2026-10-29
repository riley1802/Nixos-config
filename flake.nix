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
                uptime-kuma = prev.callPackage ./uptime-kuma-package.nix { };
                radarr = unstable.radarr;
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
