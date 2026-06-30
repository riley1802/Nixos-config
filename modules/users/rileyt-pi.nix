{ ... }:

{
  users.users.rileyt = {
    isNormalUser = true;
    description = "riley thomason";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];

    # Initial SSH access over ethernet before Tailscale is configured.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKZiF0zbAClDBzXGNoAMsz7/em4FQjJ+LvIZnxOpKLEV thomasonriley0@gmail.com"
    ];
  };
}
