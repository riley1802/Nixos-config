# Secrets (agenix)

All secrets for this config are encrypted with [agenix](https://github.com/ryantm/agenix) and stored as `*.age` files in this directory.

| Secret | File | Used by |
|--------|------|---------|
| Tailscale auth key | `tailscale-auth-key.age` | `modules/services/tailscale.nix` |
| SearXNG secret key | `searxng-secret-key.age` | `modules/services/searxng.nix` |
| Hermes email / optional env | `hermes-env.age` | `modules/services/hermes-agent/secrets.nix` |

Public keys allowed to decrypt are listed in `secrets.nix`. **Never commit plaintext secrets.**

Template for Hermes email: `secrets/hermes-env.example`

## Edit a secret

From `/etc/nixos`:

```sh
nix shell github:ryantm/agenix
cd secrets
agenix -e tailscale-auth-key.age   # paste key only — no quotes, no trailing newline
agenix -e searxng-secret-key.age   # file content: SEARXNG_SECRET_KEY=<hex>
```

After changing `secrets.nix` public keys, rekey everything:

```sh
cd secrets && agenix -r
```

Then rebuild:

```sh
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

## Tailscale auth key

1. Create a **reusable** auth key at [Tailscale admin → Keys](https://login.tailscale.com/admin/settings/keys)
2. `agenix -e tailscale-auth-key.age` — paste the key only
3. Rebuild

If a key is **revoked or rotated** in the Tailscale admin, create a new key and repeat step 2 before the next rebuild. A revoked key causes `tailscaled-autoconnect.service` to fail and can fail `nixos-rebuild switch`.

**Never paste auth keys in chat** — use `agenix -e` only.

## Hermes Discord + email (`hermes-env.age`)

Required for Discord messaging. Optional for email.

1. Copy fields from `hermes-env.example`
2. `agenix -e hermes-env.age` — paste `DISCORD_BOT_TOKEN` and `DISCORD_ALLOWED_USERS` (no quotes)
3. Rebuild — `secrets.nix` is imported automatically when the file exists

Discord bot setup: [Hermes Discord docs](https://hermes-agent.nousresearch.com/docs/user-guide/messaging/discord).

## Host SSH key (done on this machine)

Host pubkey is in `secrets.nix`. The machine decrypts secrets at activation via `/etc/ssh/ssh_host_ed25519_key`.

To add a new host after reinstall:

```sh
# Add host pubkey from /etc/ssh/ssh_host_ed25519_key.pub to secrets.nix, then:
cd /etc/nixos/secrets && agenix -r
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

## Add a new secret

1. Add entry to `secrets.nix`
2. `agenix -e new-secret.age`
3. Declare `age.secrets.<name>` in the relevant module
4. Reference `config.age.secrets.<name>.path` — never inline secret values
