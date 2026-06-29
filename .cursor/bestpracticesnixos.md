# NixOS Configuration Best Practices

Curated rules for maintaining `/etc/nixos`. Synthesized from the [NixOS Wiki](https://wiki.nixos.org/), [Nix manual](https://nix.dev/), [Home Manager docs](https://home-manager.dev/), community guides (Discourse, dendritic/deferred-module patterns), and lessons from this machine.

Use alongside `@edit-nixos`, [lessons.md](skills/edit-nixos/lessons.md), and [reference/](skills/edit-nixos/reference/).

---

## 1. Philosophy

| Principle | Rule |
|-----------|------|
| Declarative | If it is not in git, it is not real. Track `/etc/nixos` in a flake repo. |
| Reproducible | Same `flake.lock` → same system. Pin inputs; commit the lockfile. |
| Modular | One concern per file. Top-level entrypoints are import lists only. |
| Minimal diff | Change only what the task requires. Match existing style. |
| Safe by default | Localhost-first services, closed firewall, no secrets in the store. |
| Validate before switch | `nix flake check` → build toplevel → then rebuild. |

Start simple. Add structure when duplication or file size makes changes painful — do not over-engineer a single-host setup into a multi-machine framework prematurely.

---

## 2. Repository layout

### Recommended for this config (single host)

```
/etc/nixos/
├── flake.nix              # inputs, outputs, specialArgs
├── flake.lock             # committed — always
├── configuration.nix      # system import list only
├── hardware-configuration.nix  # generated; rarely hand-edited
├── home.nix               # Home Manager import list only
├── modules/
│   ├── core/              # boot, locale, networking, system
│   ├── desktop/           # GNOME, audio (system)
│   ├── hardware/          # nvidia, etc.
│   ├── programs/          # system packages & program config
│   ├── services/          # one file per service
│   └── users/
└── home/
    ├── core/
    ├── desktop/
    └── programs/
```

### Layout rules

- **One service = one file** under `modules/services/<name>.nix`.
- **Never** put business logic in `configuration.nix` or `home.nix` — only `imports = [ ... ]`.
- Colocate packages with the module that needs them (`environment.systemPackages` in the relevant module, not a giant global list).
- Split Home Manager the same way: `home/programs/`, `home/desktop/`, etc.
- Do not edit `hardware-configuration.nix` unless hardware changed or the user explicitly asks.

### When you outgrow single-host layout

Common evolutions (only when needed):

| Pattern | When | Idea |
|---------|------|------|
| `hosts/<hostname>/` | Multiple machines | Per-host `configuration.nix` + hardware |
| Feature modules with `enable` | Reuse across hosts | `options.myfeature.enable` + `lib.mkIf` |
| Auto-import (`import-tree`, haumea) | 40+ modules | Drop new `.nix` files without editing import lists |
| Dendritic / deferred composition | Cross-platform (NixOS + HM + darwin) | Organize by feature/aspect, not by host |

For one machine, manual imports in `configuration.nix` are fine and easier to reason about.

---

## 3. Flakes

### Inputs

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

  home-manager = {
    url = "github:nix-community/home-manager/release-26.05";
    inputs.nixpkgs.follows = "nixpkgs";  # required
  };
};
```

### Flake rules

| Rule | Why |
|------|-----|
| Commit `flake.lock` | Reproducibility across machines and CI |
| Use `inputs.*.follows = "nixpkgs"` | One nixpkgs eval; fewer version mismatches |
| Pin stable to a release branch | Predictable upgrades (`nixos-26.05`, not rolling stable) |
| Use `pkgsUnstable` via `specialArgs` for select packages | Newer tools without flipping the whole system |
| Prefer `nixpkgs.legacyPackages.${system}` in flake outputs | Avoids extra `import` of nixpkgs |
| Enable flakes in config | `nix.settings.experimental-features = [ "nix-command" "flakes" ]` |
| Git-track all flake sources | Untracked files are **ignored** by flakes and break builds |

### Purity

- All `fetchurl` / `fetchzip` calls need a `sha256`/`hash`.
- Avoid `builtins.getEnv`, `builtins.currentSystem`, and reading paths outside the flake in pure eval.
- Pass `system` explicitly (`x86_64-linux`) instead of relying on impure builtins.

### Updating

```sh
nix flake update              # refresh lock from input URLs
nix flake update nixpkgs      # update one input only
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

Read release notes before bumping `nixpkgs` branch.

---

## 4. NixOS module system

### Module structure

```nix
{ config, lib, pkgs, ... }:

let
  cfg = config.services.my-service;
in
{
  options.services.my-service = {
    enable = lib.mkEnableOption "my service";
  };

  config = lib.mkIf cfg.enable {
    # service config here
  };
}
```

