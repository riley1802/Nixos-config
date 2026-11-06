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
    # Local Logitech manager for the MX Master 4. The module installs the
    # package, udev rules, and the graphical-session agent. The packaging
    # flake is the real input; the repository root only aliases it.
    # https://openlogi.org/docs/installation
    openlogi = {
      url = "github:AprilNEA/OpenLogi?dir=packaging";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ nixpkgs
    , agenix
    , openlogi
    , ...
    }:
    let
      # Every computer = hosts/NAME/ plus all of modules/.
      mkHost =
        name:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit inputs;
          };
          modules = [
            ./hosts/${name}
            ./modules
            agenix.nixosModules.default
            openlogi.nixosModules.default
          ];
        };
    in
    {
      nixosConfigurations.nixos = mkHost "nixos";
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
    };
}
