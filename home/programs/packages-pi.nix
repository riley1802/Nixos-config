{ pkgs, ... }:

{
  home.packages = with pkgs; [
    htop
    ripgrep
    fd
    unzip
  ];
}
