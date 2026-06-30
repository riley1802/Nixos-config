{ ... }:

{
  # Build aarch64 packages (e.g. nixos-pi SD image) on this x86_64 desktop.
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
}
