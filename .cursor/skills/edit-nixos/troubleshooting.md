# NixOS troubleshooting and debugging

Quick reference for diagnosing build, eval, and rebuild failures on this config. For resolved errors with root cause, see [lessons.md](lessons.md).

Use when `nix flake check`, toplevel build, or `nixos-rebuild switch` fails — or when config behaves differently than expected after a change.

---

## First steps

1. Read the **full error output** — Nix often reports the real failure several lines above the final message.
2. Check [lessons.md](lessons.md) for a matching past fix.
3. Re-run with a trace:

```sh
nix flake check --show-trace
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --no-link --show-trace
```

4. Confirm new `.nix` files are **git-tracked** — flakes ignore untracked sources (see lessons.md).

---

## Common failure modes

### Untracked or new module not picked up

**Symptom:** Rebuild uses old config; new file missing from evaluation.

**Check:**

```sh
git status
git add path/to/new-module.nix
```

**Avoid:** Testing new modules while they remain untracked.

### Option or module not found

**Symptom:** `The option '…' does not exist` or `undefined variable`.

**Check:**

- Option name spelling and nesting (search nixpkgs source or wiki).
- Module is imported in `hosts/nixos/configuration.nix`.
- `specialArgs` in `flake.nix` includes what the module expects (`pkgsUnstable`, `inputs`).

**Inspect live options:**

```sh
nixos-option services.llama-cpp.enable
nix eval .#nixosConfigurations.nixos.options.services.llama-cpp.enable
```

### Secret / agenix errors

**Symptom:** Activation fails; `/run/agenix/` path missing; permission denied.

**Check:**

- `secrets/*.age` exists and is listed in `secrets/secrets.nix`.
- `age.secrets.<name>.file` path is correct from the module (e.g. `../../secrets/foo.age` from `modules/services/`).
- Host SSH key and user key in `modules/core/agenix.nix` `identityPaths`.
- Never use `builtins.readFile` on secret files at eval time.

**Edit secrets locally:**

```sh
agenix -e secrets/<name>.age
agenix -r   # after changing secrets/secrets.nix keys
```

### Flake input / lock mismatch

**Symptom:** Version conflicts, missing packages, HM/nixpkgs mismatch.

**Check:**

- `home-manager` and `agenix` use `inputs.nixpkgs.follows = "nixpkgs"`.
- `flake.lock` committed after intentional `nix flake update`.
- Module uses `pkgs` vs `pkgsUnstable` consistently with intent.

### Service fails at runtime (build succeeded)

**Check:**

```sh
systemctl status <service>
journalctl -u <service> -b --no-pager
```

**Common causes:**

- Wrong bind address or port conflict.
- Missing persistent directory or wrong ownership (`systemd.tmpfiles.rules`).
- GPU services running as wrong user (see `reference/services.md`).
- Secret not mounted at expected path.

---

## Useful commands

| Command | Purpose |
|---------|---------|
| `nix flake check --show-trace` | Validate flake outputs with stack trace |
| `nix build .#nixosConfigurations.nixos.config.system.build.toplevel --no-link` | Full local system build |
| `nix eval .#nixosConfigurations.nixos.config.system.build.toplevel.drvPath` | Lighter eval (what CI runs) |
| `nix fmt .` | Fix formatting before commit (pass `.` or paths — bare `nix fmt` hangs) |
| `nixos-rebuild build --flake /etc/nixos#nixos` | Build without activating |
| `nixos-rebuild test --flake /etc/nixos#nixos` | Activate without new boot entry |
| `pkexec nixos-rebuild switch --flake /etc/nixos#nixos` | Apply config (user allows `pkexec` for sudo-equivalent commands) |
| `nix log <drvpath>` | Show build log for a failed derivation |

### Impure eval (development only)

If deliberately testing **untracked** files before `git add`:

```sh
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --impure --no-link
```

Prefer `git add` + normal build for anything you intend to keep.

---

## Rollback (user request only)

Do **not** run rollback unless the user explicitly asks.

```sh
sudo nixos-rebuild switch --rollback
```

Previous generations remain in `/nix/var/nix/profiles/system-*` until garbage-collected.

---

## External references

- [NixOS Wiki — Troubleshooting](https://wiki.nixos.org/wiki/Troubleshooting)
- [Nix manual — error messages](https://nix.dev/manual/nix/latest/development/error-messages)
- [NixOS Wiki — FAQ](https://wiki.nixos.org/wiki/FAQ)
