{ ... }:

# Home Manager configuration shared by every host. Desktop-environment
# specific settings (GNOME dconf, Cinnamon) live in the per-host home files.
{
  imports = [
    ./core/identity.nix
    ./core/state-version.nix
    ./core/home-manager.nix
    ./desktop/cursor.nix
    ./programs/utilities.nix
    ./programs/google-chrome.nix
    ./programs/spotify.nix
    ./programs/discord.nix
    ./programs/cursor.nix
    ./programs/claude-code.nix
  ];
}
