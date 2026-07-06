# Secrets (agenix)

All machine secrets are managed with [agenix](https://github.com/ryantm/agenix). Encrypted files live in `secrets/`; decrypted at activation under `/run/agenix/`.

| Secret | Encrypted file | Module |
|--------|----------------|--------|
| Tailscale auth key | `secrets/tailscale-auth-key.age` | `modules/services/tailscale.nix` |
| SearXNG secret key | `secrets/searxng-secret-key.age` | `modules/services/searxng.nix` |

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
