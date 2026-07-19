{ ... }:

# Desktop (host "nixos"): shared home config plus GNOME dconf settings.
{
  imports = [
    ./home/common.nix
    ./home/desktop/gnome/interface.nix
    ./home/desktop/gnome/extensions.nix
    ./home/desktop/gnome/dash-to-dock.nix
  ];
}
