{ ... }:

{
  services.openssh = {
    enable = true;
    openFirewall = false;
  };

  # SSH only over Tailscale — not exposed on LAN/WAN.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];
}
