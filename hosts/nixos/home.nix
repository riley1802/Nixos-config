# rileyt's Home Manager config. home.stateVersion stays at the first install.
{ config, ... }:
{
  home-manager.users.${config.my.user} = {
    programs.home-manager.enable = true;
    # Set once. Do not bump it when Home Manager updates.
    home.stateVersion = "26.05";
  };
}
