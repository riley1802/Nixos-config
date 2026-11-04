# OpenSSH on the tailnet, plus the laptop host alias.
{ config, lib, ... }:
let
  cfg = config.my.network.openssh;
in
{
  options.my.network.openssh.enable = lib.mkEnableOption "OpenSSH on the tailnet";

  config = lib.mkIf cfg.enable {
    # OpenSSH is reachable from the tailnet only.
    services.openssh = {
      enable = true;
      openFirewall = false;
      settings = {
        AllowUsers = [ config.my.user ];
        KbdInteractiveAuthentication = false;
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      22
    ];

    # `ssh laptop` uses the Linux machine already on this tailnet.
    programs.ssh.extraConfig = ''
      Host laptop
        HostName rileys-minty.taile9f484.ts.net
        User riley
    '';
  };
}
