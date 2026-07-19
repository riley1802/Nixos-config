# NixOS Configuration Best Practices

Curated rules for maintaining `/etc/nixos`. Synthesized from the [NixOS Wiki](https://wiki.nixos.org/), [Nix manual](https://nix.dev/), [Home Manager docs](https://home-manager.dev/), community guides (Discourse, dendritic/deferred-module patterns), and lessons from this machine.

### Document hierarchy

| Doc | Role |
|-----|------|
| **This file** | Summary of philosophy, layout, security, validation, and git policy |
| [preferences.md](skills/edit-nixos/reference/preferences.md) | Standing user decisions: GitHub source of truth, seamless desktop+laptop |
| [@edit-nixos](skills/edit-nixos/SKILL.md) | Full agent workflow: discovery checklist, implementation, audit, handoff |
| [reference/](skills/edit-nixos/reference/) | Living index of current config state (update on every config change) |
| [lessons.md](skills/edit-nixos/lessons.md) | Resolved errors — log as soon as cause and fix are known |
| [troubleshooting.md](skills/edit-nixos/troubleshooting.md) | Debugging commands and common failure modes |
| [@agent-rules-books](skills/agent-rules-books/SKILL.md) | On-demand coding rules from classic SE books ([source](https://github.com/ciembor/agent-rules-books)) |
| [rules/](rules/) | Cursor project rules: NixOS always-on + scoped `.nix` + on-demand book index |

When this file and `@edit-nixos` overlap, the skill has the detailed workflow; this file has the rules and rationale.

---

## 1. Philosophy

| Principle | Rule |
|-----------|------|
| Declarative | If it is not in git **and on GitHub `main`**, it is not finished. Local `/etc/nixos` is a checkout of the remote. |
| Fleet-first | Desktop (`nixos`) and laptop (`legion`) share one flake. Prefer shared modules; host-only deltas via `hosts/<name>/` and `host.*` facts. |
| Reproducible | Same `flake.lock` → same system. Pin inputs; commit the lockfile. |
| Modular | One concern per file. Top-level entrypoints are import lists only. |
| Minimal diff | Change only what the task requires. Match existing style. |
| Safe by default | Localhost-first services, closed firewall, no secrets in the store. |
| Validate before switch | `nix fmt .` → `nix flake check` → build toplevel → config audit → then rebuild. Never bare `nix fmt` (hangs). |

**GitHub is the source of truth** (`github.com/riley1802/Nixos-config`, branch `main`). Both machines keep `/etc/nixos` in sync with that remote so desktop and laptop stay seamless. Standing preferences: [preferences.md](skills/edit-nixos/reference/preferences.md).

---

## 2. Research before implementation

Before writing or editing config for a non-trivial change, **search the web** for the current best way to implement it. NixOS evolves quickly; wiki pages, Discourse threads, and upstream module docs often beat model training data.

### When to research

| Research first | Skip research |
|----------------|---------------|
| New services, packages, or integrations | Typo fixes, one-line tweaks |
| Unfamiliar options (agenix, GPU/CUDA, custom derivations, HM modules) | Bumping a package already in config |
| Upgrading flake inputs or migrating patterns | Docs-only edits |
| Anything where the obvious approach might be outdated or suboptimal | Changes that mirror an existing module in this repo |

### Workflow

1. **Search** — use web search for NixOS-specific guidance: official wiki, nixpkgs options, Home Manager manual, GitHub issues, Discourse.
2. **Summarize** — tell the user what you found: recommended approach, alternatives, trade-offs, and how it fits this repo's layout and security rules (see sections 3–8).
3. **Ask** — explicitly ask whether to proceed with implementation using that approach. **Do not edit files until the user confirms.**

For the full pre-edit discovery checklist (scope, persistence, packages, removal, apply, git), see [@edit-nixos](skills/edit-nixos/SKILL.md).

Example handoff:

> I looked up how to add X on NixOS. The recommended approach is … (module Y, localhost bind, agenix for secrets). Alternatives: … Trade-offs: …
>
> Do you want me to implement this?

### Research quality

- Prefer **NixOS Wiki**, **nixpkgs source/options**, **Home Manager manual**, and **recent Discourse** over generic Stack Overflow.
- Cross-check against [lessons.md](skills/edit-nixos/lessons.md) and existing modules in this repo — reuse patterns before inventing new ones.
- If sources conflict, say so and recommend one path with reasons.

---

## 3. Repository layout

### Canonical layout (this config)

```
/etc/nixos/
├── flake.nix                    # inputs, mkNixos helper, one output per host
├── flake.lock                   # committed — always
├── home.nix                     # HM entry: desktop (nixos)
├── home-legion.nix              # HM entry: laptop (legion)
├── hosts/
│   ├── common.nix               # shared system profile (all hosts)
│   ├── nixos/                   # desktop
│   └── legion/                  # laptop
├── modules/
│   ├── core/                    # boot, locale, host-facts, networkmanager, nix, agenix, openssh
│   ├── desktop/                 # gdm/gnome (desktop), cinnamon (laptop), audio
│   ├── hardware/                # graphics, nvidia, nvidia-prime
│   ├── programs/
│   ├── services/                # one file per service (shared stack)
│   └── users/
├── home/
│   ├── common.nix               # shared HM modules
│   ├── core/
│   ├── desktop/
│   └── programs/
└── secrets/
    ├── secrets.nix              # agenix public keys (rileyt + each host)
    └── *.age                    # encrypted secrets (committed; rekey for every host)
```

The flake's `mkNixos` helper wires agenix, Home Manager, and `specialArgs` (`pkgsUnstable`, `inputs`) per host.

### Layout rules

- **One concern = one file** — a service, program, dconf domain, or single NixOS option group. No bundled "system defaults" catch-alls.
- **One service = one file** under `modules/services/<name>.nix`.
- Shared services/programs go in `hosts/common.nix`; host-only imports (hardware, desktop DE) go in `hosts/<name>/configuration.nix`.
- **`hosts/*/configuration.nix`**, **`home.nix`**, and **`home-legion.nix`** are import lists only — no logic.
- Colocate packages with the module that needs them (`environment.systemPackages` in the relevant module, not a giant global list).
- Split Home Manager the same way: `home/programs/`, `home/desktop/`, etc.; share via `home/common.nix`.
- Do not edit `hosts/*/hardware-configuration.nix` unless hardware changed or the user explicitly asks.
- Modules that need unstable packages or flake inputs must declare them in the function head: `{ pkgsUnstable, inputs, ... }:`.
- Paths from `modules/services/` to secrets use relative paths (e.g. `../../secrets/foo.age`).
- New host → add `nixosConfigurations.<name>`, host key in `secrets/secrets.nix`, run `agenix -r` on an existing machine, push rekeyed `.age` files.

### When adding another machine

| Pattern | When | Idea |
|---------|------|------|
| Additional `hosts/<name>/` | New machine | Reuse `mkNixos` + `hosts/common.nix`; set `host.*` facts; rekey secrets |
| Feature modules with `enable` | Reuse across hosts | `options.myfeature.enable` + `lib.mkIf` |
| Auto-import (`import-tree`, haumea) | 40+ modules | Drop new `.nix` files without editing import lists |

---

## 4. Flakes

### Inputs

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

  home-manager = {
    url = "github:nix-community/home-manager/release-26.05";
    inputs.nixpkgs.follows = "nixpkgs";  # required
  };

  agenix = {
    url = "github:ryantm/agenix";
    inputs.nixpkgs.follows = "nixpkgs";
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

## 5. NixOS module system

### Module structure

```nix
{ config, lib, pkgs, pkgsUnstable, ... }:

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
| Declare `pkgsUnstable`, `inputs` in `{ ... }:` when used | Assume specialArgs without listing them |

Circular option references are a common footgun — if config depends on an option defined in the same module, wrap with `mkIf`.

### Custom modules

- Provide `enable = mkEnableOption` when the whole module can be toggled.
- Document non-obvious options in `description`.
- Respect upstream modules: do not fight their defaults without `mkForce` and a reason.

---

## 6. Home Manager

### Integration (NixOS module)

Wired in `flake.nix` via `mkNixos`:

```nix
home-manager.nixosModules.home-manager
{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.rileyt = import ./home.nix;
}
```

| Setting | Purpose |
|---------|---------|
| `useGlobalPkgs = true` | Single nixpkgs eval; HM uses system `pkgs` |
| `useUserPackages = true` | Packages via NixOS user options / proper PATH integration |

### Home Manager rules

- Set `home.stateVersion` once at first install — **never change** unless you have migrated all affected state (same rule as `system.stateVersion`).
- Use `force = true` on `xdg.configFile` when replacing dotfiles that may already exist on disk.
- User/desktop preferences → `home/`. System daemons → `modules/services/`.
- HM rebuilds with the system (`nixos-rebuild switch`) — no separate `home-manager switch` needed when embedded.

---

## 7. State, versions, and persistence

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

## 8. Security

### Secrets

The nix store is **world-readable**. Never put secrets in `.nix` files or derivations.

**This config standard: agenix only.** All secrets go in `secrets/*.age` via `agenix -e`.

| Approach | Use when |
|----------|----------|
| **agenix** (required here) | Every secret — Tailscale keys, service tokens, passwords |
| Runtime-generated secrets | **Do not use** — migrate to agenix instead |
| Plaintext in git | **Never** |

Secrets decrypt at activation to `/run/agenix/`, not at eval time.

**Never ask the user to paste secrets in chat.** Direct them to run `agenix -e secrets/<name>.age` locally.

#### agenix workflow

1. Add recipient public keys in `secrets/secrets.nix` if needed; run `agenix -r` after key changes.
2. Create or edit: `agenix -e secrets/<name>.age`
3. Declare `age.secrets.<name>` in the service module with `file = ../../secrets/<name>.age` (adjust path from module location).
4. Reference at runtime via `config.age.secrets.<name>.path` — never `builtins.readFile` at eval time.
5. Host decryption uses keys in `modules/core/agenix.nix` (`age.identityPaths`).

See [reference/secrets.md](skills/edit-nixos/reference/secrets.md) and `@edit-nixos` for the full secrets policy.

### Network exposure

| Rule | Example |
|------|---------|
| Bind local services to `127.0.0.1` | llama.cpp, SearXNG |
| `openFirewall = false` on every service unless public access is intended | Default for new services |
| Explicitly open ports in `networking.firewall` when exposing to LAN/WAN | Conscious admin decision |
| Review `hardware-configuration.nix` and user modules before public git push | Disk UUIDs, hostnames |

Service-specific remote access patterns (e.g. Tailscale) live in [reference/services.md](skills/edit-nixos/reference/services.md).

### Systemd hardening

For custom services, consider `DynamicUser`, `ProtectSystem`, `PrivateTmp`, and dedicated service users — unless the service needs broad filesystem access. GPU/model details for this machine are in [reference/machine.md](skills/edit-nixos/reference/machine.md) and [reference/services.md](skills/edit-nixos/reference/services.md).

---

## 9. Services

### New service checklist

- [ ] Dedicated `modules/services/<name>.nix`
- [ ] One import line in `hosts/nixos/configuration.nix`
- [ ] `enable` option if toggling on/off matters
- [ ] Persistent state directory if needed (`systemd.tmpfiles.rules`)
- [ ] `openFirewall = false` unless exposure is intended
- [ ] Localhost bind for internal-only APIs
- [ ] agenix secret if the service needs credentials
- [ ] README + `reference/services.md` updated
- [ ] `systemctl status <service>` documented

### Remove service checklist

- [ ] Remove import from `hosts/nixos/configuration.nix`
- [ ] Delete `modules/services/<name>.nix`
- [ ] **Ask user** whether to delete data under `/var/lib/<service>` — never delete without confirmation
- [ ] Remove agenix secret if no longer used
- [ ] Grep repo for stale references to the service
- [ ] Update README + `reference/services.md` + `reference/layout.md`

### Rebuild subcommands

| Command | Use |
|---------|-----|
| `switch` | Build, activate, set boot default |
| `test` | Activate without adding boot entry — good for risky changes |
| `boot` | Build and set boot default without activating now |
| `build` | Build only, no activation |
| `--rollback` | Emergency revert — **only when user asks** |

### Confirm with user before `switch`

**Always ask** before switching when the change touches:

- Services (new, changed, or removed)
- Hardware / NVIDIA
- Boot loader or kernel
- Users or permissions
- Networking or firewall
- Anything that can break login or GPU

**Proceed without extra confirmation** after a green build for small changes: Home Manager packages, desktop tweaks, docs-only edits.

### Safe sequence for this config

```sh
nix fmt .                    # not bare `nix fmt` — see lessons.md
nix flake check
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --no-link
# Run config audit — see section 12
pkexec nixos-rebuild switch --flake /etc/nixos#nixos
```

**Privileged commands:** User **rileyt** allows agents to use **`pkexec`** for any command that would otherwise require `sudo`. `modules/core/polkit-pkexec.nix` grants passwordless `pkexec` for user `rileyt`. Prefer `pkexec` in non-interactive agent sessions. Rollback and GC still require an explicit user request before agents run them.

### Commands requiring explicit user request

Never run these unless the user explicitly asks:

| Command | Why |
|---------|-----|
| `nixos-rebuild switch --rollback` | Destructive to current generation |
| `nix-collect-garbage -d` | Can remove rollback paths |
| `git push --force` to `main` | Rewrites shared history |
| `git commit --no-verify` | Skips hooks |
| `git push` to `main` | **Always ask first** (even without `--force`) |

---

## 10. Packages and overlays

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

## 11. Testing and CI

### Local validation (required before switch)

```sh
nix fmt .                    # pass `.` or changed paths; bare `nix fmt` hangs
nix flake check
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --no-link
```

Local validation is **stricter than CI** — it performs a full toplevel build, not just eval.

### CI (this repo)

`.github/workflows/check.yml` on push/PR:

| Step | Command | Purpose |
|------|---------|---------|
| Format | `nix fmt -- --check .` | Style consistency |
| Flake | `nix flake check --no-build` | Output validity |
| Eval | `nix eval .#nixosConfigurations.nixos.config.system.build.toplevel.drvPath` | System evaluates (lighter than full build) |

Keep CI green before pushing. A passing local build implies CI eval should pass; CI does not substitute for local build before switch.

### Optional (when complexity grows)

- `checks` output in flake for integration tests (`pkgs.nixosTest`)
- `nixos-rebuild build-vm` for manual smoke test in QEMU
- Pre-commit hooks for `nix fmt`

For build failures, see [troubleshooting.md](skills/edit-nixos/troubleshooting.md).

---

## 12. Documentation and audit

### Config audit (required before commit)

After every config change, run the checklist in [reference/audit.md](skills/edit-nixos/reference/audit.md):

- Import graph: no orphans, no stale imports, every service file imported
- Secrets: `age.secrets` ↔ `secrets/*.age` ↔ `secrets/secrets.nix` aligned
- Reference docs and README match live config
- Grep for removed service/package names
- Validation commands pass

Fix stale or mismatched entries before committing. Full workflow details in [@edit-nixos](skills/edit-nixos/SKILL.md).

### Update on every meaningful change

| File | When |
|------|------|
| `README.md` | Services, layout, usage, endpoints — always (except trivial syntax) |
| `.cursor/skills/edit-nixos/reference/` | Any config change affecting layout, services, flake, machine — see SKILL.md mapping table |
| `.cursor/skills/edit-nixos/lessons.md` | As soon as cause and fix for an error are known (flexible timing vs commit) |
| [troubleshooting.md](skills/edit-nixos/troubleshooting.md) | New recurring failure modes worth documenting |
| This file | When a new **general** best practice is learned |

---

## 13. Git workflow (this repo)

GitHub `main` is the **source of truth** for both desktop and laptop. Details: [preferences.md](skills/edit-nixos/reference/preferences.md).

| Action | Policy |
|--------|--------|
| Commit | **Automatic** after validated changes |
| Push to `main` | Ask first, unless Riley already directed push / GitHub sync / source-of-truth for this work |
| After push | Remind to `git pull` + rebuild on the other host when the change is fleet-relevant |
| Commit message | Imperative, 1–2 sentences, focus on why |
| `flake.lock` | Commit with intentional input updates |
| Secrets | Never commit plaintext (`.env`, `*.key`, `secrets/*.plain.*` — see `.gitignore`) |
| Force push | Never to `main` without explicit user request |

---

## 14. Anti-patterns

| Anti-pattern | Why it hurts |
|--------------|--------------|
| Monolithic `configuration.nix` | Unreviewable, merge conflicts, unclear ownership |
| Secrets in nix files | World-readable store |
| Pasting secrets in chat | Exposure outside agenix workflow |
| Changing `stateVersion` to "current release" | Data path migrations, breakage |
| Skipping `flake check` before switch | Broken system activation |
| Untracked new `.nix` files | Flake silently ignores them |
| `builtins.fetchTarball` without hash | Impure, unreproducible |
| Multiple unrelated services in one file | Violates this repo's modularity rule |
| Auto-opening firewall on service enable | Surprises, unintended exposure |
| Duplicating nixpkgs without `follows` | Slow evals, subtle version conflicts |
| Deleting `/var/lib/` data when removing a service | Data loss without user consent |
| `--option require-sigs false` / disabled sandbox | Security risk |

---

## 15. Alignment with this fleet

These practices are tuned for riley's setup:

- Hosts: `nixos` (desktop, GNOME) + `legion` (laptop, Cinnamon / PRIME offload); user `rileyt`
- Preferences & multi-host decisions: [preferences.md](skills/edit-nixos/reference/preferences.md)
- Machine facts: [reference/machine.md](skills/edit-nixos/reference/machine.md)
- Stable `nixos-26.05` + `pkgsUnstable` for CUDA llama.cpp
- Shared local AI / dashboard stack on every host — [reference/services.md](skills/edit-nixos/reference/services.md)
- Home Manager as NixOS module with `useGlobalPkgs` / `useUserPackages`; shared via `home/common.nix`
- agenix for all secrets (every host must decrypt); OpenSSH over Tailscale only

When a general best practice conflicts with [preferences.md](skills/edit-nixos/reference/preferences.md) or `@edit-nixos`, **preferences win**.

---

## 16. Agent rules from programming books

Vendored from [ciembor/agent-rules-books](https://github.com/ciembor/agent-rules-books) (MIT) under `.cursor/agent-rules-books/`.

| Mechanism | Location | When |
|-----------|----------|------|
| Index skill | [skills/agent-rules-books/SKILL.md](skills/agent-rules-books/SKILL.md) | Pick which book applies |
| Per-book skills | [skills/\<book\>/SKILL.md](skills/) | Refactoring, review, DDD, architecture, etc. |
| Source files | [agent-rules-books/](agent-rules-books/) | `mini` (active), `full` (reference), `nano` (compact) |
| Cursor rules | [rules/](rules/) | NixOS always-on; books on-demand |

**Precedence:** `@edit-nixos` and this file override book rules for NixOS flake work. Use **one primary** book skill per task; check [COMPATIBILITY.md](agent-rules-books/COMPATIBILITY.md) before combining overlapping sets (e.g. Clean Code vs Pragmatic Programmer).

---

## Sources

- [NixOS Wiki — Flakes](https://wiki.nixos.org/wiki/Flakes)
- [NixOS Wiki — NixOS system configuration](https://wiki.nixos.org/wiki/NixOS_system_configuration)
- [NixOS Wiki — NixOS modules](https://wiki.nixos.org/wiki/NixOS:Modules)
- [NixOS Wiki — FAQ: When do I update stateVersion](https://wiki.nixos.org/wiki/FAQ/When_do_I_update_stateVersion)
- [NixOS Wiki — Updating NixOS](https://wiki.nixos.org/wiki/Updating_NixOS)
- [NixOS Wiki — Firewall](https://wiki.nixos.org/wiki/Firewall)
- [NixOS Wiki — Module system vs Nix language](https://wiki.nixos.org/wiki/The_Nix_Language_versus_the_NixOS_Module_System)
- [NixOS Wiki — Troubleshooting](https://wiki.nixos.org/wiki/Troubleshooting)
- [Nix manual — nix flake](https://nix.dev/manual/nix/latest/command-ref/new-cli/nix3-flake.html)
- [Nix manual — Secrets in the store](https://github.com/NixOS/nix/blob/master/doc/manual/source/store/secrets.md)
- [Home Manager — NixOS module](https://home-manager.dev/manual/unstable/#ch-nixos-module)
- [sops-nix](https://github.com/Mic92/sops-nix)
- [Discourse — Config structure](https://discourse.nixos.org/t/how-do-you-structure-your-nixos-configs/65851)
- [Discourse — Secrets overview](https://discourse.nixos.org/t/handling-secrets-in-nixos-an-overview-git-crypt-agenix-sops-nix-and-when-to-use-them/35462)
- [import-tree / Dendritic pattern](https://github.com/denful/import-tree)
