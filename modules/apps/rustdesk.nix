# RustDesk host for Android control over the tailnet only.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.apps.rustdesk;

  rustdeskExe = lib.getExe pkgs.rustdesk-flutter;

  rustdeskConfigSeed = pkgs.writeShellApplication {
    name = "rustdesk-direct-access-seed";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      set -euo pipefail
      home=/home/${config.my.user}
      conf="$home/.config/rustdesk/RustDesk2.toml"
      mkdir -p "$(dirname "$conf")"
      export RUSTDESK_HOME="$home"
      ${pkgs.python3}/bin/python3 <<'PY'
      import os
      import re

      home = os.environ["RUSTDESK_HOME"]
      conf = os.path.join(home, ".config", "rustdesk", "RustDesk2.toml")
      required = {
          "direct-server": "'Y'",
          "direct-access-port": "'21118'",
      }

      if not os.path.isfile(conf):
          with open(conf, "w") as f:
              f.write("[options]\n")
              for key, val in required.items():
                  f.write(f"{key} = {val}\n")
          raise SystemExit(0)

      with open(conf) as f:
          text = f.read()

      missing = {
          k: v
          for k, v in required.items()
          if not re.search(rf"^\s*{re.escape(k)}\s*=", text, re.MULTILINE)
      }
      if not missing:
          raise SystemExit(0)

      lines = text.splitlines(keepends=True)
      out = []
      in_options = False
      inserted = False
      opt_re = re.compile(r"^\s*\[options\]\s*$", re.IGNORECASE)

      for line in lines:
          if opt_re.match(line.rstrip("\n")):
              in_options = True
              out.append(line)
              continue
          if in_options and re.match(r"^\s*\[", line) and not opt_re.match(line.rstrip("\n")):
              if not inserted:
                  for key, val in missing.items():
                      out.append(f"{key} = {val}\n")
                  inserted = True
              in_options = False
          out.append(line)

      if in_options and not inserted:
          for key, val in missing.items():
              out.append(f"{key} = {val}\n")
          inserted = True

      if not inserted and not any(opt_re.match(l.rstrip("\n")) for l in lines):
          out.append("\n[options]\n")
          for key, val in missing.items():
              out.append(f"{key} = {val}\n")

      with open(conf, "w") as f:
          f.writelines(out)
      PY
    '';
  };
in
{
  options.my.apps.rustdesk.enable = lib.mkEnableOption "RustDesk remote desktop on the tailnet";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.network.tailscale.enable;
        message = "apps/rustdesk needs network/tailscale (nixctl enable network/tailscale)";
      }
    ];

    environment.systemPackages = [ pkgs.rustdesk-flutter ];

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 21118 ];

    boot.kernelModules = [ "uinput" ];

    users.users.${config.my.user}.extraGroups = [ "input" ];

    services.udev.extraRules = ''
      KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
    '';

    # The Flutter wrapper puts pipewiresrc on GST_PLUGIN_SYSTEM_PATH_1_0.
    # The capture process is started with `sudo -u $USER -- env ...`, and
    # sudo's env_reset drops that variable, so Wayland capture cannot load
    # pipewiresrc. Keep it. The pipeline also needs videoconvert and appsink
    # from that same path.
    # https://github.com/rustdesk/rustdesk/blob/1.5.0/libs/scrap/src/wayland/pipewire.rs
    security.sudo.extraConfig = ''
      Defaults:${config.my.user} env_keep += "GST_PLUGIN_SYSTEM_PATH_1_0"
    '';

    environment.etc."xdg/autostart/rustdesk.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=RustDesk
      Comment=Remote desktop host on the tailnet
      Exec=${rustdeskExe} --service
      Icon=rustdesk
      Terminal=false
      Categories=Network;RemoteAccess;
      OnlyShowIn=KDE;
      X-KDE-autostart-after=panel
    '';

    systemd.services.rustdesk-direct-access-seed = {
      description = "Seed RustDesk direct-access settings before first launch";
      wantedBy = [ "multi-user.target" ];
      before = [ "display-manager.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = config.my.user;
        ExecStart = "${rustdeskConfigSeed}/bin/rustdesk-direct-access-seed";
      };
    };
  };
}
