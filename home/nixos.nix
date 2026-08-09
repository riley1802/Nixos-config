{ ... }:

# Home Manager entry for the desktop host (`nixos`) only.
# Shared stack plus desktop-only tools (GitNexus).
{
  imports = [
    ./common.nix
    ./programs/gitnexus.nix
  ];
}
