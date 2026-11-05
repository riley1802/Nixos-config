# Open WebUI 0.13.0 chat. Web page on port 8088.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.open-webui;
  # The 1660 switch publishes Nemotron only while that process is the one
  # that boots. The unit can be installed and stopped.
  nemotronUp = config.my.services.nemotron.enable && config.my.hardware.gtx1660 == "nemotron";
  # One copy of the llama.cpp key per OpenAI URL. The space before the
  # third "$key" stays outside the indented string: Nix strips that
  # indent, and a space inside it glued the second and third copies
  # into one argument (8082 got the key twice, 8083 got nothing).
  llamaKeyScript = pkgs.writeShellScript "open-webui-llama-key" ''
    set -euo pipefail
    ${pkgs.coreutils}/bin/install -d -m 0700 /run/open-webui-llama
    key=$(${pkgs.coreutils}/bin/tr -d '\n' < ${config.age.secrets.llama-api-key.path})
    test -n "$key"
    umask 077
    printf 'OPENAI_API_KEYS=%s;%s${lib.optionalString nemotronUp ";%s"}\n' "$key" "$key" ${lib.optionalString nemotronUp ''"$key"''} > /run/open-webui-llama/env
    unset key
  '';
  image = "ghcr.io/open-webui/open-webui:v0.13.0@sha256:2272b0fb7c8783a016bcc179abb467cfa34590c99c5e6560fe0e9155b4820a09";
in
{
  options.my.services.open-webui.enable = lib.mkEnableOption "Open WebUI";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.services.docker.enable;
        message = "services/open-webui needs services/docker (nixctl enable services/docker)";
      }
      {
        assertion = config.my.services.llama.enable;
        message = "services/open-webui needs services/llama (nixctl enable services/llama)";
      }
    ];

    # Official image, not the nixos-26.05 package (0.11.1). The standard
    # tag is the one without Ollama or CUDA: llama.cpp already serves the
    # models, and the 1660 is Nemotron's.
    # https://docs.openwebui.com/getting-started/quick-start/
    # https://github.com/open-webui/open-webui/blob/v0.13.0/backend/start.sh
    #
    # The image listens on 0.0.0.0:8080 unless HOST and PORT are set. 8080
    # is qBittorrent. HOST=127.0.0.1 and PORT=8088 keep the old address.
    # Tailscale Serve still terminates TLS on 8088 and proxies here.
    #
    # llama.cpp is bound to 127.0.0.1. host.docker.internal is the bridge
    # gateway, so a published port cannot reach those servers. Host
    # networking puts this container in the host network namespace.
    # Chats stay in /var/lib/open-webui/data, mounted at the image's data
    # dir. The first account created in the web UI is the admin.
    virtualisation.oci-containers.containers.open-webui = {
      inherit image;
      volumes = [ "/var/lib/open-webui/data:/app/backend/data" ];
      environmentFiles = [ "/run/open-webui-llama/env" ];
      environment = {
        HOST = "127.0.0.1";
        PORT = "8088";
        SCARF_NO_ANALYTICS = "True";
        DO_NOT_TRACK = "True";
        ANONYMIZED_TELEMETRY = "False";
        ENABLE_OLLAMA_API = "False";
        ENABLE_OPENAI_API = "True";
        OPENAI_API_BASE_URLS = "http://127.0.0.1:8081/v1;http://127.0.0.1:8082/v1${lib.optionalString nemotronUp ";http://127.0.0.1:8083/v1"}";
        WEBUI_SECRET_KEY_FILE = "/app/backend/data/.webui_secret_key";
        WEBUI_URL = "https://${config.my.tailnetHost}:8088";
        ENABLE_TITLE_GENERATION = "False";
        ENABLE_FOLLOW_UP_GENERATION = "False";
        ENABLE_TAGS_GENERATION = "False";
        # Connection URLs and the task switches above stay in this file.
        # Chats and accounts still live in the mounted data directory.
        ENABLE_PERSISTENT_CONFIG = "False";
      };
      extraOptions = [ "--network=host" ];
    };

    # Environment file has to exist before the container starts. The age
    # secret is one line. Open WebUI wants that key once per URL.
    systemd.services.open-webui-llama-key = {
      description = "Open WebUI llama.cpp API key";
      requiredBy = [ "docker-open-webui.service" ];
      before = [ "docker-open-webui.service" ];
      restartTriggers = [ config.age.secrets.llama-api-key.file ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = llamaKeyScript;
      };
    };

    systemd.services.docker-open-webui = {
      after = [ "open-webui-llama-key.service" ];
      requires = [ "open-webui-llama-key.service" ];
      restartTriggers = [
        config.age.secrets.llama-api-key.file
        llamaKeyScript
      ];
    };

    # v0.13.0 migrates the schema. 0.11.1 cannot open the new file, so keep
    # one consistent copy from before the new process starts. Later
    # activations leave that copy alone. The old service's login key, if
    # it is sitting next to the data directory, moves into the mount so
    # existing sessions keep working.
    # https://openwebui.com/blog/v0-13-0-your-model-gets-a-computer
    system.activationScripts.open-webui-013-backup.text = ''
      data=/var/lib/open-webui/data
      db=$data/webui.db
      bak=$data/webui.db.bak-before-0.13.0
      old_key=/var/lib/open-webui/.webui_secret_key
      new_key=$data/.webui_secret_key
      if [[ -f $db && ! -f $bak ]]; then
        ${pkgs.sqlite}/bin/sqlite3 "$db" ".backup '$bak'"
      fi
      if [[ -f $old_key && ! -f $new_key ]]; then
        cp -a "$old_key" "$new_key"
      fi
    '';

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      8088 # Open WebUI
    ];
  };
}
