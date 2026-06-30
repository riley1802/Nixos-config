{
  description = "riley's nixos config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, agenix, ... }@inputs:
    let
      piHostKey = builtins.readFile /etc/nixos/secrets/nixos-pi-ssh-host-key;
      piHostKeyPub = builtins.readFile /etc/nixos/secrets/nixos-pi-ssh-host-key.pub;

      mkPkgsUnstable = system:
        import inputs.nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };

      mkNixos = {
        name,
        system,
        homeFile,
      }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            pkgsUnstable = mkPkgsUnstable system;
            inherit inputs piHostKey piHostKeyPub;
          };

          modules = [
            agenix.nixosModules.default
            {
              environment.systemPackages = [
                agenix.packages.${system}.default
              ];
            }
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.rileyt = import homeFile;
            }
            ./hosts/${name}/configuration.nix
          ];
        };
    in
    {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;

      nixosConfigurations.nixos = mkNixos {
        name = "nixos";
        system = "x86_64-linux";
        homeFile = ./home.nix;
      };

      nixosConfigurations.nixos-pi = mkNixos {
        name = "nixos-pi";
        system = "aarch64-linux";
        homeFile = ./home/home-pi.nix;
      };
    };
}
