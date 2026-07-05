{ inputs, lib, ... }:

let
  hermesEnvAge = ../../../secrets/hermes-env.age;
  hasHermesEnv = builtins.pathExists hermesEnvAge;
in
{
  imports =
    [
      inputs.hermes-agent.nixosModules.default
      ./user-bridge.nix
      # ./honcho.nix # Honcho memory — uncomment when ready
    ]
    ++ lib.optionals hasHermesEnv [
      ./secrets.nix
    ];

  services.hermes-dashboard.enable = true;

  services.hermes-agent = {
    enable = true;
    addToSystemPackages = true;

    extraDependencyGroups = [
      "messaging"
      "edge-tts"
      "voice"
      "web"
    ];

    settings = import ./settings.nix { inherit hasHermesEnv lib; };

    documents = {
      "SOUL.md" = ../../hermes/SOUL.md;
      "USER.md" = ../../hermes/USER.md;
    };

    workingDirectory = "/var/lib/hermes/workspace";

    environment = {
      SEARXNG_URL = "http://127.0.0.1:8888";
      GATEWAY_ALLOW_ALL_USERS = "false";
    };
  };

  users.users.rileyt.extraGroups = [ "hermes" ];

  # Hermes reads SOUL.md from HERMES_HOME (~/.hermes), but the upstream module
  # only installs documents into workingDirectory — sync identity files on activate.
  system.activationScripts.hermes-identity-sync = lib.stringAfter [ "hermes-agent-setup" ] ''
    hermesHome="/var/lib/hermes/.hermes"
    workspace="/var/lib/hermes/workspace"
    for doc in SOUL.md USER.md; do
      if [ -f "$workspace/$doc" ]; then
        install -o hermes -g hermes -m 0660 "$workspace/$doc" "$hermesHome/$doc"
      fi
    done
  '';

  systemd.services.hermes-agent = {
    after = [
      "llama-cpp.service"
      "searx.service"
    ];
    requires = [
      "llama-cpp.service"
    ];
  };

  warnings =
    lib.optional (!hasHermesEnv) ''
      Hermes Discord is not configured: create secrets/hermes-env.age with
      DISCORD_BOT_TOKEN and DISCORD_ALLOWED_USERS (see secrets/hermes-env.example).
      CLI + gateway cron run without messaging until then.
    '';
}
