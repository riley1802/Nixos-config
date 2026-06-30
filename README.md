# NixOS Config

Personal NixOS configuration for the `nixos` host and `rileyt` user.

This repository uses Nix flakes and Home Manager as a NixOS module. System
configuration lives under `modules/`, while user configuration lives under
`home/`.

## Layout

- `flake.nix` - flake inputs and the `nixos` system output.
- `configuration.nix` - top-level NixOS module imports.
- `hardware-configuration.nix` - generated hardware and filesystem settings for this machine.
- `home.nix` - top-level Home Manager imports.
- `modules/core/` - boot, locale, networking, and system defaults.
- `modules/desktop/` - GNOME and audio configuration.
- `modules/hardware/` - hardware-specific modules.
- `modules/programs/` - system-level applications and program settings.
- `modules/services/` - system services.
- `modules/users/` - local user accounts.
- `secrets/` - agenix-encrypted secrets (`*.age`) and `secrets.nix` public keys.
- `home/` - Home Manager modules for user packages and desktop preferences.

## Local AI Stack

This system runs llama.cpp for local inference and SearXNG for search, both
bound to localhost.

| Service | URL | Module |
|---------|-----|--------|
| llama.cpp API | http://127.0.0.1:8080/v1 | `modules/services/llama-cpp.nix` |
| SearXNG | http://127.0.0.1:8888 | `modules/services/searxng.nix` |
| Tailscale | tailnet (MagicDNS) | `modules/services/tailscale.nix` |

### llama.cpp

- CUDA build from `nixpkgs-unstable` (llama.cpp 9747+), required for Gemma 4
  Multi-Token Prediction (MTP).
- Dual-GPU layer split across RTX 3050 and GTX 1660 Super.
- Models are stored in `/var/lib/llama-cpp/models` and survive NixOS upgrades.
- Models download automatically from Hugging Face on first use.

Configured model presets:

| Alias | Model | Notes |
|-------|-------|-------|
| `gemma-4-e4b-q8` | Gemma 4 E4B Q8_0 | Fast, smaller model |
| `nemotron-nano-12b-v2-q4` | Nemotron Nano 12B v2 Q4_K_M | NVIDIA reasoning model |
| `gemma-4-12b-q4-mtp` | Gemma 4 12B Q4_K_M + MTP drafter | ~27% faster than baseline on this hardware |

Switch the active model by restarting the service with a different preset alias
in `modules/services/llama-cpp.nix`.

### SearXNG

- Local meta-search engine with JSON output.
- Secret key managed by agenix (`secrets/searxng-secret-key.age`).

### Tailscale

- Mesh VPN via `services.tailscale`.
- Auth key managed by agenix (`secrets/tailscale-auth-key.age`).
- SSH (`port 22`) allowed on `tailscale0` only — not open on LAN/WAN.
- Connect remotely: `ssh rileyt@nixos` or `ssh rileyt@100.121.132.40` from another tailnet device.

## Secrets (agenix)

All secrets use [agenix](https://github.com/ryantm/agenix). Encrypted files in `secrets/` are safe to commit; decrypted copies live in `/run/agenix/` at activation only.

| Secret | File |
|--------|------|
| Tailscale auth key | `secrets/tailscale-auth-key.age` |
| SearXNG secret key | `secrets/searxng-secret-key.age` |

Edit secrets:

```sh
nix shell github:ryantm/agenix
cd /etc/nixos/secrets
agenix -e tailscale-auth-key.age
```

Full instructions: [secrets/README.md](secrets/README.md)

**Before Tailscale works:** create a reusable auth key at [Tailscale admin → Keys](https://login.tailscale.com/admin/settings/keys), then `agenix -e tailscale-auth-key.age` and paste the key.

After first rebuild with OpenSSH, add the host public key to `secrets/secrets.nix` and run `agenix -r` so the machine can decrypt secrets without your user key. (Done on this machine.)

## Usage

Apply the system configuration from this repository:

```sh
sudo nixos-rebuild switch --flake .#nixos
```

Build the system without switching:

```sh
nix build .#nixosConfigurations.nixos.config.system.build.toplevel
```

Update locked inputs:

```sh
nix flake update
sudo nixos-rebuild switch --flake .#nixos
```

Format Nix files:

```sh
nix fmt
```

Check service status after applying:

```sh
systemctl status llama-cpp searx tailscaled
curl http://127.0.0.1:8080/v1/models
curl http://127.0.0.1:8888
tailscale status
```

## Git and GitHub

This repo uses the GitHub CLI (`gh`) as a credential helper so `git push` and
`git pull` work without entering a username or password each time.

Remote:

```sh
https://github.com/riley1802/Nixos-config.git
```

One-time setup on a new machine:

```sh
nix shell nixpkgs#gh
gh auth login
gh auth setup-git
```

Verify:

```sh
git pull
git push
```

The `gh` token is stored in the system keyring and refreshed automatically.

### SSH (optional)

SSH is also configured at `~/.ssh/id_ed25519`. To use it instead of HTTPS:

```sh
git remote set-url origin git@github.com:riley1802/Nixos-config.git
gh auth refresh -h github.com -s admin:public_key
gh ssh-key add ~/.ssh/id_ed25519.pub --title "nixos-$(hostname)"
ssh -T git@github.com
```

## Publishing Notes

Before pushing this repository publicly, review machine-specific files:

- `hardware-configuration.nix` includes disk UUIDs and hardware details.
- `modules/core/networking.nix` includes the hostname.
- `modules/users/rileyt.nix` includes the local username and groups.
- Do not commit private keys, access tokens, age identities, or plaintext credentials.
- Encrypted `secrets/*.age` files **are** intended for git (agenix).

Commit secrets only via agenix-encrypted `.age` files. Keep decryption keys (SSH host key, user key) off GitHub.
