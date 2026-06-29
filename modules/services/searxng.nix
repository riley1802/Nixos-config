{ pkgs, config, ... }:

{
  age.secrets.searxng-secret-key = {
    file = ../../secrets/searxng-secret-key.age;
    owner = "searx";
    group = "searx";
    mode = "0400";
  };

  services.searx = {
    enable = true;
    package = pkgs.searxng;

    environmentFile = config.age.secrets.searxng-secret-key.path;
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
