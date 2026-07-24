{ ... }:

# Home Manager entry for every host — shared modules only. Cinnamon is
# configured through its GUI; no DE-specific dconf modules yet.
{
  imports = [
    ./home/common.nix
  ];
}
