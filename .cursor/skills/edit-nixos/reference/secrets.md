# Secrets (agenix)

All machine secrets are managed with [agenix](https://github.com/ryantm/agenix). Encrypted files live in `secrets/`; decrypted at activation under `/run/agenix/`.

| Secret | Encrypted file | Module |
|--------|----------------|--------|
| Tailscale auth key | `secrets/tailscale-auth-key.age` | `modules/services/tailscale.nix` |
| SearXNG secret key | `secrets/searxng-secret-key.age` | `modules/services/searxng.nix` |
| n8n DB password | `secrets/n8n-db-password.age` | `modules/services/n8n.nix` |
| Uptime Kuma sync env | `secrets/uptime-kuma-sync.env.age` | `modules/services/uptime-kuma.nix` |

## Core modules

| Path | Purpose |
|------|---------|
| `modules/core/openssh.nix` | Host SSH keys (agenix decryption) |
| `modules/core/agenix.nix` | `age.identityPaths` |

## Rules

- **Never** put secret values in `.nix` files or plaintext in git
- **Always** use `agenix -e` to create or edit secrets
- After adding public keys to `secrets/secrets.nix`, run `agenix -r`
- `agenix -r` must run on a machine holding an identity that can already
  decrypt (rileyt's user key or an existing host key) — a brand-new host
  cannot rekey for itself; rekey on the desktop and push
- Recipients per host: `rileyt` (user), `nixos-host`, `legion-host` — see `secrets/secrets.nix`
- See [secrets/README.md](../../../secrets/README.md) for edit instructions
