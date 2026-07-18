# Services

| Service | Module | URL / port | Notes |
|---------|--------|------------|-------|
| llama.cpp | `modules/services/llama-cpp.nix` | http://127.0.0.1:8080/v1 | CUDA via `pkgsUnstable`, localhost only |
| whisper.cpp | `modules/services/whisper-cpp.nix` | http://127.0.0.1:8081/v1/audio/transcriptions | Runs as `rileyt`, model dir persisted |
| Piper TTS | `modules/services/piper.nix` | http://127.0.0.1:8082 | Runs as `rileyt`, voice dir persisted |
| SearXNG | `modules/services/searxng.nix` | http://127.0.0.1:8888 | Secret via agenix |
| Tailscale | `modules/services/tailscale.nix` | tailnet | Auth key via agenix |
| printing | `modules/services/printing.nix` | — | CUPS |
| nginx | `modules/services/nginx.nix` | http://nixos.taile9f484.ts.net/ (port 80 on `tailscale0`) | Path proxy front door |
| Homepage | `modules/services/homepage-dashboard.nix` | via nginx `/` (upstream `127.0.0.1:8083`) | `openFirewall = false` |
| n8n | `modules/services/n8n.nix` | via nginx `/n8n/` (upstream `127.0.0.1:5678`) | Postgres + agenix password |
| Portainer | `modules/services/docker.nix` | via nginx `/portainer/` (upstream `127.0.0.1:9443`) | `portainer/portainer-ce:2.39.4` |
| ntfy | `modules/services/ntfy-sh.nix` | http://nixos.taile9f484.ts.net:8090 | Own port on `tailscale0` (no subpath — upstream rejects path in `base-url`) |
| Uptime Kuma | `modules/services/uptime-kuma.nix` | http://nixos.taile9f484.ts.net:3001 | Not proxied (no subpath support) |
| PostgreSQL | `modules/services/postgresql.nix` | `127.0.0.1:5432` | DB `n8n` only |
| Docker | `modules/services/docker.nix` | — | `oci-containers` + nvidia-container-toolkit |

## llama.cpp

- Package: `pkgsUnstable.llama-cpp.override { cudaSupport = true; }`
- Models dir: `/var/lib/llama-cpp/models` (persistent, tmpfiles rule)
- Runs as `rileyt` (DynamicUser disabled)
- `LLAMA_CACHE=/var/lib/llama-cpp/models`

### Model presets

| Alias | HF repo | File |
|-------|---------|------|
| `gemma-4-e4b-q8` | unsloth/gemma-4-E4B-it-GGUF | gemma-4-E4B-it-Q8_0.gguf |
| `nemotron-nano-12b-v2-q4` | MaziyarPanahi/NVIDIA-Nemotron-Nano-12B-v2-GGUF | NVIDIA-Nemotron-Nano-12B-v2.Q4_K_M.gguf |
| `gemma-4-12b-q4-mtp` | unsloth/gemma-4-12b-it-GGUF | gemma-4-12b-it-Q4_K_M.gguf (MTP drafter) |

### GPU flags

- `--n-gpu-layers 999`, `--flash-attn on`, `--ctx-size 65536`, `--cache-type-k/v q4_0`, `--parallel 1`, `--kv-unified`, `--sleep-idle-seconds 1800`
- Dual GPU: `--split-mode layer`, `--tensor-split 1,1`, `--main-gpu 0`

## whisper.cpp

- Package: `pkgs.whisper-cpp`
- Service: `systemd.services.whisper-cpp` (custom module)
- Bind: `127.0.0.1:8081`
- Inference path: `/v1/audio/transcriptions`
- Model dir: `/var/lib/whisper-cpp/models` (persistent, tmpfiles rule)
- Default startup model: `ggml-base.bin` (auto-downloaded if missing)
- Runs as `rileyt` with `DynamicUser = false`

## Piper TTS

- Package: `pkgs.piper-tts`
- Service: `systemd.services.piper` (custom module, stdlib HTTP wrapper)
- Bind: `127.0.0.1:8082`
- Health endpoint: `/health`
- Voice dir: `/var/lib/piper/voices` (persistent, tmpfiles rule)
- Default voice name: `en_US-lessac-medium` (if present)
- Runs as `rileyt` with `DynamicUser = false`

## SearXNG

- Instance: Local SearXNG
- Bind: 127.0.0.1:8888
- Secret: `secrets/searxng-secret-key.age` → `/run/agenix/searxng-secret-key`
- Formats: html, json
- Firewall: closed

## Tailscale

- Enabled via `services.tailscale`
- Auth key: `secrets/tailscale-auth-key.age` → `authKeyFile`
- Firewall: closed (`openFirewall = false`)
- SSH: port 22 on `tailscale0` only (`modules/core/openssh.nix`)
- Revoked keys must be replaced via `agenix -e` before rebuild

## nginx + dashboard stack

- nginx listens on `0.0.0.0:80`, firewall open on `tailscale0` only
- Path routing: `/` → Homepage `:8083`, `/n8n/` → n8n, `/portainer/` → Portainer HTTPS
- Uptime Kuma (`:3001`) and ntfy (`:8090`) stay direct on `tailscale0` (ntfy rejects path in `base-url`)
- Homepage `allowedHosts` includes `nixos.taile9f484.ts.net` and localhost `:8083`
- n8n DB password: agenix → oneshot `n8n-postgres-password` → `ALTER USER n8n`
- `rileyt` in `docker` group

## Gaming (Steam)

- Steam enabled; Remote Play does **not** open firewall ports
