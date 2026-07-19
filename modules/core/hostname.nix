{ lib, ... }:

{
  # Default hostname; hosts override this in their configuration.nix (e.g. legion).
  networking.hostName = lib.mkDefault "nixos";
}
