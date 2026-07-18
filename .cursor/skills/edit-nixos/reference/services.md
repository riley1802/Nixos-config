# Services

| Service | Module | URL / port | Notes |
|---------|--------|------------|-------|
| llama.cpp | `modules/services/llama-cpp.nix` | http://127.0.0.1:8080/v1 | CUDA via `pkgsUnstable`, localhost only |
| whisper.cpp | `modules/services/whisper-cpp.nix` | http://127.0.0.1:8081/v1/audio/transcriptions | Runs as `rileyt`, model dir persisted |
| Piper TTS | `modules/services/piper.nix` | http://127.0.0.1:8082 | Runs as `rileyt`, voice dir persisted |
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

## Homepage

- Built-in `services.homepage-dashboard` module on port 8083
- No bind-address option; listens on all interfaces, but direct firewall access stays closed
- Reached from the tailnet through Tailscale Serve on port 443
- Title: Homeport; `color = slate`; cool geometric grid CSS (no warm/amber cast)
- Theme switcher kept (dark first-visit default via `customJS`); soft cool-gray light mode
- Layout (whiteboard grid): System row → header widgets (at-a-glance) → Workspace row (Apps + Bookmarks | Automation | Monitoring) → Bottom row (AI / Local | Containers). Bookmarks are service tiles (not `bookmarks.yaml`) so they can nest beside Apps.
- Section chrome: `customCSS` draws a bounding box around each leaf `.services-group` and `#information-widgets`
- System tiles use `customapi` against `gpu-stats` (`127.0.0.1:8091`)
- Service tiles have `siteMonitor` latency (ms); Piper uses `/health`
- Widgets (section 2): datetime, Open-Meteo (Chicago / `America/Chicago`), resources + uptime, SearXNG search

## GPU stats API

- Module: `modules/services/gpu-stats.nix`
- Bind: `127.0.0.1:8091` (localhost only, firewall closed)
- Endpoints: `/` (full), `/host`, `/gpu/0`, `/gpu/1`
- Runs as `rileyt` with `PrivateDevices = false` so `nvidia-smi` works

## Tailscale Serve + dashboard stack

- Unit: `tailscale-serve-apps.service` (oneshot, `tailscale serve --bg --https=…`)
- `:443` → Homepage `http://127.0.0.1:8083`
- `:5678` → n8n `http://127.0.0.1:5678` (n8n `N8N_LISTEN_ADDRESS=127.0.0.1`, `N8N_PROTOCOL=https`, `N8N_PROXY_HOPS=1`)
- `:9443` → Portainer `https+insecure://127.0.0.1:9443` (no `--base-url`)
- Uptime Kuma (`:3001`) and ntfy (`:8090`) stay direct on `tailscale0`
- Uptime Kuma monitors: Nix list in `uptime-kuma.nix` → `uptime-kuma-sync.py` (uptime-kuma-api); tag `nix-managed`; ntfy provider `ntfy-homeport`; secret `uptime-kuma-sync.env.age`
- Homepage `allowedHosts` includes `nixos.taile9f484.ts.net` and localhost `:8083`
- n8n DB password: agenix → oneshot `n8n-postgres-password` → `ALTER USER n8n`
- `rileyt` in `docker` group
- Requires Serve enabled in Tailscale admin for this node

## Homeport Desktop (tray app)

- Project: `apps/homeport-tray/` (Tauri v2, Rust); package: `apps/homeport-tray/default.nix`; flake output: `packages.x86_64-linux.homeport-tray`
- Home Manager module: `home/programs/homeport-tray.nix` (imported from `home.nix`)
- Main window loads `http://127.0.0.1:8083` directly (the existing Homepage dashboard) — no separate frontend, `frontendDist` is an unused placeholder (`apps/homeport-tray/src-tauri/dist/`)
- Close button hides to tray instead of quitting; tray menu: Show Dashboard / Reload / Quit; left-click toggles window visibility
- Reload uses a cache-busting navigation (`/?<timestamp>`) so Homepage `customCSS`/layout changes show up in WebKitGTK; after dashboard chrome edits also `systemctl --user restart homeport-tray`
- Tray status is driven **only** by subscribing to `http://127.0.0.1:8090/<topic>/json` (ntfy NDJSON stream) — no independent health polling; each message becomes a native notification (`tauri-plugin-notification`) and swaps the tray icon (normal/alert) based on whether the text contains "down"
- `NTFY_TOPIC` comes from the existing `age.secrets.uptime-kuma-sync` file; that secret's `owner` was changed from default `root` to `rileyt` so this user-session service can read it (root-run `uptime-kuma-sync.service` still reads it fine — root bypasses file permissions). The path itself is threaded from `flake.nix`'s home-manager block (`uptimeKumaSyncEnvFile = config.age.secrets.uptime-kuma-sync.path`) into `extraSpecialArgs`, not hand-typed as a `"/run/agenix/…"` string in the home-manager module
- All window show()/hide() calls (single-instance re-launch, tray click, close-to-tray) are dispatched via `app.run_on_main_thread(...)` — GTK/WebKitGTK calls from other threads (single-instance's D-Bus listener, the ntfy tokio task) crash with a Wayland protocol error
- `main()` sets `WEBKIT_DISABLE_DMABUF_RENDERER=1` and `__NV_DISABLE_EXPLICIT_SYNC=1` before building the app — required on this machine's dual-NVIDIA + Wayland session, or hiding/showing the window crashes the whole process (see `lessons.md`)
- Autostart: `systemd.user.services.homeport-tray`, `WantedBy = graphical-session.target`, launched with `--start-hidden`
- Requires `gnomeExtensions.appindicator` (already installed in `modules/desktop/gnome-extensions.nix`) for the tray icon to render on GNOME Shell at all
- Runtime deps (`buildInputs` in `apps/homeport-tray/default.nix`): `gtk3`, `webkitgtk_4_1`, `libsoup_3`, `libayatana-appindicator`, `openssl`, `dbus`, `glib`. `libayatana-appindicator` is `dlopen()`'d at runtime (not linked) — `preFixup` adds it to `LD_LIBRARY_PATH` via `gappsWrapperArgs`, or the tray icon panics on startup
- Rebuild/test the package alone: `nix build .#homeport-tray`

## Gaming (Steam)

- Steam enabled; Remote Play does **not** open firewall ports
