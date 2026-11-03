# Nix itself: flakes, unfree packages, and agenix.
{ inputs, ... }:
{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.allowUnfree = true;
  environment.systemPackages = [
    inputs.agenix.packages.x86_64-linux.default
  ];
}
