# PostgreSQL research archive, schema migrations, and vault storage.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.data-platform;
  postgres = pkgs.postgresql_17;
  stateDirectory = "/var/lib/research-postgresql";
  envFile = "${stateDirectory}/secrets.env";
  # Static group for the vault trees n8n writes. Not named n8n: that name is
  # the dynamic user/group, and a static group of the same name without a
  # static user makes DynamicUser= fail.
  # https://www.freedesktop.org/software/systemd/man/systemd.exec.html#DynamicUser=
  researchGroup = "research";
  researchExports = "/vault/research/exports";
  researchBlobs = "/vault/research/blobs";
  researchBlobObjects = "/vault/research/blobs/sha256";

  schema = pkgs.writeText "research-archive-schema.sql" ''
      \set ON_ERROR_STOP on

      SET ROLE information;

      CREATE SCHEMA IF NOT EXISTS catalog;
      CREATE SCHEMA IF NOT EXISTS research;

      CREATE TABLE IF NOT EXISTS catalog.schema_version (
        version integer PRIMARY KEY,
        applied_at timestamptz NOT NULL DEFAULT now()
      );

      CREATE TABLE IF NOT EXISTS catalog.blob (
        sha256 text PRIMARY KEY CHECK (sha256 ~ '^[0-9a-f]{64}$'),
        storage_key text NOT NULL UNIQUE,
        byte_size bigint NOT NULL CHECK (byte_size >= 0),
        compression text,
        mime_type text NOT NULL,
        retention_class text NOT NULL DEFAULT 'evidence',
        created_at timestamptz NOT NULL DEFAULT now(),
        verified_at timestamptz
      );

      CREATE TABLE IF NOT EXISTS catalog.information_item (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        kind text NOT NULL CHECK (
          kind IN ('paper', 'manual', 'article', 'documentation', 'web_clipping', 'note', 'report')
        ),
        canonical_url text,
        title text NOT NULL,
        authors jsonb NOT NULL DEFAULT '[]'::jsonb,
        publisher text,
        license text,
        language text NOT NULL DEFAULT 'en',
        first_seen_at timestamptz NOT NULL DEFAULT now(),
        metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
        UNIQUE (canonical_url)
      );

      CREATE TABLE IF NOT EXISTS catalog.item_snapshot (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        information_item_id uuid NOT NULL REFERENCES catalog.information_item(id) ON DELETE CASCADE,
        fetched_at timestamptz NOT NULL DEFAULT now(),
        http_status integer,
        final_url text,
        content_hash text NOT NULL CHECK (content_hash ~ '^[0-9a-f]{64}$'),
        mime_type text NOT NULL,
        raw_blob_sha256 text REFERENCES catalog.blob(sha256),
        extracted_text text,
        metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
        supersedes_snapshot_id uuid REFERENCES catalog.item_snapshot(id),
        text_search tsvector GENERATED ALWAYS AS (
          to_tsvector('english'::regconfig, coalesce(extracted_text, chr(32)))
    ) STORED,
    UNIQUE (information_item_id, content_hash)
    );

    CREATE TABLE IF NOT EXISTS catalog.source_chunk (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    item_snapshot_id uuid NOT NULL REFERENCES catalog.item_snapshot(id) ON DELETE CASCADE,
    ordinal integer NOT NULL CHECK (ordinal >= 0),
    text text NOT NULL,
    token_count integer CHECK (token_count IS NULL OR token_count >= 0),
    content_hash text NOT NULL CHECK (content_hash ~ '^[0-9a-f]{64}$'),
    embedding_model text,
    embedded_at timestamptz,
    text_search tsvector GENERATED ALWAYS AS (
    to_tsvector('english'::regconfig, text)
    ) STORED,
    UNIQUE (item_snapshot_id, ordinal),
    UNIQUE (item_snapshot_id, content_hash)
    );

    CREATE TABLE IF NOT EXISTS research.research_run (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    topic text NOT NULL,
    input_parameters jsonb NOT NULL DEFAULT '{}'::jsonb,
    status text NOT NULL DEFAULT 'planned' CHECK (
    status IN ('planned', 'running', 'partial', 'completed', 'failed', 'cancelled')
    ),
    started_at timestamptz,
    completed_at timestamptz,
    workflow_execution_id text,
    model_id text,
    prompt_version text,
    error_summary text,
    created_at timestamptz NOT NULL DEFAULT now()
    );

    CREATE TABLE IF NOT EXISTS research.subtopic (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    research_run_id uuid NOT NULL REFERENCES research.research_run(id) ON DELETE CASCADE,
    parent_subtopic_id uuid REFERENCES research.subtopic(id),
    ordinal integer NOT NULL CHECK (ordinal >= 0),
    title text NOT NULL,
    query_plan jsonb NOT NULL DEFAULT '{}'::jsonb,
    status text NOT NULL DEFAULT 'planned' CHECK (
    status IN ('planned', 'running', 'completed', 'failed', 'skipped')
    ),
    UNIQUE (research_run_id, ordinal)
    );

    CREATE TABLE IF NOT EXISTS research.search_query (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    subtopic_id uuid NOT NULL REFERENCES research.subtopic(id) ON DELETE CASCADE,
    provider text NOT NULL,
    query_text text NOT NULL,
    request jsonb NOT NULL DEFAULT '{}'::jsonb,
    executed_at timestamptz,
    result_count integer CHECK (result_count IS NULL OR result_count >= 0),
    response_blob_sha256 text REFERENCES catalog.blob(sha256),
    status text NOT NULL DEFAULT 'planned' CHECK (
    status IN ('planned', 'running', 'completed', 'failed', 'rate_limited')
    ),
    error_summary text,
    UNIQUE (subtopic_id, provider, query_text)
    );

    CREATE TABLE IF NOT EXISTS research.artifact (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    kind text NOT NULL CHECK (kind IN ('subtopic_report', 'final_report')),
    research_run_id uuid NOT NULL REFERENCES research.research_run(id) ON DELETE CASCADE,
    subtopic_id uuid REFERENCES research.subtopic(id) ON DELETE CASCADE,
    title text NOT NULL,
    current_revision_id uuid,
    status text NOT NULL DEFAULT 'draft' CHECK (
    status IN ('draft', 'review', 'published', 'superseded')
    ),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE NULLS NOT DISTINCT (research_run_id, kind, subtopic_id)
    );

    CREATE TABLE IF NOT EXISTS research.artifact_revision (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    artifact_id uuid NOT NULL REFERENCES research.artifact(id) ON DELETE CASCADE,
    revision_number integer NOT NULL CHECK (revision_number > 0),
    markdown text NOT NULL,
    markdown_hash text NOT NULL CHECK (markdown_hash ~ '^[0-9a-f]{64}$'),
    front_matter jsonb NOT NULL DEFAULT '{}'::jsonb,
    generator_model text,
    prompt_version text,
    created_at timestamptz NOT NULL DEFAULT now(),
    text_search tsvector GENERATED ALWAYS AS (
    to_tsvector('english'::regconfig, markdown)
    ) STORED,
    UNIQUE (artifact_id, revision_number),
    UNIQUE (artifact_id, markdown_hash)
    );

    DO $migration$
    BEGIN
    IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'artifact_current_revision_fk'
      ) THEN
      ALTER TABLE research.artifact
      ADD CONSTRAINT artifact_current_revision_fk
      FOREIGN KEY (current_revision_id)
      REFERENCES research.artifact_revision(id);
    END IF;
    END
    $migration$;

    CREATE TABLE IF NOT EXISTS research.citation (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    artifact_revision_id uuid NOT NULL REFERENCES research.artifact_revision(id) ON DELETE CASCADE,
    item_snapshot_id uuid NOT NULL REFERENCES catalog.item_snapshot(id),
    source_chunk_id uuid REFERENCES catalog.source_chunk(id),
    citation_key text NOT NULL,
    claim_excerpt text,
    source_excerpt text,
    url_at_citation text,
    ordinal integer NOT NULL CHECK (ordinal >= 0),
    locator jsonb NOT NULL DEFAULT '{}'::jsonb,
    UNIQUE (artifact_revision_id, citation_key),
    UNIQUE (artifact_revision_id, ordinal)
    );

    CREATE TABLE IF NOT EXISTS research.artifact_input (
    artifact_revision_id uuid NOT NULL REFERENCES research.artifact_revision(id) ON DELETE CASCADE,
    input_artifact_revision_id uuid NOT NULL REFERENCES research.artifact_revision(id),
    role text NOT NULL,
    ordinal integer NOT NULL CHECK (ordinal >= 0),
    PRIMARY KEY (artifact_revision_id, input_artifact_revision_id, role)
    );

    CREATE TABLE IF NOT EXISTS research.ingestion_job (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    idempotency_key text NOT NULL UNIQUE,
    kind text NOT NULL,
    payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    state text NOT NULL DEFAULT 'pending' CHECK (
    state IN ('pending', 'running', 'completed', 'failed')
    ),
    attempt_count integer NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
    lease_expires_at timestamptz,
    error_summary text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
    );

    -- Version 2: workflow-level idempotency and persisted search results.
    ALTER TABLE research.research_run
      ADD COLUMN IF NOT EXISTS idempotency_key text;
    UPDATE research.research_run
      SET idempotency_key = 'legacy:' || id::text
      WHERE idempotency_key IS NULL;
    ALTER TABLE research.research_run
      ALTER COLUMN idempotency_key SET NOT NULL;
    CREATE UNIQUE INDEX IF NOT EXISTS research_run_idempotency_key_idx
      ON research.research_run (idempotency_key);

    ALTER TABLE research.subtopic
      ADD COLUMN IF NOT EXISTS error_summary text;

    ALTER TABLE catalog.information_item
      ADD COLUMN IF NOT EXISTS canonical_key text;
    CREATE UNIQUE INDEX IF NOT EXISTS information_item_canonical_key_idx
      ON catalog.information_item (canonical_key)
      WHERE canonical_key IS NOT NULL;

    ALTER TABLE research.search_query
      ADD COLUMN IF NOT EXISTS query_hash text;
    UPDATE research.search_query
      SET query_hash = 'legacy:' || id::text
      WHERE query_hash IS NULL;
    ALTER TABLE research.search_query
      ALTER COLUMN query_hash SET NOT NULL;
    ALTER TABLE research.search_query
      DROP CONSTRAINT IF EXISTS search_query_subtopic_id_provider_query_text_key;
    CREATE UNIQUE INDEX IF NOT EXISTS search_query_identity_idx
      ON research.search_query (subtopic_id, provider, query_hash);

    CREATE TABLE IF NOT EXISTS research.search_hit (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      search_query_id uuid NOT NULL REFERENCES research.search_query(id) ON DELETE CASCADE,
      rank integer NOT NULL CHECK (rank >= 0),
      requested_url text NOT NULL,
      canonical_key text NOT NULL,
      title text,
      snippet text,
      information_item_id uuid REFERENCES catalog.information_item(id),
      item_snapshot_id uuid REFERENCES catalog.item_snapshot(id),
      status text NOT NULL DEFAULT 'seen' CHECK (
        status IN ('seen', 'captured', 'skipped', 'failed')
      ),
      error_summary text,
      UNIQUE (search_query_id, canonical_key)
    );
    CREATE INDEX IF NOT EXISTS search_hit_item_idx
      ON research.search_hit (information_item_id);

    ALTER TABLE research.artifact_revision
      ADD COLUMN IF NOT EXISTS evidence_hash text,
      ADD COLUMN IF NOT EXISTS export_path text,
      ADD COLUMN IF NOT EXISTS exported_at timestamptz;
    UPDATE research.artifact_revision
      SET evidence_hash = 'legacy:' || id::text
      WHERE evidence_hash IS NULL;
    ALTER TABLE research.artifact_revision
      ALTER COLUMN evidence_hash SET NOT NULL;
    ALTER TABLE research.artifact_revision
      DROP CONSTRAINT IF EXISTS artifact_revision_artifact_id_markdown_hash_key;
    CREATE UNIQUE INDEX IF NOT EXISTS artifact_revision_evidence_idx
      ON research.artifact_revision (artifact_id, evidence_hash);

    CREATE INDEX IF NOT EXISTS item_snapshot_item_fetched_idx
    ON catalog.item_snapshot (information_item_id, fetched_at DESC);
    CREATE INDEX IF NOT EXISTS item_snapshot_text_search_idx
    ON catalog.item_snapshot USING gin (text_search);
    CREATE INDEX IF NOT EXISTS source_chunk_text_search_idx
    ON catalog.source_chunk USING gin (text_search);
    CREATE INDEX IF NOT EXISTS research_run_status_created_idx
    ON research.research_run (status, created_at DESC);
    CREATE INDEX IF NOT EXISTS subtopic_run_status_idx
    ON research.subtopic (research_run_id, status);
    CREATE INDEX IF NOT EXISTS artifact_run_kind_idx
    ON research.artifact (research_run_id, kind);
    CREATE INDEX IF NOT EXISTS artifact_revision_text_search_idx
    ON research.artifact_revision USING gin (text_search);
    CREATE INDEX IF NOT EXISTS ingestion_job_state_lease_idx
    ON research.ingestion_job (state, lease_expires_at);

    GRANT CONNECT ON DATABASE information TO n8n;
    GRANT USAGE ON SCHEMA catalog, research TO n8n;
    GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA catalog, research TO n8n;
    REVOKE DELETE ON ALL TABLES IN SCHEMA catalog, research FROM n8n;
    GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA catalog, research TO n8n;
    ALTER DEFAULT PRIVILEGES FOR ROLE information IN SCHEMA catalog, research
    GRANT SELECT, INSERT, UPDATE ON TABLES TO n8n;
    ALTER DEFAULT PRIVILEGES FOR ROLE information IN SCHEMA catalog, research
    REVOKE DELETE ON TABLES FROM n8n;
    ALTER DEFAULT PRIVILEGES FOR ROLE information IN SCHEMA catalog, research
    GRANT USAGE, SELECT ON SEQUENCES TO n8n;

    INSERT INTO catalog.schema_version (version) VALUES (1), (2)
    ON CONFLICT (version) DO NOTHING;
  '';

  runtimeRole = pkgs.writeText "research-archive-runtime-role.sql" ''
    \set ON_ERROR_STOP on
    SELECT format('CREATE ROLE n8n LOGIN PASSWORD %L', :'runtime_password')
    WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'n8n')
    \gexec
    ALTER ROLE n8n PASSWORD :'runtime_password';
  '';

  backup = pkgs.writeShellApplication {
    name = "research-archive-backup";
    runtimeInputs = [
      postgres
      pkgs.coreutils
      pkgs.findutils
      pkgs.gzip
    ];
    text = ''
      set -euo pipefail
      umask 077
      readonly destination="/vault/research/backups"
      stamp="$(date --utc +%Y%m%dT%H%M%SZ)"
      readonly stamp
      readonly temporary="$destination/information-$stamp.sql.gz.partial"
      readonly final="$destination/information-$stamp.sql.gz"
      PGPASSWORD=$(tr -d '\n' < ${stateDirectory}/owner-password)
      export PGPASSWORD
      pg_dump \
        --host=127.0.0.1 \
        --port=5433 \
        --username=information \
        --dbname=information \
        --format=plain \
        --no-owner \
        --no-privileges |
        gzip --best > "$temporary"
      mv "$temporary" "$final"
      find "$destination" -type f -name 'information-*.sql.gz' -mtime +30 -delete
    '';
  };
