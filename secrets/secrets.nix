let
  rileyt = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDCd1Jz+nO1bzSSUY26BAW1Qpy5PISW1XydEhkP9Bl1R";
  nixos = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBKkO4t+GGqZPOiYz4QPFmqBcQzKceLSoguFTHCg5Z2B";
in
{
  "pia-credentials.age".publicKeys = [
    rileyt
    nixos
  ];
}
