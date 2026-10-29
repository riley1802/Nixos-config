{ config, ... }:
{
  # ntfy 2.26.0 from the nixos-26.05 module. The phone, Uptime Kuma, n8n,
  # and the arr apps all publish or subscribe here. The process listens on
  # loopback. Chrome's HSTS list upgrades http://*.ts.net to HTTPS, and the
  # iOS app requires the public URL to be HTTPS, so Tailscale Serve
  # terminates TLS on 2586 and proxies here. tailscale-serve.nix installs
  # that route. 2586 is the module default and is free: 5678 is n8n and
  # 3001 is Uptime Kuma.
  #
  # Anonymous clients are denied. Signup stays off. The phone user and the
  # publisher user are provisioned from an age secret so the bcrypt hashes
  # and the publisher token are not in the Nix store. The phone password
  # and that token are in a second secret. Read them with:
  #   pkexec cat /run/agenix/ntfy-passwords
  #
  # Topics, all write-only for the publisher and readable by the phone user:
  #   movies  Radarr, after a movie is imported
  #   shows   Sonarr, after an episode is imported
  #   music   Lidarr, after a release is imported
  #   uptime  Uptime Kuma, when a monitor changes state
  #   n8n     a workflow that posts a message
  #
  # Messages stay cached for 24 hours, so a phone that was offline overnight
  # still receives them. iOS cannot keep its own background connection, so
  # each message also sends a wake-up to ntfy.sh. That wake-up says
  # "New message" and carries the message id. The title and body stay here,
  # and the phone fetches them over the tailnet. Android does not use the
  # wake-up. It keeps a connection to this server, which means the phone
  # has to be on the tailnet.
  # https://github.com/NixOS/nixpkgs/blob/6713828a351efa628b025a1adf7f43cbf8597513/nixos/modules/services/misc/ntfy-sh.nix
  # https://docs.ntfy.sh/config/#access-control
  # https://docs.ntfy.sh/config/#ios-instant-notifications
  # https://docs.ntfy.sh/config/#message-cache
  age.secrets.ntfy-auth = {
    file = ./secrets/ntfy-auth.age;
    mode = "0400";
    owner = "root";
    group = "root";
  };
  age.secrets.ntfy-passwords = {
    file = ./secrets/ntfy-passwords.age;
    mode = "0400";
    owner = "root";
    group = "root";
  };

  services.ntfy-sh = {
    enable = true;
    environmentFile = config.age.secrets.ntfy-auth.path;
    settings = {
      base-url = "https://nixos.taile9f484.ts.net:2586";
      listen-http = "127.0.0.1:2586";
      behind-proxy = true;
      auth-default-access = "deny-all";
      enable-login = true;
      enable-signup = false;
      cache-duration = "24h";
      upstream-base-url = "https://ntfy.sh";
    };
  };

  # Secrets are decrypted by activation before systemd starts services.
  # /run is empty after a shutdown; the next boot fills it again.
  # Start again if the process dies while the machine is coming up.
  systemd.services.ntfy-sh.serviceConfig = {
    Restart = "on-failure";
    RestartSec = "5s";
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    2586 # ntfy
  ];
}
