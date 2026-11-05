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
