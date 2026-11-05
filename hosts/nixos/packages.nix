# Programs installed by name. One plain name per line, sorted.
# Change with: nixctl pkg add NAME / nixctl pkg remove NAME
{ lib, pkgs, ... }:
lib.mkMerge [
  {
    environment.systemPackages = with pkgs; [
      code-cursor
      git
      google-chrome
      htop
      llama-cpp
      spotify
      uv
    ];
  }
  {
    # Chrome app window for Homarr. It sits with the other desktop programs.
    # google-chrome-stable is the package's main program; google-chrome is a
    # symlink to it.
    # https://github.com/NixOS/nixpkgs/blob/6713828a351efa628b025a1adf7f43cbf8597513/pkgs/by-name/go/google-chrome/package.nix
    environment.systemPackages = [
      (pkgs.makeDesktopItem {
        name = "homarr";
        desktopName = "Homarr";
        comment = "Visual service board";
        exec = "google-chrome-stable --app=http://127.0.0.1:7575";
        icon = "google-chrome";
        categories = [ "Network" ];
      })
    ];
  }
]
