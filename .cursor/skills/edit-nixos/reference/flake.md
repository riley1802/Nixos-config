# Flake

- Output: `.#nixosConfigurations.nixos` (active desktop); `.#nixosConfigurations.legion` still defined but unused
- Stable: `nixpkgs` → `nixos-26.05`
- Unstable: `nixpkgs-unstable` → `pkgsUnstable` in `specialArgs`
- Home Manager: `release-26.05`, embedded in `flake.nix`
  - Desktop (`nixos`): `./home/nixos.nix` (common + GitNexus)
  - Legion: `./home.nix` (common only)
- agenix: `github:ryantm/agenix`, module + CLI in flake
- llm-agents: `github:numtide/llm-agents.nix` — GitNexus package (`inputs.llm-agents.packages.<system>.gitnexus`)
- Home Manager: `backupFileExtension = "hm-bak"` (avoids activation failure on leftover plain files)
- Formatter: `nix fmt .` or `nix fmt -- --check .` (nixpkgs-fmt). Bare `nix fmt` with no paths hangs — see lessons.md.
- CI: `.github/workflows/check.yml` — fmt check, flake check, eval toplevel
- Overlays: none
- `specialArgs`: `pkgsUnstable`, `inputs`
- Home Manager `extraSpecialArgs`: `pkgsUnstable`, `inputs` (so HM modules can use unstable packages and flake inputs)
