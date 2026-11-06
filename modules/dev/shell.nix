# Global development shell. Enter it from anywhere with nix dev.
{ config, lib, ... }:
let
  cfg = config.my.dev.shell;
in
{
  options.my.dev.shell.enable = lib.mkEnableOption "Global development shell. Enter it from anywhere with nix dev";

  config = lib.mkIf cfg.enable {
    # Bash has no two-word alias, and Nix 2.34 has no `nix dev` command.
    # This function only redirects that one invocation. Other `nix` commands
    # still run the real binary. The flake lives outside modules/ so it is
    # not imported as a NixOS module. Edits to dev/flake.nix need `git add`
    # before the next `nix dev` sees them.
    # https://nix.dev/manual/nix/stable/command-ref/new-cli/nix3-develop
    environment.interactiveShellInit = ''
      nix() {
        if [ "''${1-}" = dev ]; then
          shift
          command nix develop "path:/etc/nixos?dir=dev" "$@"
        else
          command nix "$@"
        fi
      }
    '';
  };
}