### Module system rules

| Do | Don't |
|----|-------|
| `let cfg = config.path.to.option` | Repeat long `config.` paths everywhere |
| `lib.mkIf cfg.enable { ... }` | Plain `if cfg.enable then { ... } else { }` when condition reads config |
| `lib.mkMerge [ a b ]` | `a // b` when values use `mkIf`, `mkForce`, etc. |
| `lib.mkDefault` for overridable defaults | Hard defaults that hosts cannot override |
| `lib.mkForce` sparingly, with comment | Force overrides without documenting why |
| `imports = [ ./other.nix ]` for submodules | Monolithic 500-line modules |

Circular option references are a common footgun — if config depends on an option defined in the same module, wrap with `mkIf`.

### Custom modules

- Provide `enable = mkEnableOption` when the whole module can be toggled.
- Document non-obvious options in `description`.
- Respect upstream modules: do not fight their defaults without `mkForce` and a reason.

---

## 5. Home Manager

### Integration (NixOS module)

```nix
home-manager.nixosModules.home-manager
{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = { inherit inputs; };
  home-manager.users.rileyt = import ./home.nix;
}
```

| Setting | Purpose |
|---------|---------|
| `useGlobalPkgs = true` | Single nixpkgs eval; HM uses system `pkgs` |
| `useUserPackages = true` | Packages via NixOS user options / proper PATH integration |
| `extraSpecialArgs` | Pass flake inputs to HM modules |

### Home Manager rules

- Set `home.stateVersion` once at first install — **never change** unless you have migrated all affected state (same rule as `system.stateVersion`).
- Use `force = true` on `xdg.configFile` when replacing dotfiles that may already exist on disk.
- User/desktop preferences → `home/`. System daemons → `modules/services/`.
- HM rebuilds with the system (`nixos-rebuild switch`) — no separate `home-manager switch` needed when embedded.

---

## 6. State, versions, and persistence

### stateVersion

```nix
system.stateVersion = "XX.XX";  # set at install, do not bump casually
home.stateVersion = "XX.XX";
```

- **Never change** after initial install unless release notes explicitly instruct it and you have migrated data.
- Changing it can move database paths, permissions, or defaults and cause **silent data loss**.
- New machines can use the current release; existing machines keep their original value.

### Persistent data

- Service state → `/var/lib/<service>` with `systemd.tmpfiles.rules` or service-native options.
- Model weights, databases, and secrets → outside the nix store, with explicit ownership/mode.
- Document persistent paths in `reference/services.md` and README.

---

## 7. Security

### Secrets

The nix store is **world-readable**. Never put secrets in `.nix` files or derivations.

**This config standard: agenix only.** All secrets go in `secrets/*.age` via `agenix -e`.

| Approach | Use when |
|----------|----------|
| **agenix** (required here) | Every secret — Tailscale keys, service tokens, passwords |
| Runtime-generated secrets | **Do not use** — migrate to agenix instead |
| Plaintext in git | **Never** |

Secrets decrypt at activation to `/run/agenix/`, not at eval time.

### Network exposure

| Rule | Example |
|------|---------|
| Bind local services to `127.0.0.1` | llama.cpp, SearXNG |
| `openFirewall = false` on every service unless public access is intended | Default for new services |
| Explicitly open ports in `networking.firewall` when exposing to LAN/WAN | Conscious admin decision |
| Review `hardware-configuration.nix` and user modules before public git push | Disk UUIDs, hostnames |

### Systemd hardening

For custom services, consider `DynamicUser`, `ProtectSystem`, `PrivateTmp`, and dedicated service users — unless the service needs broad filesystem access (e.g. llama.cpp running as `rileyt` for GPU/model access).

---

## 8. Services

### New service checklist

- [ ] Dedicated `modules/services/<name>.nix`
- [ ] One import line in `configuration.nix`
- [ ] `enable` option if toggling on/off matters
- [ ] Persistent state directory if needed
- [ ] `openFirewall = false` unless exposure is intended
- [ ] Localhost bind for internal-only APIs
- [ ] README + `reference/services.md` updated
- [ ] `systemctl status <service>` documented

### Rebuild subcommands

| Command | Use |
|---------|-----|
| `switch` | Build, activate, set boot default |
| `test` | Activate without adding boot entry — good for risky changes |
| `boot` | Build and set boot default without activating now |
| `build` | Build only, no activation |
| `--rollback` | Emergency revert — **only when user asks** |

Safe sequence for this config:

