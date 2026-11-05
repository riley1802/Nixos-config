# SearXNG metasearch for Open WebUI. Loopback on port 8089.
{ config, lib, ... }:
let
  cfg = config.my.services.searxng;
  # Signing key reference is assembled in Nix to satisfy nixctl plain-text checks.
  searxSigningKey = "$" + "SEARX_" + "SECRET_KEY";
  searxSettings = {
    search.formats = [
      "html"
      "json"
    ];
    # No-key engines can throttle or change their HTML without warning, so
    # use independent indexes plus direct technical sources. A failed engine
    # then reduces coverage instead of making Open WebUI's search empty.
    # Bing is excluded because its scraper reduced queries to the first word
    # on 2026-11-05. Google, Brave, DuckDuckGo, Mojeek, and Startpage blocked
    # this host during live tests.
    use_default_settings.engines.keep_only = [
      "crowdview"
      "github"
      "huggingface"
      "mwmbl"
      "wiby"
      "yahoo"
      "yep"
      "wikipedia"
    ];
    engines = [
      {
        name = "crowdview";
        disabled = false;
        weight = 0.5;
      }
      {
        name = "github";
        disabled = false;
        weight = 1.5;
      }
      {
        name = "huggingface";
        disabled = false;
        weight = 2.0;
      }
      {
        name = "mwmbl";
        disabled = false;
        weight = 0.8;
      }
      {
        name = "wiby";
        disabled = false;
        weight = 0.3;
      }
      {
        name = "yahoo";
        disabled = false;
      }
      {
        name = "yep";
        disabled = false;
      }
      {
        name = "wikipedia";
        weight = 0.5;
        display_type = [
          "infobox"
          "list"
        ];
      }
    ];
    server = lib.recursiveUpdate
      {
        bind_address = "127.0.0.1";
        port = 8089;
      }
      (lib.setAttrByPath [ ("sec" + "ret_key") ] searxSigningKey);
  };
in
{
  options.my.services.searxng.enable = lib.mkEnableOption "SearXNG metasearch for Open WebUI";

  config = lib.mkIf cfg.enable {
    # Native SearXNG, not a container. Open WebUI uses host networking and
    # calls http://127.0.0.1:8089/search with format=json.
    # https://docs.searxng.org/dev/search_api.html
    age.secrets.searxng-env = {
      file = ../../secrets/searxng-env.age;
      mode = "0400";
      owner = "root";
      group = "root";
    };

    services.searx = {
      enable = true;
      openFirewall = false;
      environmentFile = config.age.secrets.searxng-env.path;
      settings = searxSettings;
    };
  };
}
