{ ... }:

{
  users.users.rileyt = {
    isNormalUser = true;
    description = "riley thomason";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };
}
