# Programs installed by name. One plain name per line, sorted.
# Change with: nixctl pkg add NAME / nixctl pkg remove NAME
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    code-cursor
    discord
    gh
    git
    google-chrome
    htop
    spotify
    uv
  ];
}
