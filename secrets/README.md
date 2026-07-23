# Secrets (agenix)

All secrets for this config are encrypted with [agenix](https://github.com/ryantm/agenix) and stored as `*.age` files in this directory.

| Secret | File | Used by |
|--------|------|---------|
| Tailscale auth key | `tailscale-auth-key.age` | `modules/services/tailscale.nix` |
| SearXNG secret key | `searxng-secret-key.age` | `modules/services/searxng.nix` |
| n8n DB password | `n8n-db-password.age` | `modules/services/n8n.nix` |
| Uptime Kuma sync env | `uptime-kuma-sync.env.age` | `modules/services/uptime-kuma.nix` |
| Unsloth Studio env | `unsloth-studio.env.age` | `modules/services/unsloth-studio.nix` |

Public keys allowed to decrypt are listed in `secrets.nix`. **Never commit plaintext secrets.**

## Edit a secret

From `/etc/nixos`:

```sh
nix shell github:ryantm/agenix
cd secrets
agenix -e tailscale-auth-key.age   # paste key only — no quotes, no trailing newline
agenix -e searxng-secret-key.age   # file content: SEARXNG_SECRET_KEY=<hex>
agenix -e uptime-kuma-sync.env.age # KUMA_USERNAME=… / KUMA_PASSWORD=… / NTFY_TOPIC=…
agenix -e unsloth-studio.env.age   # JUPYTER_PASSWORD=… / USER_PASSWORD=…
```

After changing `secrets.nix` public keys, rekey everything:

```sh
cd secrets && agenix -r
```

Then rebuild:

```sh
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

## Uptime Kuma sync env

After creating the admin account in the Kuma UI (`http://nixos.taile9f484.ts.net:3001`):

```sh
agenix -e uptime-kuma-sync.env.age
```

File contents (one key per line):

```
KUMA_USERNAME=admin
KUMA_PASSWORD=…
NTFY_TOPIC=homeport-uptime
```

Then rebuild so `/run/agenix` picks up the new ciphertext (restarting the unit alone is not enough):

```sh
pkexec nixos-rebuild switch --flake /etc/nixos#nixos
# or after a switch that already includes the unit:
systemctl restart uptime-kuma-sync.service
```

This file's `owner` is `rileyt` (not the default `root`) because the `homeport-tray`
user service (`home/programs/homeport-tray.nix`) also reads `NTFY_TOPIC` from it to
subscribe to ntfy for native tray notifications. The root-run `uptime-kuma-sync.service`
still reads it fine — root bypasses file permissions.

## Tailscale auth key

1. Create a **reusable** auth key at [Tailscale admin → Keys](https://login.tailscale.com/admin/settings/keys)
2. `agenix -e tailscale-auth-key.age` — paste the key only
3. Rebuild

If a key is **revoked or rotated** in the Tailscale admin, create a new key and repeat step 2 before the next rebuild. A revoked key causes `tailscaled-autoconnect.service` to fail and can fail `nixos-rebuild switch`.

**Never paste auth keys in chat** — use `agenix -e` only.

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
