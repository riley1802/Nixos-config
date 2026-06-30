# Services

| Service | Module | URL / port | Notes |
|---------|--------|------------|-------|
| llama.cpp | `modules/services/llama-cpp.nix` | http://127.0.0.1:8080/v1 | CUDA via `pkgsUnstable`, localhost only |
| SearXNG | `modules/services/searxng.nix` | http://127.0.0.1:8888 | Secret via agenix |
| Tailscale | `modules/services/tailscale.nix` | tailnet | Auth key via agenix |
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
- SSH: port 22 allowed on `tailscale0` only (see `modules/core/openssh.nix`)
