# Honcho memory provider — DISABLED
#
# Honcho adds cross-session user modeling on top of Hermes built-in memory.
# Self-hosted stack: https://honcho.dev/docs/v3/contributing/self-hosting
# Hermes integration: https://honcho.dev/docs/v3/guides/integrations/hermes
#
# To enable later:
#   1. Uncomment the import in default.nix
#   2. Uncomment blocks below (remove leading # from each active line)
#   3. Start Honcho (Docker or modules/services/honcho.nix when you add it)
#   4. Uncomment honcho settings in settings.nix
#   5. Create secrets/honcho-env.age (cloud) OR use baseUrl only (self-hosted)
#   6. nixos-rebuild switch

{ config, ... }:
{
  # ── Hermes: Honcho Python extra + env ─────────────────────────────────────
  # services.hermes-agent.extraDependencyGroups = [
  #   "honcho"
  # ];
  #
  # services.hermes-agent.environment = {
  #   HONCHO_URL = "http://127.0.0.1:8000";
  # };
  #
  # services.hermes-agent.environmentFiles = lib.mkAfter [
  #   config.age.secrets.honcho-env.path
  # ];

  # ── agenix (cloud Honcho only — skip for self-hosted with AUTH_USE_AUTH=false) ─
  # age.secrets.honcho-env = {
  #   file = ../../../secrets/honcho-env.age;
  #   owner = "hermes";
  #   group = "hermes";
  #   mode = "0640";
  # };

  # ── Seed honcho.json into HERMES_HOME (declarative Hermes ↔ Honcho link) ───
  # systemd.services.hermes-agent.preStart = lib.mkAfter ''
  #   HONCHO_JSON="${config.services.hermes-agent.stateDir}/.hermes/honcho.json"
  #   if [ ! -f "$HONCHO_JSON" ]; then
  #     install -o hermes -g hermes -m 0640 /dev/null "$HONCHO_JSON"
  #     cat > "$HONCHO_JSON" <<'HONCHO_JSON_EOF'
  # {
  #   "baseUrl": "http://127.0.0.1:8000",
  #   "hosts": {
  #     "hermes": {
  #       "enabled": true,
  #       "aiPeer": "hermes",
  #       "peerName": "rileyt",
  #       "workspace": "hermes"
  #     }
  #   }
  # }
  # HONCHO_JSON_EOF
  #     chown hermes:hermes "$HONCHO_JSON"
  #   fi
  # '';

  # ── Start Hermes after Honcho API is up ────────────────────────────────────
  # systemd.services.hermes-agent.after = lib.mkAfter [ "honcho.service" ];
  # systemd.services.hermes-agent.requires = lib.mkAfter [ "honcho.service" ];
}
