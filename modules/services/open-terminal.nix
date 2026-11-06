# Open Terminal sandbox for Open WebUI. Loopback API on port 8000.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.open-terminal;
  # Persistent key on disk; Docker reads a root-only runtime env file at
  # start. OPEN_TERMINAL_API_KEY_FILE would need a host file bind mount
  # readable by container uid 1000, which conflicts with a root-only key.
  # https://github.com/open-webui/open-terminal/blob/main/README.md
  # https://github.com/open-webui/open-terminal/blob/main/entrypoint.sh
  apiKeyScript = pkgs.writeShellScript "open-terminal-api-key" ''
    set -euo pipefail
    ${pkgs.coreutils}/bin/install -d -m 0700 /var/lib/open-terminal
    keyfile=/var/lib/open-terminal/api-key
    if [[ ! -f $keyfile ]]; then
      umask 077
      ${pkgs.openssl}/bin/openssl rand -hex 32 > "$keyfile"
      ${pkgs.coreutils}/bin/chown root:root "$keyfile"
      ${pkgs.coreutils}/bin/chmod 0600 "$keyfile"
    fi
    ${pkgs.coreutils}/bin/install -d -m 0700 /run/open-terminal
    umask 077
    printf 'OPEN_TERMINAL_API_KEY=%s\n' \
      "$(${pkgs.coreutils}/bin/tr -d '\n' < "$keyfile")" > /run/open-terminal/env
  '';
  image = "ghcr.io/open-webui/open-terminal:latest@sha256:38e115cb4ec1170bd0093786a864742e77e455f4529dce3b3c1a32754a7d177a";
in
{
  options.my.services.open-terminal.enable = lib.mkEnableOption "Open Terminal sandbox for Open WebUI";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.services.docker.enable;
        message = "services/open-terminal needs services/docker (nixctl enable services/docker)";
      }
    ];

    # Official image for AI agent sandboxes. Pinned by digest from
    # `docker pull ghcr.io/open-webui/open-terminal:latest` on 2026-11-05.
    # Open WebUI uses host networking and reaches this at 127.0.0.1:8000.
    # https://github.com/open-webui/open-terminal
    # https://github.com/open-webui/open-terminal/blob/main/README.md
    #
    # Named volume only for /home/user. No Docker socket, privileged mode,
    # host network, or extra capabilities. Loopback publish keeps the API
    # off the LAN and tailnet; Open WebUI connects from the host namespace.
    virtualisation.oci-containers.containers.open-terminal = {
      inherit image;
      volumes = [ "open-terminal:/home/user" ];
      ports = [ "127.0.0.1:8000:8000" ];
      environmentFiles = [ "/run/open-terminal/env" ];
      environment = {
        SCARF_NO_ANALYTICS = "True";
        DO_NOT_TRACK = "True";
      };
    };

    systemd.services.open-terminal-api-key = {
      description = "Open Terminal API key and runtime env file";
      requiredBy = [ "docker-open-terminal.service" ];
      before = [ "docker-open-terminal.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = apiKeyScript;
      };
    };

    systemd.services.docker-open-terminal = {
      after = [ "docker.service" "open-terminal-api-key.service" ];
      requires = [ "open-terminal-api-key.service" ];
      wants = [ "docker.service" ];
      restartTriggers = [ apiKeyScript ];
    };
  };
}
