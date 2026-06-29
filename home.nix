{ ... }:

{
  imports = [
    ./home/core/default.nix
    ./home/desktop/gnome.nix
    ./home/programs/packages.nix
    ./home/programs/goose.nix
  ];
}