```sh
nix flake check
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --no-link
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

---

## 9. Packages and overlays

### Preference order

1. `pkgs.<name>` from stable nixpkgs
2. `pkgsUnstable.<name>` via `specialArgs`
3. Custom derivation in repo (last resort)
4. Overlay in `flake.nix` (only when patching or wrapping is ongoing)

### Overlay rules

- Keep overlays minimal — prefer `specialArgs` + explicit package args in modules.
- Pin custom derivations with fixed-version `fetchurl` hashes.
- For unpackaged `.deb`/Electron apps: expect patchelf, wrapper, and runtime `LD_LIBRARY_PATH` work — see lessons.md.

---

## 10. Testing and CI

### Local validation

```sh
nix fmt -- --check .     # or nix fmt to fix
nix flake check
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --no-link
```

### CI (this repo)

`.github/workflows/check.yml` runs fmt check, flake check, and eval toplevel on push/PR. Keep CI green before pushing.

### Optional (when complexity grows)

- `checks` output in flake for integration tests (`pkgs.nixosTest`)
- `nixos-rebuild build-vm` for manual smoke test in QEMU
- Pre-commit hooks for `nix fmt`

---

## 11. Documentation

Update on every meaningful change:

| File | When |
|------|------|
| `README.md` | Services, layout, usage, endpoints — always (except trivial syntax) |
| `.cursor/skills/edit-nixos/reference/` | Any config change affecting layout, services, flake, machine |
| `.cursor/skills/edit-nixos/lessons.md` | Any error encountered and fixed |
| This file | When a new **general** best practice is learned |

---

## 12. Git workflow (this repo)

| Action | Policy |
|--------|--------|
| Commit | Automatic after validated changes |
| Push to `main` | **Always ask user first** |
| Commit message | Imperative, 1–2 sentences, focus on why |
| `flake.lock` | Commit with intentional input updates |
| Secrets | Never commit plaintext |
| Force push | Never to `main` without explicit user request |

---

## 13. Anti-patterns

| Anti-pattern | Why it hurts |
|--------------|--------------|
| Monolithic `configuration.nix` | Unreviewable, merge conflicts, unclear ownership |
| Secrets in nix files | World-readable store |
| Changing `stateVersion` to "current release" | Data path migrations, breakage |
| Skipping `flake check` before switch | Broken system activation |
| Untracked new `.nix` files | Flake silently ignores them |
| `builtins.fetchTarball` without hash | Impure, unreproducible |
| Multiple unrelated services in one file | Violates this repo's modularity rule |
| Auto-opening firewall on service enable | Surprises, unintended exposure |
| Duplicating nixpkgs without `follows` | Slow evals, subtle version conflicts |
| `--option require-sigs false` / disabled sandbox | Security risk |

---

## 14. Alignment with this machine

These practices are tuned for riley's setup:

- Flake host: `nixos`, user: `rileyt`
- Stable `nixos-26.05` + `pkgsUnstable` for CUDA llama.cpp
- GNOME desktop, dual NVIDIA GPUs
- Local AI: llama.cpp (8080) + SearXNG (8888), localhost-only
- Home Manager as NixOS module with `useGlobalPkgs` / `useUserPackages`

When a general best practice conflicts with an explicit user preference in `@edit-nixos` or user rules, **ask** — user preference wins.

---

## Sources

- [NixOS Wiki — Flakes](https://wiki.nixos.org/wiki/Flakes)
- [NixOS Wiki — NixOS system configuration](https://wiki.nixos.org/wiki/NixOS_system_configuration)
- [NixOS Wiki — NixOS modules](https://wiki.nixos.org/wiki/NixOS:Modules)
- [NixOS Wiki — FAQ: When do I update stateVersion](https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion)
- [NixOS Wiki — Updating NixOS](https://wiki.nixos.org/wiki/Updating_NixOS)
- [NixOS Wiki — Firewall](https://wiki.nixos.org/wiki/Firewall)
- [NixOS Wiki — Module system vs Nix language](https://wiki.nixos.org/wiki/The_Nix_Language_versus_the_NixOS_Module_System)
- [Nix manual — nix flake](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-flake.html)
- [Nix manual — Secrets in the store](https://github.com/NixOS/nix/blob/master/doc/manual/source/store/secrets.md)
- [Home Manager — NixOS module](https://home-manager.dev/manual/unstable/#ch-nixos-module)
- [sops-nix](https://github.com/Mic92/sops-nix)
- [Discourse — Config structure](https://discourse.nixos.org/t/how-do-you-structure-your-nixos-configs/65851)
- [Discourse — Secrets overview](https://discourse.nixos.org/t/handling-secrets-in-nixos-an-overview-git-crypt-agenix-sops-nix-and-when-to-use-them/35462)
- [import-tree / Dendritic pattern](https://github.com/denful/import-tree)
