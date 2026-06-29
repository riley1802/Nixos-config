{ config, ... }:

{
  age.secrets.tailscale-auth-key = {
    file = ../../secrets/tailscale-auth-key.age;
    mode = "0400";
  };

  services.tailscale = {
    enable = true;
    authKeyFile = config.age.secrets.tailscale-auth-key.path;
    openFirewall = false;
  };
}
