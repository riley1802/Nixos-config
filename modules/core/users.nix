# Login account for this computer.
{ config, lib, ... }:
{
  users.users.${config.my.user} = {
    isNormalUser = true;
    description = "riley thomason";
    extraGroups =
      lib.optionals config.my.services.docker.enable [ "docker" ]
      ++ lib.optionals config.my.services.arr.media.enable [ "media" ]
      ++ [
        "networkmanager"
        "wheel"
      ];
  };
}
