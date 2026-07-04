{ pkgs, ... }:

{
  home.packages = with pkgs; [
    cursor-cli
    code-cursor
  ];
}
