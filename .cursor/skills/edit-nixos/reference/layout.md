# Module Layout

## System (`configuration.nix` imports)

| Path | Module |
|------|--------|
| `modules/core/boot.nix` | Boot |
| `modules/core/locale.nix` | Locale |
| `modules/core/networking.nix` | Networking |
| `modules/core/openssh.nix` | OpenSSH (host keys for agenix) |
| `modules/core/agenix.nix` | agenix identity paths |
| `modules/core/system.nix` | System defaults |
| `modules/hardware/nvidia.nix` | NVIDIA |
| `modules/desktop/audio.nix` | Audio |
| `modules/desktop/gnome.nix` | GNOME (system) |
| `modules/programs/firefox.nix` | Firefox |
| `modules/programs/gaming.nix` | Gaming |
| `modules/programs/packages.nix` | System packages |
| `modules/services/llama-cpp.nix` | llama.cpp |
| `modules/services/printing.nix` | Printing |
| `modules/services/searxng.nix` | SearXNG |
| `modules/services/tailscale.nix` | Tailscale |
| `modules/users/rileyt.nix` | User account |

## Home Manager (`home.nix` imports)

| Path | Module |
|------|--------|
| `home/core/default.nix` | Core HM settings |
| `home/desktop/gnome.nix` | GNOME (user) |
| `home/programs/packages.nix` | User packages |

## Secrets (`secrets/`)

| File | Purpose |
|------|---------|
| `secrets/secrets.nix` | agenix public keys |
| `secrets/tailscale-auth-key.age` | Tailscale auth key |
| `secrets/searxng-secret-key.age` | SearXNG `SEARXNG_SECRET_KEY` |
