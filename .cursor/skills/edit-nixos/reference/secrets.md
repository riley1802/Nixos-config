# Secrets (agenix)

All machine secrets are managed with [agenix](https://github.com/ryantm/agenix). Encrypted files live in `secrets/`; decrypted at activation under `/run/agenix/`.

| Secret | Encrypted file | Module |
|--------|----------------|--------|
| Tailscale auth key | `secrets/tailscale-auth-key.age` | `modules/services/tailscale.nix` |
| SearXNG secret key | `secrets/searxng-secret-key.age` | `modules/services/searxng.nix` |
| n8n DB password | `secrets/n8n-db-password.age` | `modules/services/n8n.nix` |
| Uptime Kuma sync env | `secrets/uptime-kuma-sync.env.age` | `modules/services/uptime-kuma.nix` |

`uptime-kuma-sync`'s `age.secrets` stanza sets `owner = "rileyt"` (not the default `root`) — it's read both by the root-run `uptime-kuma-sync.service` (root bypasses file permissions) and by the `rileyt` user-session `homeport-tray.service` (`home/programs/homeport-tray.nix`), which only needs `NTFY_TOPIC` from it.

## Core modules

| Path | Purpose |
|------|---------|
| `modules/core/openssh.nix` | Host SSH keys (agenix decryption) |
| `modules/core/agenix.nix` | `age.identityPaths` |

## Rules

- **Never** put secret values in `.nix` files or plaintext in git
- **Always** use `agenix -e` to create or edit secrets
- After adding public keys to `secrets/secrets.nix`, run `agenix -r`
- See [secrets/README.md](../../../secrets/README.md) for edit instructions
