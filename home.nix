{ ... }:

{
  imports = [
    ./home/core/identity.nix
    ./home/core/state-version.nix
    ./home/core/home-manager.nix
    ./home/desktop/cursor.nix
    ./home/desktop/gnome/interface.nix
    ./home/desktop/gnome/extensions.nix
    ./home/desktop/gnome/dash-to-dock.nix
    ./home/programs/utilities.nix
    ./home/programs/google-chrome.nix
    ./home/programs/spotify.nix
    ./home/programs/discord.nix
    ./home/programs/hermes.nix
    ./home/programs/cursor.nix
  ];
}
