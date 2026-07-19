{ config
, lib
, pkgs
, ...
}:
let
  tailnet = config.host.tailnetName;
  tagName = "nix-managed";
  notificationName = "ntfy-homeport";

  groups = [
    "AI / Local Models"
    "Automation & Infra"
    "Monitoring"
    "Infra"
  ];

  # Desired monitors — upserted by exact name; tagged nix-managed for safe cleanup.
  monitors = [
    {
      name = "Homepage (local)";
      type = "http";
      url = "http://127.0.0.1:8083";
      group = "Monitoring";
    }
    {
      name = "Homepage (tailnet)";
      type = "http";
      url = "https://${tailnet}/";
      group = "Monitoring";
    }
    {
      name = "llama.cpp";
      type = "http";
      url = "http://127.0.0.1:8080/v1/models";
      group = "AI / Local Models";
    }
    {
      name = "whisper.cpp";
      type = "http";
      url = "http://127.0.0.1:8081";
      group = "AI / Local Models";
    }
    {
      name = "Piper TTS";
      type = "http";
      url = "http://127.0.0.1:8082/health";
      group = "AI / Local Models";
    }
    {
      name = "SearXNG";
      type = "http";
      url = "http://127.0.0.1:8888";
      group = "AI / Local Models";
    }
    {
      name = "n8n (local)";
      type = "http";
      url = "http://127.0.0.1:5678/healthz";
      group = "Automation & Infra";
    }
    {
      name = "n8n (tailnet)";
      type = "http";
      url = "https://${tailnet}:5678";
      group = "Automation & Infra";
    }
    {
      name = "Portainer (local)";
      type = "http";
      url = "https://127.0.0.1:9443";
      ignoreTls = true;
      group = "Automation & Infra";
    }
    {
      name = "Portainer (tailnet)";
      type = "http";
      url = "https://${tailnet}:9443";
      group = "Automation & Infra";
    }
    {
      name = "GPU stats";
      type = "http";
      url = "http://127.0.0.1:8091/host";
      group = "Infra";
    }
    {
      name = "ntfy (local)";
      type = "http";
      url = "http://127.0.0.1:8090";
      group = "Monitoring";
    }
    {
      name = "ntfy (tailnet)";
      type = "http";
      url = "http://${tailnet}:8090";
      group = "Monitoring";
    }
    {
      name = "Uptime Kuma (local)";
      type = "http";
      url = "http://127.0.0.1:3001";
      group = "Monitoring";
    }
    {
      name = "Uptime Kuma (tailnet)";
      type = "http";
      url = "http://${tailnet}:3001";
      group = "Monitoring";
    }
    {
      name = "PostgreSQL";
      type = "port";
      hostname = "127.0.0.1";
      port = 5432;
      group = "Infra";
    }
    {
      name = "OpenSSH";
      type = "port";
      hostname = "127.0.0.1";
      port = 22;
      group = "Infra";
    }
  ];

  desiredState = pkgs.writeText "uptime-kuma-monitors.json" (
    builtins.toJSON {
      tag = tagName;
      inherit notificationName groups monitors;
    }
  );

  pythonEnv = pkgs.python3.withPackages (ps: [ ps.uptime-kuma-api ]);
in
{
  age.secrets = lib.mkIf config.host.uptimeKumaSync {
    uptime-kuma-sync = {
      file = ../../secrets/uptime-kuma-sync.env.age;
      mode = "0400";
    };
  };

  services.uptime-kuma = {
    enable = true;
    settings = {
      HOST = "0.0.0.0";
      PORT = "3001";
    };
  };

  # Declarative monitor sync (Socket.IO via uptime-kuma-api).
  # Requires admin account already created in the Kuma UI and credentials in
  # secrets/uptime-kuma-sync.env.age (KUMA_USERNAME, KUMA_PASSWORD, NTFY_TOPIC).
  systemd.services.uptime-kuma-sync = lib.mkIf config.host.uptimeKumaSync {
    description = "Sync Nix-declared monitors into Uptime Kuma";
    after = [
      "uptime-kuma.service"
      "ntfy-sh.service"
    ];
    requires = [ "uptime-kuma.service" ];
    wants = [ "ntfy-sh.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      EnvironmentFile = config.age.secrets.uptime-kuma-sync.path;
      ExecStart = "${pythonEnv}/bin/python ${./uptime-kuma-sync.py} ${desiredState}";
    };
  };

  # Uptime Kuma does NOT support running behind a subpath (confirmed upstream) —
  # it stays directly reachable over Tailscale on its own port, not proxied.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 3001 ];
}
