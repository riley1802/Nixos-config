{ lib, piHostKey, piHostKeyPub, ... }:

{
  services.openssh = {
    enable = true;
    openFirewall = false;
    generateHostKeys = false;
    hostKeys = lib.mkForce [ ];
  };

  # Predetermined host key so agenix can decrypt Tailscale auth key on first boot.
  environment.etc."ssh/ssh_host_ed25519_key" = {
    text = piHostKey;
    mode = "0600";
  };
  environment.etc."ssh/ssh_host_ed25519_key.pub" = {
    text = piHostKeyPub;
    mode = "0644";
  };

  # SSH over ethernet (homelab LAN) and Tailscale.
  networking.firewall.allowedTCPPorts = [ 22 ];
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];

  # mDNS — reach the Pi at nixos-pi.local on your LAN.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish.enable = true;
    publish.userServices = false;
    publish.addresses = true;
  };

  security.sudo.wheelNeedsPassword = false;
}
