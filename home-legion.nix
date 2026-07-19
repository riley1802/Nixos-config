{ ... }:

# Laptop (host "legion", Cinnamon): shared home config only — Cinnamon is
# configured through its own GUI settings, no dconf modules needed yet.
{
  imports = [
    ./home/common.nix
  ];
}
