# Public keys allowed to decrypt secrets in this directory.
# Rekey after adding keys: agenix -r

let
  rileyt = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKZiF0zbAClDBzXGNoAMsz7/em4FQjJ+LvIZnxOpKLEV thomasonriley0@gmail.com";
  nixos-host = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBKkO4t+GGqZPOiYz4QPFmqBcQzKceLSoguFTHCg5Z2B root@nixos";
in
{
  "tailscale-auth-key.age".publicKeys = [
    rileyt
    nixos-host
  ];
  "searxng-secret-key.age".publicKeys = [
    rileyt
    nixos-host
  ];
}
