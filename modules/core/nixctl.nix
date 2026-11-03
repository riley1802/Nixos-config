# nixctl, the one command for changing this computer (script: tools/nixctl.sh).
{ config, pkgs, ... }:
let
  nixctl = pkgs.writeShellApplication {
    name = "nixctl";
    runtimeInputs = with pkgs; [
      config.nix.package
      coreutils
      diffutils
      findutils
      gawk
      git
      gnugrep
      gnused
      jq
      systemd
      util-linux
    ];
    text = builtins.readFile ../../tools/nixctl.sh;
  };
in
{
  environment.systemPackages = [ nixctl ];

  # nixctl applies changes without a password prompt, so an agent can use
  # it unattended. Anything that can run commands as this user can change
  # the whole system through it.
  security.sudo.extraRules = [
    {
      users = [ config.my.user ];
      commands = [
        {
          command = "/run/current-system/sw/bin/nixctl";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
