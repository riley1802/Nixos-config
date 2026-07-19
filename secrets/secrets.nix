# Public keys allowed to decrypt secrets in this directory.
# Rekey after adding keys: agenix -r

let
  rileyt = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKZiF0zbAClDBzXGNoAMsz7/em4FQjJ+LvIZnxOpKLEV thomasonriley0@gmail.com";
  nixos-host = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBKkO4t+GGqZPOiYz4QPFmqBcQzKceLSoguFTHCg5Z2B root@nixos";
  legion-host = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIwTe5yig49pvaR46s1zvbXN8GTBf5IoFVdw39hqxLIJ root@legion";
in
{
  "tailscale-auth-key.age".publicKeys = [
    rileyt
    nixos-host
    legion-host
  ];
  "searxng-secret-key.age".publicKeys = [
    rileyt
    nixos-host
    legion-host
  ];
  "n8n-db-password.age".publicKeys = [
    rileyt
    nixos-host
    legion-host
  ];
  "uptime-kuma-sync.env.age".publicKeys = [
    rileyt
    nixos-host
    legion-host
  ];
  # Uncomment when enabling cloud Honcho:
  # "honcho-env.age".publicKeys = [ rileyt nixos-host ];
  # "honcho-server-env.age".publicKeys = [ rileyt nixos-host ];
}
