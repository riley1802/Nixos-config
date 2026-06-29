# Secrets (agenix)

All secrets for this config are encrypted with [agenix](https://github.com/ryantm/agenix) and stored as `*.age` files in this directory.

| Secret | File | Used by |
|--------|------|---------|
| Tailscale auth key | `tailscale-auth-key.age` | `modules/services/tailscale.nix` |
| SearXNG secret key | `searxng-secret-key.age` | `modules/services/searxng.nix` |

Public keys allowed to decrypt are listed in `secrets.nix`. **Never commit plaintext secrets.**

## Edit a secret

From `/etc/nixos`:

```sh
nix shell github:ryantm/agenix
cd secrets
agenix -e tailscale-auth-key.age   # opens $EDITOR
agenix -e searxng-secret-key.age   # file content: SEARXNG_SECRET_KEY=<hex>
```

After changing `secrets.nix` public keys, rekey everything:

```sh
cd secrets && agenix -r
```

## One-time: add host SSH key

After the first rebuild with `openssh` enabled:

```sh
# Add host pubkey to secrets.nix publicKeys, then:
cd /etc/nixos/secrets && agenix -r
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

Host key path: `/etc/ssh/ssh_host_ed25519_key.pub`

## Tailscale auth key

1. Create a reusable auth key at [Tailscale admin → Keys](https://login.tailscale.com/admin/settings/keys)
2. `agenix -e tailscale-auth-key.age` — paste the key only (no quotes, no newline)
3. Rebuild

Until the placeholder is replaced, Tailscale will not authenticate.

## Add a new secret

1. Add entry to `secrets.nix`
2. `agenix -e new-secret.age`
3. Declare `age.secrets.<name>` in the relevant module
4. Reference `config.age.secrets.<name>.path` — never inline secret values
