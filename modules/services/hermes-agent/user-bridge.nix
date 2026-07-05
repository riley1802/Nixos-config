# Point rileyt's CLI at the same HERMES_HOME as the gateway/dashboard.
{ lib, config, ... }:

let
  agentCfg = config.services.hermes-agent;
  user = "rileyt";
  userHome = "/home/${user}";
  userHermes = "${userHome}/.hermes";
  systemHermes = "${agentCfg.stateDir}/.hermes";
in
{
  config = lib.mkIf agentCfg.enable {
    system.activationScripts.hermes-user-bridge = lib.stringAfter [ "hermes-agent-setup" ] ''
      target="${systemHermes}"
      link="${userHermes}"
      if [ ! -d "$target" ]; then
        echo "hermes-user-bridge: skip — system HERMES_HOME missing"
        exit 0
      fi
      if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then
        exit 0
      fi
      if [ -e "$link" ] && [ ! -L "$link" ]; then
        backup="''${link}.bak.$(date +%s)"
        echo "hermes-user-bridge: backing up $link -> $backup"
        mv "$link" "$backup"
      elif [ -L "$link" ]; then
        rm -f "$link"
      fi
      ln -sfn "$target" "$link"
      chown -h ${user}:users "$link" 2>/dev/null || true
      echo "hermes-user-bridge: $link -> $target"
    '';
  };
}
