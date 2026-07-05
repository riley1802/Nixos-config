# Honcho server stack — DISABLED
#
# Self-hosted Honcho = API + deriver worker + PostgreSQL (pgvector) + Redis.
# Upstream: https://github.com/plastic-labs/honcho
#
# Recommended first run: Docker Compose on the host (see README Hermes section).
# This module is a placeholder for a future declarative NixOS service.
#
# To enable later:
#   1. Uncomment the import in hosts/nixos/configuration.nix
#   2. Uncomment the blocks below
#   3. Create secrets/honcho-server-env.age with LLM_OPENAI_API_KEY (or OpenRouter)
#   4. nixos-rebuild switch

{ config, pkgs, ... }:
{
  # ── Example: OCI container (adjust image/build once you pin a workflow) ─────
  #
  # virtualisation.oci-containers.containers.honcho = {
  #   image = "honcho-local"; # build from github:plastic-labs/honcho via nix2container
  #   autoStart = true;
  #   ports = [ "127.0.0.1:8000:8000" ];
  #   environmentFiles = [ config.age.secrets.honcho-server-env.path ];
  #   volumes = [
  #     "/var/lib/honcho/data:/data"
  #   ];
  # };
  #
  # systemd.tmpfiles.rules = [
  #   "d /var/lib/honcho 0750 root root -"
  #   "d /var/lib/honcho/data 0750 root root -"
  # ];

  # ── Or: systemd service running upstream docker compose ─────────────────────
  #
  # systemd.services.honcho = {
  #   description = "Honcho memory API (docker compose)";
  #   wantedBy = [ "multi-user.target" ];
  #   after = [ "network-online.target" "docker.service" ];
  #   requires = [ "docker.service" ];
  #   serviceConfig = {
  #     Type = "oneshot";
  #     RemainAfterExit = true;
  #     WorkingDirectory = "/var/lib/honcho/compose";
  #     ExecStart = "${pkgs.docker-compose}/bin/docker-compose up -d";
  #     ExecStop = "${pkgs.docker-compose}/bin/docker-compose down";
  #   };
  # };
}
