# llama.cpp research stack — session handoff

**Audience:** another agent continuing this project (orchestration, agent research loop, tooling, UI, etc.).  
**Host:** `nixos` desktop — RTX 3050 6GB (GPU0) + GTX 1660 SUPER 6GB (GPU1).  
**Date:** 2026-07-23.  
**Repo:** `/etc/nixos` → `riley1802/Nixos-config` (`main`).

This document is the product of one session: tear down the old Gemma/Nemotron-12B router, deploy a dual-GPU + exclusive-Phi stack for an agent research loop, tune for TPS at 16k with q8 KV, and quality-check.

---

## 1. Goal (what this stack is for)

- Local OpenAI-compatible inference for an **agent research loop**.
- **Three models:**
  - Phi-4-reasoning-plus runs **alone** (needs both GPUs).
  - Nemotron-3-Nano-4B + Qwen3.5-4B-MTP run **together**, ideally **one per GPU**.
- **Zero-friction switching** between dual (two 4Bs) and Phi exclusive.
- Separate **8k / 16k** aliases per model.
- Tuned once via bench sweeps; winners **hardcoded in Nix** (no runtime autotuner).

---

## 2. Architecture (desktop, 2 GPUs)

```
Default (dual mode)                    Phi mode (exclusive)
─────────────────────                  ────────────────────
GPU0: Nemotron  → :8084                GPU0+GPU1: Phi → :8080
GPU1: Qwen MTP  → :8085                (dual stopped)

Switch: llama-cpp-mode phi|dual|status
Idle:   Phi unloaded ~60s → auto dual restore
```

| Mode | Units | Ports | VRAM |
|------|-------|-------|------|
| **dual** (boot default) | `llama-cpp-nemotron`, `llama-cpp-qwen` | `127.0.0.1:8084`, `:8085` | one 4B per GPU |
| **phi** | `llama-cpp-phi` (+ `llama-cpp-phi-idle-watch`) | `127.0.0.1:8080` | layer-split both GPUs |

**Legion (1 GPU):** same module falls back to a single `llama-cpp` router on `:8080` with all aliases and `--models-max 1` (no dual ports).

**Module:** `modules/services/llama-cpp.nix` (imported via `hosts/common.nix`).  
**Does not use** nixpkgs `services.llama-cpp` — custom systemd units.

**Tailscale Serve:** HTTPS `:8080`, `:8084`, `:8085` → localhost (see `modules/services/tailscale-serve.nix`).

---

## 3. Models and aliases

| Alias | Port (desktop) | HF repo | File | Notes |
|-------|----------------|---------|------|-------|
| `nemotron-8k` / `nemotron-16k` | `:8084` | `unsloth/NVIDIA-Nemotron-3-Nano-4B-GGUF` | `NVIDIA-Nemotron-3-Nano-4B-UD-Q4_K_XL.gguf` | ~3.1 GB |
| `qwen-8k` / `qwen-16k` | `:8085` | `unsloth/Qwen3.5-4B-MTP-GGUF` | `Qwen3.5-4B-UD-Q4_K_XL.gguf` | ~2.8 GB, MTP |
| `phi4-8k` / `phi4-16k` | `:8080` (phi mode) | `unsloth/Phi-4-reasoning-plus-GGUF` | `Phi-4-reasoning-plus-UD-Q4_K_XL.gguf` | ~8.4–9 GB |

- Models cache: `LLAMA_CACHE=/var/lib/llama-cpp/models` (HF download on first use).
- Router mode per service: `--models-max 1` (evict before load).
- Jinja chat templates on for all presets.

---

## 4. Production tuned flags (`tuned` in module)

| Setting | Value | Scope |
|---------|-------|--------|
| `--flash-attn` | `on` | all |
| `--cache-type-k/v` | **`q8_0` / `q8_0`** | all (symmetric — required for fused FA) |
| `--n-gpu-layers` | `999` | all |
| `--parallel` | `1` | all (single concurrent request) |
| `--kv-unified` | on | all |
| `--ubatch-size` | **`1024`** | Nemotron only |
| `--spec-type` / `--spec-draft-n-max` | `draft-mtp` / **`2`** | Qwen only |
| `--main-gpu` / `--split-mode` | `0` / `none` | Nemotron |
| `--main-gpu` / `--split-mode` | `1` / `none` | Qwen |
| `--split-mode` / `--tensor-split` | `layer` / `1,1` | Phi |
| `--sleep-idle-seconds` | `1800` dual / `300` Phi | unload idle model |

