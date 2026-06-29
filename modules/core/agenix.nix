{ ... }:

{
  # Host key decrypts secrets at activation; user key is for `agenix -e` on this machine.
  age.identityPaths = [
    "/etc/ssh/ssh_host_ed25519_key"
    "/home/rileyt/.ssh/id_ed25519"
  ];
}
