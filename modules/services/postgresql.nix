{ config, pkgs, ... }:
{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    ensureDatabases = [ "n8n" ];
    ensureUsers = [
      { name = "n8n"; ensureDBOwnership = true; }
    ];
  };
}
