{ config, lib, pkgs, ... }:
{
  # Open WebUI 0.11.1 from the nixos-26.05 module. Chat front end for the
  # llama.cpp servers in llama-cpp.nix. Those stay on 8081 and 8082, and
  # their own pages stay available. The first account created in the web
  # UI is the admin. Do that at http://127.0.0.1:8088 before an untrusted
  # device is on the tailnet.
  #
  # The module default port is 8080, which is qBittorrent. This listens on
  # loopback. Chrome's HSTS list upgrades http://*.ts.net to HTTPS on the
  # same port, so Tailscale Serve terminates TLS on 8088 and proxies here.
  # tailscale-serve.nix installs that route.
  # https://github.com/NixOS/nixpkgs/blob/6713828a351efa628b025a1adf7f43cbf8597513/nixos/modules/services/misc/open-webui.nix
  # https://docs.openwebui.com/reference/env-configuration
  services.open-webui = {
    enable = true;
    host = "127.0.0.1";
    port = 8088;
    openFirewall = false;
    # Assigning this set replaces the module default, so the telemetry
    # flags are repeated here.
    environment = {
      SCARF_NO_ANALYTICS = "True";
      DO_NOT_TRACK = "True";
      ANONYMIZED_TELEMETRY = "False";
      # Nothing is listening for Ollama. Both models are OpenAI-compatible
      # llama-server endpoints. Each server has one slot, so title, follow-up,
      # and tag generation would queue in front of the reply.
      ENABLE_OLLAMA_API = "False";
      ENABLE_OPENAI_API = "True";
      OPENAI_API_BASE_URLS = "http://127.0.0.1:8081/v1;http://127.0.0.1:8082/v1";
      # OPENAI_API_KEYS is not set here. The oneshot below writes it from
      # the age secret, one copy per URL, so the key stays out of the store.
      # Persistent config is off, so this file is what the process sends.
      WEBUI_URL = "https://nixos.taile9f484.ts.net:8088";
      ENABLE_TITLE_GENERATION = "False";
      ENABLE_FOLLOW_UP_GENERATION = "False";
      ENABLE_TAGS_GENERATION = "False";
      # Connection URLs and the task switches above stay in this file.
      # Chats and accounts still live in the service state directory.
      ENABLE_PERSISTENT_CONFIG = "False";
    };
  };

  # EnvironmentFile is read before ExecStartPre, so the file has to exist
  # already. The age secret is one line. Open WebUI wants that key twice,
  # once for each llama-server URL.
  systemd.services.open-webui-llama-key = {
    description = "Open WebUI llama.cpp API key";
    requiredBy = [ "open-webui.service" ];
    before = [ "open-webui.service" ];
    restartTriggers = [ config.age.secrets.llama-api-key.file ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail
      ${pkgs.coreutils}/bin/install -d -m 0700 /run/open-webui-llama
      key=$(${pkgs.coreutils}/bin/tr -d '\n' < ${config.age.secrets.llama-api-key.path})
      test -n "''$key"
      umask 077
      printf 'OPENAI_API_KEYS=%s;%s\n' "''$key" "''$key" > /run/open-webui-llama/env
      unset key
    '';
  };

  # Start again if the process dies while the machine is coming up.
  # The module option would copy this path into the Nix store. Set the
  # unit directly so the key stays in /run.
  systemd.services.open-webui = {
    restartTriggers = [ config.age.secrets.llama-api-key.file ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "5s";
      EnvironmentFile = lib.mkForce [ "/run/open-webui-llama/env" ];
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    8088 # Open WebUI
  ];
}