**No `q6` KV type** in this llama.cpp build (b9747). Allowed: `f32, f16, bf16, q8_0, q4_0, q4_1, iq4_nl, q5_0, q5_1`.  
`q5_0` was tried as a “q6 floor” substitute — **catastrophically slow** (~8–15 t/s); do not use.

---

## 5. How to operate

```bash
# Status
llama-cpp-mode status
systemctl status llama-cpp-nemotron llama-cpp-qwen llama-cpp-phi

# Dual (default) — agent research with two 4Bs
curl http://127.0.0.1:8084/v1/models   # nemotron-8k | nemotron-16k
curl http://127.0.0.1:8085/v1/models   # qwen-8k | qwen-16k

# Phi exclusive — stops dual
llama-cpp-mode phi
curl http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"phi4-16k","messages":[{"role":"user","content":"..."}]}'

# Back to dual
llama-cpp-mode dual
```

OpenAI base URLs:

| Role | Base URL |
|------|----------|
| Nemotron | `http://127.0.0.1:8084/v1` |
| Qwen | `http://127.0.0.1:8085/v1` |
| Phi | `http://127.0.0.1:8080/v1` (after `llama-cpp-mode phi`) |

Remote (tailnet): `https://nixos.taile9f484.ts.net:8084` / `:8085` / `:8080`.

---

## 6. Benchmark results (16k focus)

Artifacts (may be wiped on reboot): `/tmp/llama-tps-q8/`  
Key files: `WINNERS.md`, `QUALITY.md`, `CONSTRAINTS.md`, `METHODS.md` (if present), `quality/`.

### Warm server gen TPS (production path)

| Model | Config | Warm gen t/s |
|-------|--------|--------------|
| Nemotron | 16k, q8, ub1024, GPU0 | **~40** |
| Qwen MTP | 16k, q8, n_max=2..3, GPU1 | **~71–73** |
| Phi | 16k, q8, layer split | **~18.6** |

### llama-bench @ 16k (`-p 512 -n 128 -d 16384`)

| Model | KV | pp512 | tg128 | Notes |
|-------|-----|-------|-------|-------|
| Nemotron | q8_0 | **1086.5** | 34.70 | production |
| Nemotron | q4_0 | 1065.2 | **35.24** | +1.6% tg, worse KV fidelity |
| Nemotron | q5_0 | 14.7 | 8.5 | reject |
| Qwen | q8_0 | **162.7** | **50.8** | production (no MTP in bench) |
| Qwen | q4_0 | 161.3 | 48.3 | q8 wins tg |
| Qwen | q5_0 | 9.9 | 5.7 | reject |
| Phi | any | — | — | **llama-bench OOM** — use phi service only |

### Qwen MTP n_max @ 16k+q8 (server, ~610 tok prompt)

| n_max | gen t/s |
|-------|---------|
| **2** | **~73.3** ← winner |
| 3 | ~70.5 |
| 6 | ~51.9 |

### Why q8 can beat q4 on Qwen

Smaller KV ≠ always faster. On this hardware a 4B at 16k is often **dequant-bound**, not KV-bandwidth-bound. `q4_0` saves memory but costs dequant; fused FA is happier with symmetric `q8_0`. Nemotron sees only a tiny q4 tg edge (~1.6%); Qwen sees q8 faster (~+5% tg).

---

## 7. Quality suite (q4 vs q8 @ 16k)

Fixed prompts, `temperature=0`, `seed=42`. Categories: math, reasoning, code, long-context recall.

| Model | q8_0 | q4_0 |
|-------|------|------|
| Nemotron | all ✅ | all ✅ (equivalent) |
| Qwen MTP | all ✅ | all ✅ — answers often in `reasoning_content`, empty `content` |
| Phi | all ✅ | all ✅ (equivalent) |

**Verdict:** No observable quality regression q4→q8 on this suite. Keep **q8_0** for production (headroom + Qwen TPS).

**Agent note:** When parsing Qwen chat completions, check `reasoning_content` / thinking fields, not only `message.content`.

---

## 8. Phi deep dive (for agents)

