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

  # Provision a "llama.cpp (local)" credential (type openAiApi) pointing at the local
  # llama.cpp OpenAI-compatible API (see llama-cpp.nix), so the OpenAI Chat Model /
  # AI Agent nodes can use local models without manual credential setup.
  # Idempotent upsert by fixed id via `n8n import:credentials`; runs after n8n so the
  # owner account/personal project already exist. On a brand-new instance (no owner
  # account yet), it skips gracefully — rerun `systemctl start n8n-llama-cpp-credential`
  # after finishing the first-run setup wizard.
  systemd.services.n8n-llama-cpp-credential = {
    description = "Provision n8n credential for local llama.cpp OpenAI-compatible API";
    after = [ "n8n.service" ];
    wants = [ "n8n.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      DynamicUser = true;
      User = "n8n";
      StateDirectory = "n8n";
      RuntimeDirectory = "n8n-llama-cpp-credential";
      Environment = [
        "HOME=/var/lib/n8n"
        "N8N_USER_FOLDER=/var/lib/n8n"
        "DB_TYPE=postgresdb"
        "DB_POSTGRESDB_HOST=127.0.0.1"
        "DB_POSTGRESDB_DATABASE=n8n"
        "DB_POSTGRESDB_USER=n8n"
        "DB_POSTGRESDB_PASSWORD_FILE=%d/db_postgresdb_password_file"
      ];
      LoadCredential = "db_postgresdb_password_file:${config.age.secrets.n8n-db-password.path}";
      ExecStart = pkgs.writeShellScript "n8n-llama-cpp-credential" ''
        set -euo pipefail
        export PGPASSWORD="$(cat "$CREDENTIALS_DIRECTORY/db_postgresdb_password_file")"

        project_id=$(${config.services.postgresql.package}/bin/psql -h 127.0.0.1 -U n8n -d n8n -tAc \
          "select id from project where type = 'personal' order by \"createdAt\" limit 1")
        project_id=$(echo "$project_id" | tr -d '[:space:]')

        if [ -z "$project_id" ]; then
          echo "n8n-llama-cpp-credential: no personal project yet (owner account not created) — skipping"
          exit 0
        fi

        cred_file="$RUNTIME_DIRECTORY/llama-cpp-credential.json"
        cat > "$cred_file" <<EOF
        [
          {
            "id": "llama-cpp-local-openai",
            "name": "llama.cpp (local)",
            "type": "openAiApi",
            "data": {
              "apiKey": "sk-local-no-auth-required",
              "url": "http://127.0.0.1:8080/v1"
            }
          }
        ]
        EOF

        ${pkgs.n8n}/bin/n8n import:credentials --input="$cred_file" --projectId="$project_id"
      '';
    };
  };
}
