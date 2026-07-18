# Flake

- Output: `.#nixosConfigurations.nixos`
- Stable: `nixpkgs` → `nixos-26.05`
- Unstable: `nixpkgs-unstable` → `pkgsUnstable` in `specialArgs`
- Home Manager: `release-26.05`, embedded in `flake.nix`, user `./home.nix`
- agenix: `github:ryantm/agenix`, module + CLI in flake
- Formatter: `nix fmt .` or `nix fmt -- --check .` (nixpkgs-fmt). Bare `nix fmt` with no paths hangs — see lessons.md.
- CI: `.github/workflows/check.yml` — fmt check, flake check, eval toplevel
- Overlays: none
- `specialArgs`: `pkgsUnstable`, `inputs`
- Home Manager `extraSpecialArgs`: `pkgsUnstable`, `inputs` (so HM modules can use unstable packages)
