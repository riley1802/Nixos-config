# Services

| Service | Module | URL / port | Notes |
|---------|--------|------------|-------|
| llama.cpp | `modules/services/llama-cpp.nix` | http://127.0.0.1:8080/v1 | CUDA via `pkgsUnstable`, localhost only |
| whisper.cpp | `modules/services/whisper-cpp.nix` | http://127.0.0.1:8081/v1/audio/transcriptions | Runs as `rileyt`, model dir persisted |
| Piper TTS | `modules/services/piper.nix` | http://127.0.0.1:8082 | Runs as `rileyt`, voice dir persisted |
| SearXNG | `modules/services/searxng.nix` | http://127.0.0.1:8888 | Secret via agenix |
| Tailscale | `modules/services/tailscale.nix` | tailnet | Auth key via agenix |
| Hermes Agent | `modules/services/hermes-agent.nix` | gateway (systemd) | CLI + gateway; local llama.cpp provider |
| printing | `modules/services/printing.nix` | — | CUPS |

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

- `--n-gpu-layers 999`, `--flash-attn on`, `--ctx-size 4096`
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

## Hermes Agent

- Flake input: `github:NousResearch/hermes-agent` (package v0.18.0+)
- Module: upstream `nixosModules.default` via `modules/services/hermes-agent.nix`
- CLI: `hermes` on system PATH (`addToSystemPackages = true`)
- Gateway: `systemd.services.hermes-agent` (`hermes gateway`)
- State: `/var/lib/hermes/.hermes` (`HERMES_HOME`, shared with CLI)
- User `rileyt` in `hermes` group for read/write to shared state
- LLM: local llama.cpp at `http://127.0.0.1:8080/v1`, model `gemma-4-e4b-q8`
- Depends on `llama-cpp.service`
- Messaging (Telegram, Discord, etc.): configure with `hermes gateway setup` after install; platform tokens via agenix if added later

## Gaming (Steam)

- Steam enabled; Remote Play does **not** open firewall ports
