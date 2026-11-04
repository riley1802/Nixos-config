# Cleanuparr download cleanup. Web page on port 11011.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.arr.cleanuparr;
in
{
  options.my.services.arr.cleanuparr.enable = lib.mkEnableOption "Cleanuparr";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.services.arr.media.enable;
        message = "services/arr/cleanuparr needs services/arr/media (nixctl enable services/arr/media)";
      }
    ];

    # Cleanuparr 2.10.12 from packages/cleanuparr.nix. nixpkgs does not
    # have it. The official build is one .NET file, so that package runs
    # it in an FHS environment instead of rewriting the loader.
    #
    # The process listens on loopback. Chrome forces HTTPS for *.ts.net,
    # so Tailscale Serve terminates TLS on 11011 and proxies here.
    # The first visit creates the login. The cleaners stay off until
    # they are enabled in the page. Dry run is also off, so turn that
    # on before enabling one or it will delete downloads. Replacement
    # search is allowed once an app is connected. Proactive search for
    # missing items stays off.
    #
    # qBittorrent saves to /vault/media/downloads. Cleanuparr is in the
    # media group and sees that same path, so the download-directory
    # mapping in its client settings stays empty.
    # https://github.com/Cleanuparr/Cleanuparr/releases/tag/v2.10.12
    # https://github.com/Cleanuparr/Cleanuparr/blob/v2.10.12/docs/docs/installation/detailed.mdx
    # https://github.com/Cleanuparr/Cleanuparr/blob/v2.10.12/docs/docs/configuration/download-client/index.mdx
    users.users.cleanuparr = {
      isSystemUser = true;
      group = "cleanuparr";
      extraGroups = [ "media" ];
      home = "/var/lib/cleanuparr";
      createHome = true;
    };
    users.groups.cleanuparr = { };

    # The FHS wrapper enters with the service working directory. /etc is
    # private inside that wrapper, so the directory has to be /var/lib.
    # The package then changes into the store path that holds wwwroot.
    # homeMode 700 keeps the sqlite files, which hold API keys, private.
    systemd.tmpfiles.settings.cleanuparr."/var/lib/cleanuparr"."d" = {
      mode = "0700";
      user = "cleanuparr";
      group = "cleanuparr";
    };

    systemd.services.cleanuparr = {
      description = "Cleanuparr";
      after = [
        "network.target"
        "media-directories.service"
      ];
      wants = [ "media-directories.service" ];
      bindsTo = [ "media-directories.service" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        PORT = "11011";
        BIND_ADDRESS = "127.0.0.1";
        CLEANUPARR_CONFIG_PATH = "/var/lib/cleanuparr";
      };
      serviceConfig = {
        User = "cleanuparr";
        Group = "cleanuparr";
        WorkingDirectory = "/var/lib/cleanuparr";
        ExecStart = lib.getExe pkgs.cleanuparr;
        Restart = "on-failure";
        RestartSec = "5s";
        UMask = "0002";
      };
    };

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      11011 # Cleanuparr
    ];

    environment.systemPackages = [
      (pkgs.makeDesktopItem {
        name = "cleanuparr";
        desktopName = "Cleanuparr";
        comment = "Download cleanup for the arr stack";
        exec = "google-chrome-stable --app=http://127.0.0.1:11011";
        icon = "google-chrome";
        categories = [ "Network" ];
      })
    ];
  };
}
