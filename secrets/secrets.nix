let
  rileyt = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDCd1Jz+nO1bzSSUY26BAW1Qpy5PISW1XydEhkP9Bl1R";
  nixos = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBKkO4t+GGqZPOiYz4QPFmqBcQzKceLSoguFTHCg5Z2B";
  recipients = [
    rileyt
    nixos
  ];
in
{
  "pia-credentials.age".publicKeys = recipients;
  "ntfy-auth.age".publicKeys = recipients;
  "ntfy-passwords.age".publicKeys = recipients;
  "homepage-api-keys.age".publicKeys = recipients;
  "homarr-encryption-key.age".publicKeys = recipients;
  "llama-api-key.age".publicKeys = recipients;
}
