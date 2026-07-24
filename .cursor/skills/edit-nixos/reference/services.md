# Services

| Service | Module | URL / port | Notes |
|---------|--------|------------|-------|
| llama.cpp | `modules/services/llama-cpp.nix` | dual `:8084`/`:8085`, Phi `:8080` (Serve) | CUDA `pkgsUnstable`; desktop dual+phi mode; legion single router |
| whisper.cpp | `modules/services/whisper-cpp.nix` | https://nixos.taile9f484.ts.net:8081 (local `127.0.0.1:8081`) | Runs as `rileyt`, model dir persisted; Serve TLS |
| Piper TTS | `modules/services/piper.nix` | https://nixos.taile9f484.ts.net:8082 (local `127.0.0.1:8082`) | Runs as `rileyt`, voice auto-download; Serve TLS |
| Unsloth Studio | `modules/services/unsloth-studio.nix` | https://nixos.taile9f484.ts.net:8000 (local `127.0.0.1:8000`) | Docker `unsloth/unsloth` + CUDA; Serve TLS |
| SearXNG | `modules/services/searxng.nix` | http://127.0.0.1:8888 | Secret via agenix |
| Tailscale | `modules/services/tailscale.nix` | tailnet | Auth key via agenix |
| Tailscale Serve | `modules/services/tailscale-serve.nix` | HTTPS on MagicDNS | CLI oneshot (not `services.tailscale.serve` — HTTPS broken in set-config) |
| Homepage | `modules/services/homepage-dashboard.nix` | https://nixos.taile9f484.ts.net/ (upstream `:8083`) | Direct firewall closed; Serve on `:443` |
| n8n | `modules/services/n8n.nix` | https://nixos.taile9f484.ts.net:5678 | Localhost bind; Serve TLS; Postgres + agenix password |
| Portainer | `modules/services/docker.nix` | https://nixos.taile9f484.ts.net:9443 | Localhost `:9443`; Serve TLS (`https+insecure` backend) |
| ntfy | `modules/services/ntfy-sh.nix` | http://nixos.taile9f484.ts.net:8090 | Own port on `tailscale0` (no subpath — upstream rejects path in `base-url`) |
| Uptime Kuma | `modules/services/uptime-kuma.nix` | http://nixos.taile9f484.ts.net:3001 | Not proxied; declarative sync via `uptime-kuma-sync.service` + ntfy alerts |
| PostgreSQL | `modules/services/postgresql.nix` | `127.0.0.1:5432` | DB `n8n` only |
| Docker | `modules/services/docker.nix` | — | `oci-containers` + nvidia-container-toolkit |
| printing | `modules/services/printing.nix` | — | CUPS |

## llama.cpp

- Package: `pkgsUnstable.llama-cpp.override { cudaSupport = true; }`
- Models dir: `/var/lib/llama-cpp/models` (persistent, tmpfiles rule)
- Runs as `rileyt`; `LLAMA_CACHE=/var/lib/llama-cpp/models`
- Desktop (2+ GPUs): `llama-cpp-nemotron` `:8084` GPU0 + `llama-cpp-qwen` `:8085` GPU1;
  `llama-cpp-mode phi` → exclusive Phi on `:8080` (both GPUs); idle watch restores dual
- Laptop (1 GPU): `llama-cpp` `:8080` router with all aliases, `--models-max 1`
- Tuned winners in module `tuned` attr (cache q8_0, MTP n_max=2, Nemotron ubatch 1024)

### Model presets

| Alias | HF repo | File |
|-------|---------|------|
| `phi4-8k` / `phi4-16k` | unsloth/Phi-4-reasoning-plus-GGUF | Phi-4-reasoning-plus-UD-Q4_K_XL.gguf |
| `nemotron-8k` / `nemotron-16k` | unsloth/NVIDIA-Nemotron-3-Nano-4B-GGUF | NVIDIA-Nemotron-3-Nano-4B-UD-Q4_K_XL.gguf |
| `qwen-8k` / `qwen-16k` | unsloth/Qwen3.5-4B-MTP-GGUF | Qwen3.5-4B-UD-Q4_K_XL.gguf (MTP) |

### GPU flags