in
{
  options.my.services.data-platform.enable = lib.mkEnableOption "PostgreSQL research archive, schema migrations, and vault storage";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.hardware.disks.enable;
        message = "services/data-platform needs hardware/disks (nixctl enable hardware/disks)";
      }
      {
        assertion = config.my.services.n8n.enable;
        message = "services/data-platform needs services/n8n (nixctl enable services/n8n)";
      }
      {
        assertion = config.my.services.docker.enable;
        message = "services/data-platform needs services/docker (nixctl enable services/docker)";
      }
    ];

    # This instance is deliberately independent from Immich's PostgreSQL
    # service, VectorChord preload, setup hooks, restarts, and upgrades.
    virtualisation.oci-containers.containers.research-postgres = {
      image = "pgvector/pgvector:0.8.1-pg17";
      ports = [ "127.0.0.1:5433:5432" ];
      environment =
        {
          POSTGRES_DB = "information";
          POSTGRES_USER = "information";
          PGDATA = "/var/lib/postgresql/data/pgdata";
        }
        // lib.listToAttrs [
          {
            name = "POSTGRES_PASSWORD_FILE";
            value = "/run/research-secrets/owner-password";
          }
        ];
      environmentFiles = [ envFile ];
      volumes = [
        "${stateDirectory}/data:/var/lib/postgresql/data"
        "${stateDirectory}/owner-password:/run/research-secrets/owner-password:ro"
      ];
      extraOptions = [
        "--health-cmd=pg_isready -U information -d information"
        "--health-interval=10s"
        "--health-timeout=5s"
        "--health-retries=12"
      ];
    };

    systemd.services.research-archive-setup = {
      description = "Prepare research PostgreSQL secrets, data, and vault directories";
      after = [ "vault.mount" ];
      bindsTo = [ "vault.mount" ];
      wantedBy = [ "multi-user.target" ];
      before = [
        "docker-research-postgres.service"
        "research-archive-backup.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        install -d -m 0700 ${stateDirectory}
        install -d -m 0700 -o 999 -g 999 ${stateDirectory}/data

        if [ ! -s ${stateDirectory}/owner-password ]; then
          ${pkgs.openssl}/bin/openssl rand -base64 36 > ${stateDirectory}/owner-password
        fi
        chmod 0400 ${stateDirectory}/owner-password

        runtime_password=
        if [ -s ${envFile} ]; then
          runtime_password=$(${pkgs.gawk}/bin/awk -F= '$1 == "N8N_PASSWORD" { sub(/^[^=]*=/, ""); print; exit }' ${envFile})
        fi
        if [ -z "$runtime_password" ]; then
          runtime_password=$(${pkgs.openssl}/bin/openssl rand -base64 36 | tr -d '\n')
        fi
        printf 'N8N_PASSWORD=%s\n' "$runtime_password" > ${envFile}
        chmod 0400 ${envFile}

        # Parent stays root-owned and not group-writable. Group execute is
        # enough to traverse it. exports and blobs are group-writable and
        # setgid so new files stay in the group. backups stays root-only.
        # install -d applies mode and owner again when the directory exists,
        # so a tree left at root:root 0750 is corrected on the next boot.
        install -d -m 0750 -o root -g ${researchGroup} /vault/research
        install -d -m 2770 -o root -g ${researchGroup} \
          ${researchBlobs} \
          ${researchBlobObjects} \
          ${researchExports}
        install -d -m 0700 -o root -g root /vault/research/backups
      '';
    };

    systemd.services.docker-research-postgres = {
      after = [ "research-archive-setup.service" ];
      requires = [ "research-archive-setup.service" ];
    };

    # Wait for the dedicated container, then apply the idempotent schema.
    systemd.services.research-archive-migrate = {
      description = "Apply the research archive PostgreSQL schema";
      after = [ "docker-research-postgres.service" ];
      requires = [ "docker-research-postgres.service" ];
      wantedBy = [ "multi-user.target" ];
      before = [ "n8n.service" ];
      serviceConfig = {
        Type = "oneshot";
      };
      script = ''
        for attempt in $(seq 1 60); do
          if ${postgres}/bin/pg_isready --host=127.0.0.1 --port=5433 --dbname=information; then
            break
          fi
          if [ "$attempt" -eq 60 ]; then
            echo "research PostgreSQL did not become ready" >&2
            exit 1
          fi
          sleep 2
        done

        PGPASSWORD=$(tr -d '\n' < ${stateDirectory}/owner-password)
        export PGPASSWORD
        set -a
        # shellcheck disable=SC1091
        . ${envFile}
        set +a
        ${postgres}/bin/psql \
          --host=127.0.0.1 \
          --port=5433 \
          --username=information \
          --dbname=information \
          -v "runtime_password=$N8N_PASSWORD" \
          --file=${runtimeRole}
        ${postgres}/bin/psql \
          --host=127.0.0.1 \
          --port=5433 \
          --username=information \
          --dbname=information \
          --file=${schema}
      '';
    };

    systemd.services.research-archive-backup = {
      description = "Back up the research archive database";
      after = [
        "docker-research-postgres.service"
        "research-archive-setup.service"
      ];
      requires = [
        "docker-research-postgres.service"
        "research-archive-setup.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe backup;
      };
    };

    systemd.timers.research-archive-backup = {
      description = "Daily research archive database backup";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };

    # n8n's dynamic user is not in /etc/group. SupplementaryGroups= is how
    # it joins this group. Upstream services.n8n sets DynamicUser=true,
    # ProtectSystem=strict, and StateDirectory=n8n, which only opens
    # /var/lib/n8n. These keys are added beside those, not in place of them.
    # https://www.freedesktop.org/software/systemd/man/systemd.exec.html#ReadWritePaths=
    users.groups.${researchGroup} = { };

    systemd.services.n8n = {
      after = [
        "docker-research-postgres.service"
        "research-archive-migrate.service"
        # Directory creation is before migrate, but n8n only orders on
        # migrate. Start setup itself so ReadWritePaths exists first.
        "research-archive-setup.service"
      ];
      wants = [
        "docker-research-postgres.service"
        "research-archive-migrate.service"
        "research-archive-setup.service"
      ];
      serviceConfig = {
        SupplementaryGroups = [ researchGroup ];
        ReadWritePaths = [
          researchExports
          researchBlobs
          researchBlobObjects
        ];
      };
    };
  };
}

