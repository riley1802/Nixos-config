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
| llama.cpp API | http://127.0.0.1:8080/v1 | `modules/services/llama-cpp.nix` |
| whisper.cpp | http://127.0.0.1:8081/v1/audio/transcriptions | `modules/services/whisper-cpp.nix` |
| Piper TTS | http://127.0.0.1:8082 | `modules/services/piper.nix` |
| SearXNG | http://127.0.0.1:8888 | `modules/services/searxng.nix` |
| Tailscale | tailnet (MagicDNS) | `modules/services/tailscale.nix` |
| Hermes Agent | CLI + gateway (local llama.cpp) | `modules/services/hermes-agent.nix` |

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

### whisper.cpp

- Local speech-to-text HTTP service.
- Runs as `rileyt` and binds to `127.0.0.1:8081`.
- Models persist under `/var/lib/whisper-cpp/models`.

### Piper TTS

- Local text-to-speech HTTP wrapper around `piper`.
- Runs as `rileyt` and binds to `127.0.0.1:8082`.
- Voices persist under `/var/lib/piper/voices`.

### Tailscale

- Mesh VPN via `services.tailscale`.
- Auth key managed by agenix (`secrets/tailscale-auth-key.age`).
- SSH (`port 22`) allowed on `tailscale0` only — not open on LAN/WAN.
- Connect remotely: `ssh rileyt@nixos` from another tailnet device.
- **After revoking a key in Tailscale admin**, create a new key and run `agenix -e secrets/tailscale-auth-key.age` before rebuilding.

### Hermes Agent

Declarative config under `modules/services/hermes-agent/` (settings, secrets, documents).

| Piece | Path |
|-------|------|
| Service module | `modules/services/hermes-agent/default.nix` |
| Web dashboard | `modules/services/hermes-dashboard.nix` → http://127.0.0.1:9119 |
| Config settings | `modules/services/hermes-agent/settings.nix` |
| Discord + email secrets | `modules/services/hermes-agent/secrets.nix` + `secrets/hermes-env.age` |
| Persona files | `modules/hermes/SOUL.md`, `modules/hermes/USER.md` |

**Already wired:** local llama.cpp chat, SearXNG web search, full CLI toolset, Discord gateway (after secrets), Spotify tools (after client ID + OAuth), optional email, DM pairing, compression, memory, Edge TTS, local STT, **web dashboard** (systemd, port 9119), **desktop app** (`hermes-desktop` in app menu). Discord is set for **mention-free** chat in server channels (private server use).

#### One-time setup (you do these once)

1. **Discord bot** — [Discord Developer Portal](https://discord.com/developers/applications): New Application → Bot → copy token. Enable **Message Content Intent** (and **Server Members Intent** if using role allowlists). Invite the bot to your server (OAuth2 → URL Generator: `bot` + `applications.commands`).

2. **Discord secrets** — create agenix secret from `secrets/hermes-env.example`:

   ```sh
   cd /etc/nixos/secrets
   agenix -e hermes-env.age
   sudo nixos-rebuild switch --flake /etc/nixos#nixos
   ```

   Required keys: `DISCORD_BOT_TOKEN`, `DISCORD_ALLOWED_USERS` (your Discord user snowflake — Settings → Advanced → Developer Mode → right-click avatar → Copy User ID). Full guide: [Hermes Discord docs](https://hermes-agent.nousresearch.com/docs/user-guide/messaging/discord).

3. **Email (optional, Gmail example)** — add to the same `hermes-env.age` file. Use a [Gmail app password](https://myaccount.google.com/apppasswords), not your login password.

4. **Approve DMs (optional)** — unauthorized DMs get a pairing code when `gateway.unauthorized_dm_behavior = pair`:

   ```sh
   hermes pairing list
   hermes pairing approve discord ABCD1234
   ```

5. **Spotify** — create a [Spotify Developer app](https://developer.spotify.com/dashboard) (Web API, redirect URI `http://127.0.0.1:43827/spotify/callback`). Add to `hermes-env.age`:

   ```
   HERMES_SPOTIFY_CLIENT_ID=your-client-id
   ```

   Rebuild, then complete OAuth once (opens browser). **Use the shared state** — `hermes auth spotify` (not `~/.hermes`; a symlink is created automatically):

   ```sh
   hermes auth spotify
   sudo systemctl restart hermes-agent
   ```

   Spotify tools are enabled on CLI and Discord. Playback control requires Spotify Premium and an active device (phone/desktop app open).

#### Day-to-day

- **Web dashboard:** http://127.0.0.1:9119 (`systemctl status hermes-dashboard`)
- **Desktop app:** launch **Hermes Agent** from the app menu, or run `hermes-desktop`
- CLI: `hermes` or `hermes --tui`
- Change declarative settings: edit `settings.nix` or `modules/hermes/*.md`, rebuild
- Runtime-only changes (`hermes setup`) live in `/var/lib/hermes/.hermes/` and may be overwritten for keys defined in Nix

## Firewall policy

Services do not open the public firewall unless explicitly intended:

| Service | Firewall |
|---------|----------|
| SSH | `tailscale0` only (port 22) |
| llama.cpp, whisper.cpp, Piper, SearXNG | localhost only |
| Hermes Agent gateway | localhost / systemd only (no firewall ports) |
| Tailscale | closed (`openFirewall = false`) |
| Steam Remote Play | closed (`remotePlay.openFirewall = false`) |

## Secrets (agenix)

All secrets use [agenix](https://github.com/ryantm/agenix). Encrypted files in `secrets/` are safe to commit; decrypted copies live in `/run/agenix/` at activation only.

| Secret | File |
|--------|------|
| Tailscale auth key | `secrets/tailscale-auth-key.age` |
| SearXNG secret key | `secrets/searxng-secret-key.age` |
| Hermes email creds | `secrets/hermes-env.age` (optional — see `secrets/hermes-env.example`) |

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
systemctl status llama-cpp whisper-cpp piper searx hermes-agent tailscaled
hermes doctor
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
