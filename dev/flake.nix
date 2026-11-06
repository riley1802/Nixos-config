{
  description = "Global development shell. Enter with: nix dev";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          cargo
          gcc
          git
          go
          nodejs
          pkg-config
          python3
          rustc
          uv
        ];

        shellHook = ''
          echo "global dev shell (nix dev)"
        '';
      };
    };
}
