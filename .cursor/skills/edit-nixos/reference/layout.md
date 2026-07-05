# Module Layout

## System (`configuration.nix` imports)

| Path | Module |
|------|--------|
| `modules/core/boot.nix` | systemd-boot |
| `modules/core/locale.nix` | Timezone and locale |
| `modules/core/hostname.nix` | Hostname |
| `modules/core/networkmanager.nix` | NetworkManager |
| `modules/core/openssh.nix` | OpenSSH — Tailscale-only, host keys for agenix |
| `modules/core/agenix.nix` | agenix identity paths |
| `modules/core/nix.nix` | Nix daemon settings |
| `modules/core/nixpkgs.nix` | nixpkgs config (allowUnfree) |
| `modules/core/state-version.nix` | system.stateVersion |
| `modules/core/polkit-pkexec.nix` | Passwordless pkexec for `rileyt` (agent admin) |
| `modules/hardware/graphics.nix` | OpenGL/Vulkan userspace |
| `modules/hardware/nvidia.nix` | NVIDIA proprietary driver |
| `modules/desktop/gdm.nix` | GDM display manager |
| `modules/desktop/gnome.nix` | GNOME desktop and dconf |
| `modules/desktop/gnome-extensions.nix` | GNOME extensions and excluded apps |
| `modules/desktop/audio.nix` | PipeWire audio |
| `modules/programs/firefox.nix` | Firefox |
| `modules/programs/steam.nix` | Steam |
| `modules/programs/games-dirs.nix` | `/games` directory layout |
| `modules/programs/packages.nix` | Essential system CLI tools |
| `modules/services/llama-cpp.nix` | llama.cpp |
| `modules/services/whisper-cpp.nix` | whisper.cpp |
| `modules/services/piper.nix` | Piper TTS |
| `modules/services/printing.nix` | CUPS printing |
| `modules/services/searxng.nix` | SearXNG |
| `modules/services/tailscale.nix` | Tailscale |
| `modules/services/hermes-agent/` | Hermes Agent (CLI + gateway, declarative settings) |
| `modules/users/rileyt.nix` | User account |

## Home Manager (`home.nix` imports)

| Path | Module |
|------|--------|
| `home/core/identity.nix` | Username and home directory |
| `home/core/state-version.nix` | home.stateVersion |
| `home/core/home-manager.nix` | Enable Home Manager |
| `home/desktop/cursor.nix` | Pointer cursor theme |
| `home/desktop/gnome/interface.nix` | GNOME interface dconf |
| `home/desktop/gnome/extensions.nix` | GNOME shell extensions dconf |
| `home/desktop/gnome/dash-to-dock.nix` | Dash to Dock dconf |
| `home/programs/utilities.nix` | CLI utilities (htop, ripgrep, fd, unzip) |
| `home/programs/google-chrome.nix` | Google Chrome |
| `home/programs/spotify.nix` | Spotify |
| `home/programs/discord.nix` | Discord |
| `home/programs/cursor.nix` | Cursor editor and CLI |

## Secrets (`secrets/`)

| File | Purpose |
|------|---------|
| `secrets/secrets.nix` | agenix public keys |
| `secrets/tailscale-auth-key.age` | Tailscale auth key |
| `secrets/searxng-secret-key.age` | SearXNG `SEARXNG_SECRET_KEY` |
