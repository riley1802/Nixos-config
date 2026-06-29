{ config, pkgs, ... }:

{
  home.username = "rileyt";
  home.homeDirectory = "/home/rileyt";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    htop
    ripgrep
    fd
    unzip
    google-chrome
    spotify
    discord
    cursor-cli
    code-cursor
    kdePackages.plasma-browser-integration
  ];
}
