{ config, pkgs, ... }:
{
  age.secrets.n8n-db-password = {
    file = ../../secrets/n8n-db-password.age;
    mode = "0400";
  };

  services.n8n = {
    enable = true;
    environment = {
      # Localhost only — Tailscale Serve terminates TLS on :5678 (see tailscale-serve.nix).
      # N8N_PATH subpath hosting is broken in n8n 2.x; do not put n8n behind a path prefix.
      N8N_HOST = "nixos.taile9f484.ts.net";
      N8N_PORT = "5678";
      N8N_PROTOCOL = "https";
      N8N_LISTEN_ADDRESS = "127.0.0.1";
      N8N_PROXY_HOPS = "1";
      WEBHOOK_URL = "https://nixos.taile9f484.ts.net:5678/";
      DB_TYPE = "postgresdb";
      DB_POSTGRESDB_HOST = "127.0.0.1";
      DB_POSTGRESDB_DATABASE = "n8n";
      DB_POSTGRESDB_USER = "n8n";
      DB_POSTGRESDB_PASSWORD_FILE = config.age.secrets.n8n-db-password.path;
    };
  };

  # Sync the agenix password into the PostgreSQL role (ensureUsers does not set passwords).
  # Password is openssl base64 (A–Z a–z 0–9 + / =) so single-quote SQL literals are safe.
  # Note: psql :'var' interpolation is NOT applied to -c strings — do not use it here.
  systemd.services.n8n-postgres-password = {
    description = "Set n8n PostgreSQL role password from agenix";
    after = [ "postgresql.service" ];
    before = [ "n8n.service" ];
    requires = [ "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "postgres";
      LoadCredential = "dbpass:${config.age.secrets.n8n-db-password.path}";
      ExecStart = pkgs.writeShellScript "n8n-postgres-password" ''
        set -euo pipefail
        pass=$(cat "$CREDENTIALS_DIRECTORY/dbpass")
        ${config.services.postgresql.package}/bin/psql -v ON_ERROR_STOP=1 -d postgres \
          -c "ALTER USER n8n PASSWORD '$pass'"
      '';
    };
  };

  systemd.services.n8n = {
    after = [ "n8n-postgres-password.service" ];
    requires = [ "n8n-postgres-password.service" ];
  };
}
