# Flake

- Output: `.#nixosConfigurations.nixos`
- Stable: `nixpkgs` → `nixos-26.05`
- Unstable: `nixpkgs-unstable` → `pkgsUnstable` in `specialArgs`
- Home Manager: `release-26.05`, embedded in `flake.nix`, user `./home.nix`
- agenix: `github:ryantm/agenix`, module + CLI in flake
- hermes-agent: `github:NousResearch/hermes-agent`, NixOS module + CLI package
- Formatter: `nix fmt` (nixpkgs-fmt)
- CI: `.github/workflows/check.yml` — fmt check, flake check, eval toplevel
- Overlays: none
- `specialArgs`: `pkgsUnstable`, `inputs`
