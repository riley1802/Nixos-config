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
- `home/` - Home Manager modules for user packages and desktop preferences.

## Local AI Stack

This system runs a local LLM stack with a web UI and web search, all bound to
localhost.

| Service | URL | Module |
|---------|-----|--------|
| llama.cpp API | http://127.0.0.1:8080/v1 | `modules/services/llama-cpp.nix` |
| Open WebUI | http://127.0.0.1:3000 | `modules/services/open-webui.nix` |
| SearXNG | http://127.0.0.1:8888 | `modules/services/searxng.nix` |

Open WebUI talks to llama.cpp over the OpenAI-compatible API and uses SearXNG
for web search.

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

Select a model in Open WebUI by its alias after the service starts.

### Open WebUI

- Connects to llama.cpp at `http://127.0.0.1:8080/v1`.
- Web search enabled via local SearXNG.
- `ENABLE_PERSISTENT_CONFIG = False` so NixOS config stays authoritative.

### SearXNG

- Local meta-search engine with JSON output for Open WebUI.
- Secret key generated at runtime in `/var/lib/searx/searx.env`.

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
systemctl status llama-cpp open-webui searx
```

## Git and GitHub

This repo uses SSH for GitHub authentication so `git push` and `git pull` work
without entering credentials each time.

Remote:

```sh
git@github.com:riley1802/Nixos-config.git
```

If SSH is not set up yet on a new machine:

```sh
mkdir -p ~/.ssh && chmod 700 ~/.ssh
ssh-keygen -t ed25519 -C "your-email@example.com" -f ~/.ssh/id_ed25519 -N ""
ssh-keyscan github.com >> ~/.ssh/known_hosts
```

Add the public key at https://github.com/settings/keys, then verify:

```sh
ssh -T git@github.com
git pull
git push
```

## Publishing Notes

Before pushing this repository publicly, review machine-specific files:

- `hardware-configuration.nix` includes disk UUIDs and hardware details.
- `modules/core/networking.nix` includes the hostname.
- `modules/users/rileyt.nix` includes the local username and groups.
- Do not commit private keys, access tokens, age identities, or plaintext credentials.

Commit secrets only if they are encrypted with a tool such as `sops-nix` or
`agenix`, and keep the decryption keys outside the repository.
