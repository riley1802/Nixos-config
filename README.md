# NixOS Config

Personal NixOS flake for two hosts:

| Host | Platform | Role |
|------|----------|------|
| `nixos` | x86_64 | Desktop workstation (GNOME, NVIDIA, local AI) |
| `nixos-pi` | aarch64 (Raspberry Pi 4) | Homelab infocenter (XFCE, dashboards) |

System configuration lives under `hosts/` and `modules/`. User configuration
lives under `home/`.

## Layout

- `flake.nix` - flake inputs and `nixos` / `nixos-pi` outputs.
- `hosts/<hostname>/` - per-host `configuration.nix` and `hardware-configuration.nix`.
- `configuration.nix` - re-exports `hosts/nixos/` for compatibility.
- `home.nix` - Home Manager imports for the desktop.
- `home/home-pi.nix` - lightweight Home Manager imports for the Pi.
- `modules/core/` - boot, locale, networking, and system defaults.
- `modules/desktop/` - GNOME (desktop) and XFCE (Pi).
- `modules/hardware/` - NVIDIA (desktop) and Raspberry Pi 4.
- `modules/programs/` - system-level applications and program settings.
- `modules/services/` - system services.
- `modules/users/` - local user accounts.
- `secrets/` - agenix-encrypted secrets (`*.age`) and `secrets.nix` public keys.
- `home/` - Home Manager modules for user packages and desktop preferences.

## Raspberry Pi 4 (`nixos-pi`)

Homelab infocenter node: XFCE desktop, Homepage dashboard, Uptime Kuma, and
Tailscale. Heavy desktop services (llama.cpp, SearXNG, NVIDIA, gaming) stay on
`nixos` only.

| Service | URL | Module |
|---------|-----|--------|
| Homepage | http://127.0.0.1:8082 | `modules/services/homepage.nix` |
| Uptime Kuma | http://127.0.0.1:3001 | `modules/services/uptime-kuma.nix` |
| Tailscale | tailnet (MagicDNS) | `modules/services/tailscale.nix` |

### First-time install (from the desktop)

1. **Enable aarch64 builds on the desktop** (one-time rebuild):

   ```sh
   sudo nixos-rebuild switch --flake .#nixos
   ```

   This applies `modules/core/binfmt.nix` so the desktop can build Pi images.

2. **Build the SD card image** (30–60+ minutes the first time):

   ```sh
   cd /etc/nixos
   nix build .#nixos-pi-sd-image
   ```

3. **Flash the image** (replace `/dev/sdX` with your SD card device):

   ```sh
   sudo dd if=result/sd-image/*.img of=/dev/sdX bs=4M status=progress conv=fsync
   ```

4. **Boot the Pi** with ethernet connected. Find its IP on your router, then SSH:

   ```sh
   ssh rileyt@<pi-ip>
   ```

5. **Add the Pi host key to agenix** (on the desktop):

   ```sh
   ssh rileyt@<pi-ip> 'sudo cat /etc/ssh/ssh_host_ed25519_key.pub'
   ```

   Add that key as `nixos-pi-host` in `secrets/secrets.nix`, uncomment it in
   `tailscale-auth-key.age` public keys, then rekey:

   ```sh
   cd /etc/nixos/secrets
   agenix -r
   ```

6. **Deploy config to the Pi** (from the desktop):

   ```sh
   nixos-rebuild switch --flake .#nixos-pi --target-host rileyt@<pi-ip> --use-remote-sudo
   ```

   Or on the Pi directly after cloning this repo to `/etc/nixos`:

   ```sh
   sudo nixos-rebuild switch --flake .#nixos-pi
   ```

7. **Set up Uptime Kuma** at http://127.0.0.1:3001 (create admin account, add
   monitors, create a status page). Wire the status page into Homepage widgets
   in `modules/services/homepage.nix` when ready.

### Ongoing Pi updates

```sh
# From the Pi
sudo nixos-rebuild switch --flake .#nixos-pi

# Or remotely from the desktop
nixos-rebuild switch --flake .#nixos-pi --target-host rileyt@nixos-pi --use-remote-sudo
```

## Local AI Stack (desktop only)

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
- Connect remotely: `ssh rileyt@nixos` from another tailnet device.
- **After revoking a key in Tailscale admin**, create a new key and run `agenix -e secrets/tailscale-auth-key.age` before rebuilding.

## Firewall policy

Services do not open the public firewall unless explicitly intended:

| Service | Firewall |
|---------|----------|
| SSH | `tailscale0` only (port 22) |
| llama.cpp, SearXNG | localhost only (desktop) |
| Homepage, Uptime Kuma | localhost only (Pi) |
| Tailscale | closed (`openFirewall = false`) |
| Steam Remote Play | closed (`remotePlay.openFirewall = false`) |

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

Create or rotate a Tailscale key at [Tailscale admin → Keys](https://login.tailscale.com/admin/settings/keys), then `agenix -e secrets/tailscale-auth-key.age`. Do not paste keys in chat.

## Usage

Apply the desktop configuration:

```sh
sudo nixos-rebuild switch --flake .#nixos
```

Build the desktop system without switching:

```sh
nix build .#nixosConfigurations.nixos.config.system.build.toplevel
```

Build the Pi SD image (after binfmt is enabled on the desktop):

```sh
nix build .#nixos-pi-sd-image
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
