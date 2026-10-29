{ ... }:
{
  # Uptime Kuma 2.5.8 from uptime-kuma-package.nix. The admin account,
  # monitors, and the ntfy notification are stored in /var/lib/uptime-kuma,
  # not in this file. That notification posts to the local ntfy server's
  # uptime topic. See ntfy.nix.
  #
  # HOST "::" listens on every IPv4 and IPv6 address. Uptime Kuma treats
  # that as dual-stack. The firewall rule below is what limits who can
  # connect: port 3001 is open on Tailscale only. Loopback stays
  # reachable at http://127.0.0.1:3001 because NixOS trusts it.
  # https://github.com/NixOS/nixpkgs/blob/6713828a351efa628b025a1adf7f43cbf8597513/nixos/modules/services/monitoring/uptime-kuma.nix
  # https://github.com/louislam/uptime-kuma/wiki/Environment-Variables
  services.uptime-kuma = {
    enable = true;
    # Some notification types call the apprise program. The module
    # only puts it on the service PATH when this is set.
    appriseSupport = true;
    settings = {
      HOST = "::";
      PORT = "3001";
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 3001 ];
}
