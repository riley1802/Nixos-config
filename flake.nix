{
  description = "riley's nixos config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

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
      mkPkgsUnstable = system:
        import inputs.nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };

      mkNixos =
        { name
        , system
        , homeFile
        , configFile ? ./hosts/${name}/configuration.nix
        ,
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            pkgsUnstable = mkPkgsUnstable system;
            inherit inputs;
          };

          modules = [
            agenix.nixosModules.default
            {
              environment.systemPackages = [
                agenix.packages.${system}.default
              ];
            }
            home-manager.nixosModules.home-manager
            ({ ... }: {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = {
                inherit inputs;
                pkgsUnstable = mkPkgsUnstable system;
              };
              home-manager.users.rileyt = import homeFile;
            })
            configFile
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
    };
}
