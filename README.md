# NixOS Config

Personal NixOS flake for host `nixos` — x86_64 desktop workstation (GNOME, NVIDIA, local AI).

System configuration lives under `hosts/` and `modules/`. User configuration
lives under `home/`.

## Layout

- `flake.nix` - flake inputs and `nixos` output.
- `hosts/nixos/` - `configuration.nix` and `hardware-configuration.nix`.
- `configuration.nix` - re-exports `hosts/nixos/` for compatibility.
- `home.nix` - Home Manager imports for the desktop.
- `modules/core/` - boot, locale, hostname, NetworkManager, Nix settings, agenix, OpenSSH.
- `modules/desktop/` - GDM, GNOME, extensions, audio.
- `modules/hardware/` - graphics userspace and NVIDIA driver.
- `modules/programs/` - one file per program or concern (Firefox, Steam, CLI tools).
- `modules/services/` - system services.
- `modules/users/` - local user accounts.
- `secrets/` - agenix-encrypted secrets (`*.age`) and `secrets.nix` public keys.
- `home/` - Home Manager modules: one file per program, dconf domain, or core setting.
- `.cursor/` - Cursor agent skills and rules (NixOS workflow + [agent-rules-books](https://github.com/ciembor/agent-rules-books)).

User CLI tools include Cursor (`home/programs/cursor.nix`) and Claude Code
(`home/programs/claude-code.nix`, `pkgsUnstable.claude-code`). After login, run
`claude` and complete Anthropic auth when prompted.

## Cursor agent setup

| Path | Purpose |
|------|---------|
| `.cursor/bestpracticesnixos.md` | NixOS config philosophy and rules |
| `.cursor/skills/edit-nixos/` | Agent workflow for flake changes (`@edit-nixos`) |
| `.cursor/skills/agent-rules-books/` | Index of book-based coding rules |
| `.cursor/skills/<book>/` | Per-book skills (Clean Code, Refactoring, DDD, …) |
| `.cursor/rules/` | Always-on NixOS rules + scoped `.nix` conventions |

Invoke `@edit-nixos` for config changes. For code quality work, invoke a book skill (e.g. `@refactoring`, `@clean-code`) or see `.cursor/skills/agent-rules-books/SKILL.md`.

## Local AI Stack

This system runs local AI/search services bound to localhost.

| Service | URL | Module |
|---------|-----|--------|
| Homepage (via Tailscale Serve) | https://nixos.taile9f484.ts.net/ | `modules/services/homepage-dashboard.nix` + `tailscale-serve.nix` |
| n8n (via Tailscale Serve) | https://nixos.taile9f484.ts.net:5678 | `modules/services/n8n.nix` + `tailscale-serve.nix` |
| Portainer (via Tailscale Serve) | https://nixos.taile9f484.ts.net:9443 | `modules/services/docker.nix` + `tailscale-serve.nix` |
| ntfy | http://nixos.taile9f484.ts.net:8090 | `modules/services/ntfy-sh.nix` |
| Uptime Kuma | http://nixos.taile9f484.ts.net:3001 | `modules/services/uptime-kuma.nix` |
| llama.cpp (via Tailscale Serve) | https://nixos.taile9f484.ts.net:8080 (local `http://127.0.0.1:8080/v1`) | `modules/services/llama-cpp.nix` + `tailscale-serve.nix` |
| whisper.cpp (via Tailscale Serve) | https://nixos.taile9f484.ts.net:8081 (local `http://127.0.0.1:8081`) | `modules/services/whisper-cpp.nix` + `tailscale-serve.nix` |
| Piper TTS (via Tailscale Serve) | https://nixos.taile9f484.ts.net:8082 (local `http://127.0.0.1:8082`) | `modules/services/piper.nix` + `tailscale-serve.nix` |
| SearXNG | http://127.0.0.1:8888 | `modules/services/searxng.nix` |
| Tailscale | tailnet (MagicDNS) | `modules/services/tailscale.nix` |

### llama.cpp

- CUDA build from `nixpkgs-unstable` (llama.cpp 9747+), required for Gemma 4
  Multi-Token Prediction (MTP).
- Dual-GPU layer split across RTX 3050 and GTX 1660 Super.
- Context window: 16k tokens (`--ctx-size 16384`) with `q8_0` KV cache.
- Models are stored in `/var/lib/llama-cpp/models` and survive NixOS upgrades.
- Models download automatically from Hugging Face on first use.
- Router mode with `--models-max 1`: only one model fits in VRAM, so the
  loaded model is evicted before another preset is loaded (avoids CUDA OOM
  when switching models in the web UI).

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

### whisper.cpp

- Local speech-to-text HTTP service.
- Runs as `rileyt` and binds to `127.0.0.1:8081`.
- Models persist under `/var/lib/whisper-cpp/models`.

### Piper TTS

- Local text-to-speech HTTP wrapper around `piper`.
- Runs as `rileyt` and binds to `127.0.0.1:8082`.
- Voices persist under `/var/lib/piper/voices`; the default voice
  (`en_US-lessac-medium`) downloads automatically on service start.

### Tailscale

- Mesh VPN via `services.tailscale`.
- Auth key managed by agenix (`secrets/tailscale-auth-key.age`).
- SSH (`port 22`) allowed on `tailscale0` only — not open on LAN/WAN.
- Connect remotely: `ssh rileyt@nixos` from another tailnet device.
- **After revoking a key in Tailscale admin**, create a new key and run `agenix -e secrets/tailscale-auth-key.age` before rebuilding.

### Tailscale Serve + apps

- HTTPS via Tailscale Serve (`modules/services/tailscale-serve.nix`): Homepage `:443` → `:8083`, n8n `:5678` → localhost, Portainer `:9443` → localhost HTTPS, llama.cpp `:8080`, whisper.cpp `:8081`, Piper `:8082` → localhost.
- Homepage ("Homeport"): cool slate geometric theme, dark default with soft cool light mode. Its balanced single-row top bar is optimized for fullscreen 2560×1440 and contains resources, time/weather, host, primary-Ethernet throughput, and dual GPUs. Apps + Bookmarks sit beside Automation/Monitoring, then AI / Local beside Containers. `siteMonitor` latency appears on service tiles.
- Uptime Kuma (`3001`) and ntfy (`8090`) stay direct HTTP on `tailscale0` (ntfy rejects a path in `base-url`).
- Uptime Kuma monitors are declared in `modules/services/uptime-kuma.nix` and synced on boot via `uptime-kuma-sync.service` (Socket.IO API). Alerts go to ntfy. Credentials: `secrets/uptime-kuma-sync.env.age` (`KUMA_USERNAME`, `KUMA_PASSWORD`, `NTFY_TOPIC`) — create/edit with `agenix -e` after the Kuma admin account exists in the UI.
- n8n listens on `127.0.0.1` only; Serve terminates TLS. Do not use `N8N_PATH` (broken in 2.x).
- PostgreSQL 16 backs n8n; DB password via agenix (`secrets/n8n-db-password.age`).
- Docker + nvidia-container-toolkit; Portainer image pinned to `portainer/portainer-ce:2.39.4`.
- `rileyt` is in the `docker` group.
- **Serve must be enabled** in the Tailscale admin console for this node.

## Firewall policy

Services do not open the public firewall unless explicitly intended:

| Service | Firewall |
|---------|----------|
| SSH | `tailscale0` only (port 22) |
| Uptime Kuma | `tailscale0` only (port 3001) |
| ntfy | `tailscale0` only (port 8090) |
| llama.cpp, whisper.cpp, Piper, SearXNG, n8n, Portainer, Homepage, PostgreSQL | localhost only (Serve for HTTPS front doors) |
| Tailscale | closed (`openFirewall = false`) |
| Steam Remote Play | closed (`remotePlay.openFirewall = false`) |

## Secrets (agenix)

All secrets use [agenix](https://github.com/ryantm/agenix). Encrypted files in `secrets/` are safe to commit; decrypted copies live in `/run/agenix/` at activation only.

| Secret | File |
|--------|------|
| Tailscale auth key | `secrets/tailscale-auth-key.age` |
| SearXNG secret key | `secrets/searxng-secret-key.age` |
| n8n DB password | `secrets/n8n-db-password.age` |
| Uptime Kuma sync env | `secrets/uptime-kuma-sync.env.age` |

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
systemctl status tailscale-serve-apps homepage-dashboard n8n postgresql ntfy-sh uptime-kuma docker
tailscale serve status
systemctl status llama-cpp whisper-cpp piper searx tailscaled
curl http://127.0.0.1:8080/v1/models
curl http://127.0.0.1:8081/v1/audio/transcriptions
curl http://127.0.0.1:8082/health
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
- `modules/core/hostname.nix` includes the hostname.
- `modules/users/rileyt.nix` includes the local username and groups.
- Do not commit private keys, access tokens, age identities, or plaintext credentials.
- Encrypted `secrets/*.age` files **are** intended for git (agenix).

Commit secrets only via agenix-encrypted `.age` files. Keep decryption keys (SSH host key, user key) off GitHub.
