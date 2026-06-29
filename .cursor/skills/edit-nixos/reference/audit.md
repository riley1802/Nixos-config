# Config audit checklist

Run this cross-reference pass **before every handoff** and after non-trivial changes. Fix stale entries before committing.

## Import graph

- [ ] Every path in `configuration.nix` `imports` exists on disk
- [ ] Every path in `home.nix` `imports` exists on disk
- [ ] Every file under `modules/services/` is imported in `configuration.nix`
- [ ] No orphaned module files (on disk but not imported)
- [ ] No duplicate imports

## Secrets (agenix)

- [ ] Every `age.secrets.*.file` in modules points to an existing `secrets/*.age`
- [ ] Every `secrets/*.age` (except templates) is listed in `secrets/secrets.nix`
- [ ] Every `secrets/secrets.nix` entry has a matching `age.secrets` declaration
- [ ] No plaintext secrets in `.nix`, `.md`, or env files
- [ ] No runtime-only secret generation (use agenix instead)

## Flake

- [ ] `flake.nix` inputs match modules that use them (`agenix`, `home-manager`, `pkgsUnstable`)
- [ ] `flake.lock` committed when inputs change
- [ ] `specialArgs` includes everything modules expect (`inputs`, `pkgsUnstable`)

## Reference docs

- [ ] [layout.md](layout.md) matches `configuration.nix` + `home.nix`
- [ ] [services.md](services.md) matches enabled services and ports
- [ ] [flake.md](flake.md) matches `flake.nix`
- [ ] [home-manager.md](home-manager.md) matches `home.nix`
- [ ] [secrets.md](secrets.md) matches `secrets/` directory

## README

- [ ] Service table URLs/ports match modules
- [ ] Usage commands still valid
- [ ] New services documented
- [ ] Removed services not still documented

## Stale config patterns

- [ ] No references to removed packages/services (grep repo for old names)
- [ ] No dead `environment.systemPackages` entries for removed tools
- [ ] Firewall: `openFirewall = false` unless intentionally public
- [ ] Localhost-only services still bound to `127.0.0.1`
- [ ] `system.stateVersion` / `home.stateVersion` unchanged

## Validation commands

```sh
nix flake check
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --no-link
nix fmt -- --check .
```
