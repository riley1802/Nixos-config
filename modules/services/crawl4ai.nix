# Crawl4AI page-to-markdown API. Loopback port 11235.
{ config, lib, ... }:
let
  cfg = config.my.services.crawl4ai;
in
{
  options.my.services.crawl4ai.enable = lib.mkEnableOption "Crawl4AI page-to-markdown API. Loopback port 11235";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.services.docker.enable;
        message = "services/crawl4ai needs services/docker (nixctl enable services/docker)";
      }
    ];

    age.secrets.crawl4ai-api-token = {
      file = ../../secrets/crawl4ai-api-token.age;
      mode = "0400";
      owner = "root";
      group = "root";
    };

    virtualisation.oci-containers.containers.crawl4ai = {
      image = "unclecode/crawl4ai:latest";
      ports = [ "127.0.0.1:11235:11235" ];
      environmentFiles = [ config.age.secrets.crawl4ai-api-token.path ];
      extraOptions = [ "--shm-size=1g" ];
    };

    # OCI module sets Restart = "on-failure" and autoRemoveOnStop adds --rm; mkForce avoids conflict with --rm via extraOptions --restart.
    systemd.services.docker-crawl4ai.serviceConfig.Restart = lib.mkForce "always";
  };
}
