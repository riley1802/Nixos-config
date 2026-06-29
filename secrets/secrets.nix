# Public keys allowed to decrypt secrets in this directory.
# Rekey after adding keys: agenix -r
#
# Host key: add after first rebuild with openssh enabled:
#   ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
#   or paste the ssh-ed25519 line from /etc/ssh/ssh_host_ed25519_key.pub

let
  rileyt = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKZiF0zbAClDBzXGNoAMsz7/em4FQjJ+LvIZnxOpKLEV thomasonriley0@gmail.com";
in
{
  "tailscale-auth-key.age".publicKeys = [ rileyt ];
  "searxng-secret-key.age".publicKeys = [ rileyt ];
}