- **Not always-on.** Must call `llama-cpp-mode phi` (stops dual).
- Weights ~8.4–9 GB → **must** split across both GPUs (`--split-mode layer --tensor-split 1,1`).
- Cold load ~60–90s; warm ~18.6 gen t/s.
- `llama-bench` cannot load Phi on this desktop (OOM on GPU0 with display); only the systemd phi service path works.
- Idle unload (`--sleep-idle-seconds 300`) + `llama-cpp-phi-idle-watch` restores dual when unloaded for ~60s.
- Aliases: `phi4-8k`, `phi4-16k`.

---

## 9. What was removed

Old `:8080` single router with:

- `gemma-4-e4b-q8`
- `nemotron-nano-12b-v2-q4`
- `gemma-4-12b-q4-mtp`

Replaced entirely. Stray manual `llama-server` on `:18081` (Unsloth Studio) was killed during benches — do not leave ad-hoc servers holding VRAM.

---

## 10. Git commits (local; push status may lag)

| Commit | Summary |
|--------|---------|
| `681203d` | Dual/Phi research stack (replace old presets) |
| `adac04a` | First TPS tune (ubatch 1024, early MTP n_max=3, q4 KV) |
| `f71ac7d` | 16k retune → **q8 KV**, MTP **n_max=2** |
| `57be4b8` | Docs sync (README / SERVICES / reference) |

Related docs also updated: `README.md`, `SERVICES.md`, `.cursor/skills/edit-nixos/reference/services.md`, Homepage tiles, Uptime Kuma monitors, Tailscale Serve ports.

---

## 11. Key file map

| Path | Role |
|------|------|
| `modules/services/llama-cpp.nix` | **Source of truth** — units, presets, `tuned` |
| `modules/services/tailscale-serve.nix` | HTTPS front doors 8080/8084/8085 |
| `modules/services/homepage-dashboard.nix` | UI tiles |
| `modules/services/uptime-kuma.nix` | Monitors for dual ports |
| `LLAMA-CPP-RESEARCH-STACK.md` | This handoff |
| `/var/lib/llama-cpp/models` | HF GGUF cache |
| `/tmp/llama-tps-q8/` | Bench/quality artifacts (ephemeral) |

Package: `pkgsUnstable.llama-cpp.override { cudaSupport = true; }` (~b9747).

---

## 12. Suggested next work (other section of the project)

Downstream agent should assume the **inference layer above is done**. Natural follow-ons:

1. **Agent research loop orchestration**
   - Pick base URL by role (dual vs Phi).
   - Call `llama-cpp-mode phi` before Phi; wait for health/`/v1/models` loaded; restore dual after.
   - Prefer `*-16k` aliases unless context is short.
2. **Client / router layer**
   - Optional single front door that maps logical model names → port + mode switch.
   - Handle Qwen `reasoning_content` empty-`content` quirk.
3. **Warm-up / readiness**
   - Phi cold load is slow; pre-warm or show progress.
4. **Do not re-litigate** unless hardware changes
   - KV stays `q8_0`; Qwen MTP `n_max=2`; Nemotron ubatch 1024; no q5 KV.
5. **Fleet**
   - Desktop has dual layout; Legion is single-router — gate dual-only features on `host.gpus` length ≥ 2.
6. **Push**
   - Confirm with Riley before `git push` to `main` (GitHub is source of truth).

---

## 13. Quick verification checklist

```bash
llama-cpp-mode status
# expect: nemotron=active qwen=active phi=inactive

curl -fsS http://127.0.0.1:8084/health
curl -fsS http://127.0.0.1:8085/health

# Confirm live flags
tr '\0' '\n' < /proc/$(systemctl show -p MainPID --value llama-cpp-nemotron)/cmdline | rg 'cache-type|ubatch|main-gpu'
# expect q8_0, ubatch 1024, main-gpu 0

curl -fsS http://127.0.0.1:8085/v1/models | rg 'spec-draft-n-max'
# expect = 2
```

---

## 14. Constraints remembered from the session

1. Primary metric: **balanced** prompt + gen TPS.  
2. Context: **16k** production focus; 8k aliases kept.  
3. KV: **q8_0** preferred (no q6 type).  
4. Concurrency: **single** request (`--parallel 1`).  
5. Ports: dual always on `:8084`/`:8085`; Phi only on `:8080` when dual is down.  
6. Mode switch: auto stop dual for Phi; idle restore dual.  
7. API: OpenAI-compatible HTTP.  
8. Tune once in Composer loop → hardcode Nix; **ask before push**.
