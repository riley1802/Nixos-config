---
name: edit-nixos
description: >-
  Change riley's NixOS flake config at /etc/nixos with clarifying questions,
  modular modules, validation, safe rebuild, auto-commit, README updates,
  reference/ sync, lessons.md error logging, and bestpracticesnixos.md.
  Use when the user invokes @edit-nixos, asks to change NixOS/Home Manager config, or mentions
  nixos-rebuild, flake, modules, or /etc/nixos.
---

# Edit NixOS Config

Personal flake for host `nixos`, user `rileyt`, repo at `/etc/nixos`.

**Before any similar change:** read [lessons.md](lessons.md), [bestpracticesnixos.md](../../bestpracticesnixos.md), [troubleshooting.md](troubleshooting.md), and relevant files in [reference/](reference/README.md).

## Before editing anything

**Always ask clarifying questions first.** Do not guess intent. Do not edit files until answers are clear.

Use this checklist every time:

1. **What** — exact outcome (package, service, setting, removal, etc.)
2. **Scope** — system (`modules/`) vs user (`home/`). Default to what makes most sense; **ask if unsure**.
3. **Persistence** — state dirs, secrets, firewall, localhost-only vs exposed
4. **Packages** — stable `pkgs` vs `pkgsUnstable` (prefer unstable when stable is too old)
5. **Removal** — what to delete vs leave on disk
6. **Apply** — rebuild now or config-only
7. **Git** — auto-commit when done; **always ask before push to `main`**

Copy and track:

```
Discovery:
- [ ] What exactly should change?
- [ ] System or Home Manager (or both)?
- [ ] New module file or extend existing?
- [ ] pkgs vs pkgsUnstable?
- [ ] README impact?
- [ ] reference/ updated?
- [ ] secrets/ + agenix updated?
- [ ] config audit pass?
- [ ] Push after commit?
```

## Repo layout (strict)

| Change type | Location | Import via |
|-------------|----------|------------|
| Boot, locale, network, system | `modules/core/` | `hosts/nixos/configuration.nix` |
| GNOME, audio (system) | `modules/desktop/` | `hosts/nixos/configuration.nix` |
| NVIDIA, hardware | `modules/hardware/` | `hosts/nixos/configuration.nix` |
| System packages/programs | `modules/programs/` | `hosts/nixos/configuration.nix` |
| **Each service gets its own file** | `modules/services/<name>.nix` | `hosts/nixos/configuration.nix` |
| Users | `modules/users/` | `hosts/nixos/configuration.nix` |
| Secrets (agenix) | `secrets/*.age`, `secrets/secrets.nix` | per-service `age.secrets` |
| User desktop/programs | `home/desktop/`, `home/programs/` | `home.nix` |

Rules:

