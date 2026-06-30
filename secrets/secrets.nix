# Public keys allowed to decrypt secrets in this directory.
# Rekey after adding keys: agenix -r

let
  rileyt = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKZiF0zbAClDBzXGNoAMsz7/em4FQjJ+LvIZnxOpKLEV thomasonriley0@gmail.com";
  nixos-host = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBKkO4t+GGqZPOiYz4QPFmqBcQzKceLSoguFTHCg5Z2B root@nixos";
  nixos-pi-host = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOH9BaWOrAZDeSaFLwYzpfEirG/MYO5ky691yjZoxYlq root@nixos-pi";
in
{
  "tailscale-auth-key.age".publicKeys = [
    rileyt
    nixos-host
    nixos-pi-host
  ];
  "searxng-secret-key.age".publicKeys = [
    rileyt
    nixos-host
  ];
}
