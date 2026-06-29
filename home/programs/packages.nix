{ pkgs, ... }:

{
  home.packages = with pkgs; [
    htop # process viewer, terminal system monitor.
    ripgrep # fast text search, better grep.
    fd # fast file finder, better find.
    unzip # extract zip archives.
    google-chrome # web browser, proprietary, mainstream compatibility.
    spotify # music player, proprietary, only acceptable music platform.
    discord # chat and voice, proprietary, gaming communities.
    cursor-cli # Cursor terminal agent and CLI tools.
    code-cursor # Cursor editor, AI code IDE.
  ];
}
