{ pkgs, ... }:

let
  searxEnvFile = "/var/lib/searx/searx.env";
in
{
  systemd.tmpfiles.rules = [
    "d /var/lib/searx 0750 searx searx -"
  ];

  systemd.services.searx-secret = {
    description = "Generate SearXNG secret key";
    requiredBy = [ "searx-init.service" ];
    before = [ "searx-init.service" ];

    path = [
      pkgs.coreutils
      pkgs.openssl
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      install -d -m 0750 -o searx -g searx /var/lib/searx

      if [ ! -s ${searxEnvFile} ]; then
        umask 077
        printf 'SEARXNG_SECRET_KEY=%s\n' "$(openssl rand -hex 32)" > ${searxEnvFile}
      fi

      chown searx:searx ${searxEnvFile}
      chmod 0600 ${searxEnvFile}
    '';
  };

  services.searx = {
    enable = true;
    package = pkgs.searxng;

    environmentFile = searxEnvFile;
    settingsFile = "/run/searx/settings.yml";

    openFirewall = false;
    redisCreateLocally = false;

    configureUwsgi = false;
    configureNginx = false;
    domain = "localhost";
    uwsgiConfig = {
      http = ":8080";
    };

    faviconsSettings = { };
    limiterSettings = { };

    settings = {
      use_default_settings = true;

      general = {
        debug = false;
        instance_name = "Local SearXNG";
      };

      search = {
        safe_search = 1;
        autocomplete = "";
        default_lang = "";
        formats = [
          "html"
          "json"
        ];
      };

      server = {
        bind_address = "127.0.0.1";
        port = 8888;
        secret_key = "$SEARXNG_SECRET_KEY";
        limiter = false;
        image_proxy = false;
      };
    };
  };
}
