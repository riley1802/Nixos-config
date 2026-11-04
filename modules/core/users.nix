# Login account for this computer.
{ config, ... }:
{
  users.users.${config.my.user} = {
    isNormalUser = true;
    description = "riley thomason";
    extraGroups = [
      "docker"
      "media"
      "networkmanager"
      "wheel"
    ];
  };
}
