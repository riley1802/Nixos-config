# Encrypted DNS forwarder on 127.0.0.1, with MagicDNS for the tailnet zone.
{ config, lib, ... }:
let
  cfg = config.my.network.dnsproxy;
in
{
  options.my.network.dnsproxy.enable = lib.mkEnableOption "encrypted DNS forwarder";

  config = lib.mkIf cfg.enable {
    # Encrypted DNS: a local forwarder on 127.0.0.1 that sends lookups
    # out over TLS (port 853), because plain DNS is blocked for VPN sites.
    # Tailscale DNS stays off so it does not replace this forwarder. The
    # tailnet zone is the exception: MagicDNS at 100.100.100.100 answers
    # nixos.taile9f484.ts.net, which 1.1.1.1 does not know.
    # https://github.com/AdguardTeam/dnsproxy#usage
    services.dnsproxy = {
      enable = true;
      settings = {
        listen-addrs = [ "127.0.0.1" ];
        listen-ports = [ 53 ];
        upstream = [
          "[/taile9f484.ts.net/]100.100.100.100:53"
          "tls://1.1.1.1"
          "tls://1.0.0.1"
        ];
      };
    };
    networking.nameservers = [ "127.0.0.1" ];
    networking.networkmanager.dns = "none";
    # This process is the resolver. The module orders it after
    # nss-lookup.target, which is the target other services wait on.
    # Unbound starts before that target instead. NetworkManager's online
    # check also needs a resolver, and it runs before network-online.
    systemd.services.dnsproxy = {
      after = lib.mkForce [ "network.target" ];
      before = [
        "nss-lookup.target"
        "NetworkManager-wait-online.service"
      ];
      wantedBy = [
        "nss-lookup.target"
        "network-online.target"
      ];
    };
  };
}