- Common: `--models-max 1`, `--n-gpu-layers 999`, `--flash-attn on`, `--cache-type-k/v q8_0`, `--parallel 1`, `--kv-unified`
- Dual pins: Nemotron `--main-gpu 0 --ubatch-size 1024`, Qwen `--main-gpu 1` + MTP `n_max=2`, Phi `--split-mode layer --tensor-split 1,1`

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
- Default voice: `en_US-lessac-medium` — `ExecStartPre` downloads `.onnx` + `.onnx.json` from HF `rhasspy/piper-voices` if missing
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

## Homepage

- Built-in `services.homepage-dashboard` module on port 8083
- No bind-address option; listens on all interfaces, but direct firewall access stays closed
- Reached from the tailnet through Tailscale Serve on port 443
- Dark 4-column layout: header widgets (resources, DuckDuckGo, datetime, Chicago weather), service groups (System & Monitoring, Network & Infra, AI / Local, Productivity), footer bookmarks
- GPU/Host/Network tiles via `gpu-stats` customapi (`127.0.0.1:8091`); `statusStyle = "dot"` + `siteMonitor` (no API widgets for Portainer/Kuma)
- Tailnet `href`s from `config.host.tailnetName`; GPU labels from `config.host.gpus`

## GPU stats API

- Module: `modules/services/gpu-stats.nix`
- Bind: `127.0.0.1:8091` (localhost only, firewall closed)
- Endpoints: `/` (full), `/host`, `/network` (live `enp132s0` throughput), `/gpu/0`, `/gpu/1`
- Runs as `rileyt` with `PrivateDevices = false` so `nvidia-smi` works

## Tailscale Serve + dashboard stack

- Unit: `tailscale-serve-apps.service` (oneshot, `tailscale serve --bg --https=…`)
- `:443` → Homepage `http://127.0.0.1:8083`
- `:5678` → n8n `http://127.0.0.1:5678` (n8n `N8N_LISTEN_ADDRESS=127.0.0.1`, `N8N_PROTOCOL=https`, `N8N_PROXY_HOPS=1`)
- `:9443` → Portainer `https+insecure://127.0.0.1:9443` (no `--base-url`)
- `:8080` / `:8084` / `:8085` / `:8081` / `:8082` → Phi / Nemotron / Qwen / whisper / Piper on localhost
- `:8000` → Unsloth Studio on localhost
- Uptime Kuma (`:3001`) and ntfy (`:8090`) stay direct on `tailscale0`
- Uptime Kuma monitors: Nix list in `uptime-kuma.nix` → `uptime-kuma-sync.py` (uptime-kuma-api); tag `nix-managed`; ntfy provider `ntfy-homeport`; secret `uptime-kuma-sync.env.age`
- Homepage `allowedHosts` includes `nixos.taile9f484.ts.net` and localhost `:8083`
- n8n DB password: agenix → oneshot `n8n-postgres-password` → `ALTER USER n8n`
- `rileyt` in `docker` group
- Requires Serve enabled in Tailscale admin for this node

## Unsloth Studio

- Image: `unsloth/unsloth:latest` via `virtualisation.oci-containers` (Docker backend)
- Studio UI: `127.0.0.1:8000` (Jupyter left unmapped — host `:8888` is SearXNG; container SSH not published)
- GPU: `--device=nvidia.com/gpu=all` (CDI; `--gpus=all` fails here — see lessons.md) + toolkit from `docker.nix`
- Data: `/var/lib/unsloth-studio/{work,exports,outputs,auth,cache,hf-cache}`
- Secrets: `secrets/unsloth-studio.env.age` → `JUPYTER_PASSWORD`, `USER_PASSWORD`
- Hub downloads: `HF_HUB_DISABLE_XET=1`, `HF_HUB_ENABLE_HF_TRANSFER=0` (Xet stalls on this host)
- Perf: `LLAMA_SERVER_PATH` wrapper caps context to 8192, forces `q8_0` KV; vision mmproj always on (`UNSLOTH_ALLOW_MMPROJ=1`); both GPUs (`CUDA_VISIBLE_DEVICES=0,1`)
- First Studio visit sets a UI password (persisted under `auth/`)
- Shares VRAM with llama.cpp when training — stop or idle llama.cpp if you OOM

## Gaming (Steam)

- Steam enabled; Remote Play does **not** open firewall ports

## KDE Connect

- `modules/programs/kdeconnect.nix` — `programs.kdeconnect.enable = true` (shared via `hosts/common.nix`)
- Package: `kdePackages.kdeconnect-kde`; opens TCP/UDP `1714–1764` for LAN phone pairing