- **One service = one `.nix` file.** Never cram unrelated services together.
- `configuration.nix` (root), `hosts/nixos/configuration.nix`, and `home.nix` are **import lists only** — no logic.
- Match naming and style of neighboring modules. Minimal diff.
- Do not edit `hosts/nixos/hardware-configuration.nix` unless the user explicitly asks.
- **All secrets use agenix** — never plaintext in `.nix`, README, or git. See [Secrets policy](#secrets-policy-agenix-mandatory).

Details: [reference/](reference/README.md)

## Secrets policy (agenix mandatory)

**Every secret** on this system must go through agenix. No exceptions.

| Do | Don't |
|----|-------|
| `agenix -e secrets/foo.age` for create/edit | Plaintext in `.nix` or `.env` |
| `age.secrets.<name>.file` in service module | `systemd` scripts that `openssl rand` secrets |
| `config.age.secrets.<name>.path` at runtime | `builtins.readFile` on secret files at eval time |
| Encrypted `*.age` committed to git | Plaintext keys in chat, `.nix`, or README |

**Never ask the user to paste secrets in chat.** Direct them to `agenix -e` locally.

Workflow for a new secret:

1. Add public keys in `secrets/secrets.nix` if needed
2. `agenix -e secrets/<name>.age`
3. Declare `age.secrets.<name>` in the service module
4. Update `reference/secrets.md`, `secrets/README.md`, README if user-facing

See [reference/secrets.md](reference/secrets.md) and [secrets/README.md](../../../secrets/README.md).

## Implementation rules

1. Read the target module, a similar existing module, [lessons.md](lessons.md), and [bestpracticesnixos.md](../../bestpracticesnixos.md) before writing.
2. New service → create `modules/services/<name>.nix`, add one import line to `hosts/nixos/configuration.nix`.
3. Newer packages than stable → `{ pkgsUnstable, ... }` from `specialArgs` (see `flake.nix`).
4. Custom derivations → only if nixpkgs and `pkgsUnstable` cannot provide it; prefer upstream packages.
5. Home Manager managed files that may exist on disk → use `force = true` when replacing user state.
6. **Update `README.md` always** — no exceptions except trivial syntax-only edits.
7. **Update `reference/` always** when config changes — see below.

## Keep reference/ in sync (required)

On **every** config change, update the matching file(s) in `.cursor/skills/edit-nixos/reference/`:

| Config change | Update |
|---------------|--------|
| New/removed import in `hosts/nixos/configuration.nix` | [reference/layout.md](reference/layout.md) |
| New/removed/changed service | [reference/services.md](reference/services.md) |
| New/removed/changed agenix secret | [reference/secrets.md](reference/secrets.md) |
| New/removed HM module or user package | [reference/home-manager.md](reference/home-manager.md) |
| Flake inputs, outputs, overlays, specialArgs | [reference/flake.md](reference/flake.md) |
| Hardware, hostname, user, GPU | [reference/machine.md](reference/machine.md) |
| New reusable pattern worth documenting | [reference/patterns.md](reference/patterns.md) |

Reference must reflect **current** state after the change, not a changelog.

## Config audit (required before handoff)

After every change, run the full checklist in [reference/audit.md](reference/audit.md):

- Import graph: `hosts/nixos/configuration.nix` / `home.nix` vs files on disk — no orphans, no stale imports
- Secrets: `age.secrets` ↔ `secrets/*.age` ↔ `secrets/secrets.nix` all aligned
- Reference docs and README match live config
- Grep for removed service/package names still mentioned elsewhere
- `nix flake check` and toplevel build pass

Fix stale or mismatched entries before committing.

## Log errors in lessons.md (required)

**Whenever a build, rebuild, or runtime error occurs and is resolved**, append an entry to [lessons.md](lessons.md) using the format at the top of that file:

- Context — what we were doing
- Error — exact message or symptom
- Cause — why it happened
- Fix — what worked
- Avoid — rule so it is not repeated

Do this in the **same session** as the fix, before committing. If the error matches an existing lesson, update that entry instead of duplicating.

## Validation (required before rebuild)

Run in `/etc/nixos`:

```sh
nix flake check
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --no-link
```

Fix failures before switch (and log new lessons). Optionally run `nix fmt .` (never bare `nix fmt` — hangs; see lessons.md).

Follow [bestpracticesnixos.md](../../bestpracticesnixos.md) for flake, module, security, and validation rules.

## Rebuild (safe sequence)

1. `nix flake check`
2. `nix build .#nixosConfigurations.nixos.config.system.build.toplevel --no-link`
3. Confirm with user **only for big changes**:
   - services (new/changed/removed)
   - hardware / NVIDIA
   - boot
   - users
   - networking
   - anything that can break login or GPU
4. Small changes (home packages, desktop tweaks, docs-only) → proceed without extra confirmation if build passed.
5. Apply (use **`pkexec`**, not `sudo` — user approved for all privileged agent commands):

```sh
pkexec nixos-rebuild switch --flake /etc/nixos#nixos
```

If `pkexec` fails (policy kit denied, etc.), show the exact command for the user to run.

**Never** without explicit user request:

- `nixos-rebuild switch --rollback`
- `nix-collect-garbage -d`
- `git push --force` to `main`
- skip hooks (`--no-verify`)

## Git workflow

After changes validate:

1. `git status`, `git diff`, `git log -5 --oneline`
2. **Commit automatically** — include config, README, reference/, and lessons.md when touched:

```sh
git add <relevant files>
git commit -m "$(cat <<'EOF'
Short summary of why.

Optional second sentence with context.
EOF
)"
```

3. **Always ask before `git push` to `main`.** Never push unless the user confirms.
4. Never update git config. Never amend unless user rules allow it.

## Handoff to user

After work, report:

- Files changed and why
- Reference / lessons updates made
- Config audit results (stale items found and fixed)
- Whether rebuild ran or command to run
- Commit hash (if committed)
- Whether push is pending (ask if they want it)

## Examples

**User:** "Add htop"

Ask: system-wide or user-only? → likely `modules/programs/packages.nix`. Edit, README, update `reference/layout.md` or `home-manager.md`, validate, commit, ask about push.

**User:** "Remove a service"

Ask: delete module file + import? data on disk? → remove import, delete module, README, update `reference/layout.md` + `services.md`, validate, confirm rebuild, commit, ask push.

**User:** "Update llama.cpp model"

Ask: which preset alias, HF repo/file, GPU flags? → edit `modules/services/llama-cpp.nix`, README model table, update `reference/services.md`, validate, confirm rebuild, commit, ask push.

**Build fails, then fixed**

Fix the error → append entry to `lessons.md` → retry validation → commit with config + lesson together.
