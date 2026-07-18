# NixOS services & programs inventory

Host `nixos`, user `rileyt`. Sourced from `hosts/nixos/configuration.nix` and `home.nix`.

Only options **set in this flake** are listed (not nixpkgs defaults). Secrets are named but never shown in plaintext.

| Status | Meaning |
|--------|---------|
| Active | Module imported and enabled |
| Disabled | Module exists; import commented out |

---

## Quick index — services

| Service | Module | Status | Bind / notes |
|---------|--------|--------|--------------|
| llama.cpp | `modules/services/llama-cpp.nix` | Active | `127.0.0.1:8080` |
| n8n | `modules/services/n8n.nix` | Active | `127.0.0.1:5678` + Tailscale Serve HTTPS |
| whisper.cpp | `modules/services/whisper-cpp.nix` | Active | `127.0.0.1:8081` |
| Piper TTS | `modules/services/piper.nix` | Active | `127.0.0.1:8082` |
| SearXNG | `modules/services/searxng.nix` | Active | `127.0.0.1:8888` |
| Homepage | `modules/services/homepage-dashboard.nix` | Active | port `8083` (direct firewall closed); via Tailscale Serve HTTPS `:443` |
| GPU stats API | `modules/services/gpu-stats.nix` | Active | `127.0.0.1:8091` (Homepage System widgets) |
| Uptime Kuma | `modules/services/uptime-kuma.nix` | Active | `0.0.0.0:3001` (`tailscale0`); declarative API sync |
| ntfy | `modules/services/ntfy-sh.nix` | Active | `0.0.0.0:8090` (`tailscale0`) |
| Tailscale | `modules/services/tailscale.nix` | Active | tailnet |
| Printing (CUPS) | `modules/services/printing.nix` | Active | local |
| OpenSSH | `modules/core/openssh.nix` | Active | TCP 22 on `tailscale0` only |
| NetworkManager | `modules/core/networkmanager.nix` | Active | — |
| PipeWire | `modules/desktop/audio.nix` | Active | — |
| rtkit | `modules/desktop/audio.nix` | Active | realtime audio |
| GDM | `modules/desktop/gdm.nix` | Active | display manager |
| GNOME | `modules/desktop/gnome.nix` | Active | desktop + X server |
| NVIDIA / X video | `modules/hardware/nvidia.nix` | Active | proprietary driver |
| Honcho | `modules/services/honcho.nix` | Disabled | import commented out |

## Quick index — programs

| Program / package set | Module | Scope | Notes |
|----------------------|--------|-------|-------|
| Steam | `modules/programs/steam.nix` | System | `programs.steam` |
| Steam library dirs | `modules/programs/games-dirs.nix` | System | `/games`, `/games/steam-library` |
| Firefox | `modules/programs/firefox.nix` | System | `programs.firefox` |
| CLI tools (system) | `modules/programs/packages.nix` | System | wget, git, curl, gh |
| GNOME Tweaks / extensions | `modules/desktop/gnome-extensions.nix` | System | packages + excludes |
| dconf | `modules/desktop/gnome.nix` | System | `programs.dconf.enable` |
| Home Manager | `home/core/home-manager.nix` | User | `programs.home-manager` |
| Utilities (user) | `home/programs/utilities.nix` | User | htop, ripgrep, fd, unzip |
| Google Chrome | `home/programs/google-chrome.nix` | User | package |
| Spotify | `home/programs/spotify.nix` | User | package |
| Discord | `home/programs/discord.nix` | User | package |
| Cursor (IDE + CLI) | `home/programs/cursor.nix` | User | `code-cursor`, `cursor-cli` |
| Claude Code | `home/programs/claude-code.nix` | User | `pkgsUnstable.claude-code` |
| Pointer cursor | `home/desktop/cursor.nix` | User | Bibata-Modern-Ice |
| GNOME interface | `home/desktop/gnome/interface.nix` | User | dconf |
| GNOME extensions enable | `home/desktop/gnome/extensions.nix` | User | dconf UUIDs |
| Dash to Dock | `home/desktop/gnome/dash-to-dock.nix` | User | dconf |

---

## Application / API services

### llama.cpp

**Module:** `modules/services/llama-cpp.nix`  
**URL:** http://127.0.0.1:8080/v1

#### `services.llama-cpp`

| Option | Value |
|--------|-------|
| `enable` | `true` |
| `package` | `pkgsUnstable.llama-cpp.override { cudaSupport = true; }` |
| `host` | `"127.0.0.1"` |
| `port` | `8080` |
| `openFirewall` | `false` |
| `modelsDir` | `"/var/lib/llama-cpp/models"` |

#### `modelsPreset`

| Alias | `hf-repo` | `hf-file` | Extra |
|-------|-----------|-----------|-------|
| `gemma-4-e4b-q8` | `unsloth/gemma-4-E4B-it-GGUF` | `gemma-4-E4B-it-Q8_0.gguf` | `jinja = "on"` |
| `nemotron-nano-12b-v2-q4` | `MaziyarPanahi/NVIDIA-Nemotron-Nano-12B-v2-GGUF` | `NVIDIA-Nemotron-Nano-12B-v2.Q4_K_M.gguf` | `jinja = "on"` |
| `gemma-4-12b-q4-mtp` | `unsloth/gemma-4-12b-it-GGUF` | `gemma-4-12b-it-Q4_K_M.gguf` | `jinja = "on"`, `spec-type = "draft-mtp"`, `spec-draft-n-max = "2"` |

#### `extraFlags`

```
--n-gpu-layers 999
--flash-attn on
--ctx-size 16384
--cache-type-k q8_0
--cache-type-v q8_0
--parallel 1
--kv-unified
--split-mode layer
--tensor-split 1,1
--main-gpu 0
--sleep-idle-seconds 1800
```

#### systemd overrides (`systemd.services.llama-cpp.serviceConfig`)

| Option | Value |
|--------|-------|
| `DynamicUser` | `false` (forced) |
| `User` | `"rileyt"` |
| `Group` | `"users"` |
| `Environment` | `LLAMA_CACHE=/var/lib/llama-cpp/models` (forced) |

#### Other

| Setting | Value |
|---------|-------|
| `systemd.tmpfiles.rules` | `d /var/lib/llama-cpp/models 0755 rileyt users -` |
| `environment.systemPackages` | CUDA-enabled `llama-cpp` |

---

### n8n

**Module:** `modules/services/n8n.nix`  
**URL:** https://nixos.taile9f484.ts.net:5678/ (via Tailscale Serve, see `tailscale-serve.nix`)

#### `services.n8n.environment`

| Option | Value |
|--------|-------|
| `N8N_HOST` / `WEBHOOK_URL` | `nixos.taile9f484.ts.net` (Tailscale Serve terminates TLS) |
| `N8N_LISTEN_ADDRESS` | `"127.0.0.1"` |
| `N8N_PORT` | `"5678"` |
| `DB_TYPE` | `postgresdb` (local PostgreSQL, role `n8n`, password from agenix `n8n-db-password`) |

#### Local llama.cpp AI credential (`n8n-llama-cpp-credential.service`)

A oneshot unit runs after `n8n.service` and upserts (via `n8n import:credentials`) a fixed-id
`openAiApi` credential named **"llama.cpp (local)"** pointing at llama.cpp's OpenAI-compatible API
(`http://127.0.0.1:8080/v1`, see `llama-cpp.nix`). This lets the **OpenAI Chat Model** / **AI Agent**
nodes use local models (`gemma-4-e4b-q8`, `nemotron-nano-12b-v2-q4`, `gemma-4-12b-q4-mtp`) with zero
manual credential setup. It reads the personal project id from the `n8n` Postgres DB, so on a
brand-new instance (no owner account yet) it skips gracefully — rerun
`systemctl start n8n-llama-cpp-credential` once the first-run setup wizard is done.

---

### whisper.cpp

**Module:** `modules/services/whisper-cpp.nix`  
**URL:** http://127.0.0.1:8081/v1/audio/transcriptions  
**Unit:** custom `systemd.services.whisper-cpp` (no nixpkgs `services.whisper-cpp`)

#### Service unit

| Option | Value |
|--------|-------|
| `description` | `"whisper.cpp HTTP server"` |
| `after` | `[ "network.target" ]` |
| `wantedBy` | `[ "multi-user.target" ]` |

#### `serviceConfig`

| Option | Value |
|--------|-------|
| `Type` | `"simple"` |
| `DynamicUser` | `false` (forced) |
| `User` | `"rileyt"` |
| `Group` | `"users"` |
| `WorkingDirectory` | `/var/lib/whisper-cpp/models` |
| `Restart` | `"on-failure"` |
| `RestartSec` | `"5s"` |
| `Environment` | `PATH` includes `ffmpeg` and `whisper-cpp` |

#### Exec

| Key | Value |
|-----|-------|
| `ExecStartPre` | `mkdir -p` models dir; download `base` model if `ggml-base.bin` missing |
| `ExecStart` | `whisper-server --host 127.0.0.1 --port 8081 --inference-path /v1/audio/transcriptions --convert --model /var/lib/whisper-cpp/models/ggml-base.bin` |

#### Other

| Setting | Value |
|---------|-------|
| Model path | `/var/lib/whisper-cpp/models/ggml-base.bin` |
| `systemd.tmpfiles.rules` | `d /var/lib/whisper-cpp/models 0755 rileyt users -` |
| `environment.systemPackages` | `whisper-cpp`, `ffmpeg` |

---

### Piper TTS

**Module:** `modules/services/piper.nix`  
**URL:** http://127.0.0.1:8082  
**Unit:** custom `systemd.services.piper` (Python stdlib HTTP wrapper around `piper`)

#### Constants (in wrapper)

| Name | Value |
|------|-------|
| Host | `127.0.0.1` |
| Port | `8082` |
| Voices dir | `/var/lib/piper/voices` |
| Default voice | `en_US-lessac-medium` |
| Binary | `${pkgs.piper-tts}/bin/piper` |

#### HTTP API (wrapper)

| Method | Path | Behavior |
|--------|------|----------|
| GET | `/health` | JSON status + voice list |
| GET | `/voices` | JSON voice list |
| POST | `/`, `/synthesize`, `/v1/audio/speech` | JSON `{ text, voice?, ... }` → WAV |

Optional POST body keys passed to piper: `speaker_id`, `length_scale`, `noise_scale`, `noise_w_scale`, `sentence_silence`, `volume`, `cuda`.

#### Service unit

| Option | Value |
|--------|-------|
| `description` | `"Piper local HTTP TTS server"` |
| `after` | `[ "network.target" ]` |
| `wantedBy` | `[ "multi-user.target" ]` |

#### `serviceConfig`

| Option | Value |
|--------|-------|
| `Type` | `"simple"` |
| `DynamicUser` | `false` (forced) |
| `User` | `"rileyt"` |
| `Group` | `"users"` |
| `WorkingDirectory` | `/var/lib/piper/voices` |
| `ExecStart` | `python` + generated `piper-http-server.py` |
| `Restart` | `"on-failure"` |
| `RestartSec` | `"5s"` |

#### Other

| Setting | Value |
|---------|-------|
| `systemd.tmpfiles.rules` | `d /var/lib/piper/voices 0755 rileyt users -` |
| `environment.systemPackages` | `piper-tts` |

---

### SearXNG

**Module:** `modules/services/searxng.nix`  
**URL:** http://127.0.0.1:8888

#### agenix

| Secret | File | Runtime | owner/group/mode |
|--------|------|---------|------------------|
| `searxng-secret-key` | `secrets/searxng-secret-key.age` | `/run/agenix/searxng-secret-key` | `searx` / `searx` / `0400` |

#### `services.searx`

| Option | Value |
|--------|-------|
| `enable` | `true` |
| `package` | `pkgs.searxng` |
| `environmentFile` | `config.age.secrets.searxng-secret-key.path` |
| `settingsFile` | `"/run/searx/settings.yml"` |
| `openFirewall` | `false` |
| `redisCreateLocally` | `false` |
| `configureUwsgi` | `false` |
| `configureNginx` | `false` |
| `domain` | `"localhost"` |
| `uwsgiConfig.http` | `":8080"` |
| `faviconsSettings` | `{ }` |
| `limiterSettings` | `{ }` |

#### `services.searx.settings`

| Option | Value |
|--------|-------|
| `use_default_settings` | `true` |
| `general.debug` | `false` |
| `general.instance_name` | `"Local SearXNG"` |
| `search.safe_search` | `1` |
| `search.autocomplete` | `""` |
| `search.default_lang` | `""` |
| `search.formats` | `[ "html" "json" ]` |
| `server.bind_address` | `"127.0.0.1"` |
| `server.port` | `8888` |
| `server.secret_key` | `"$SEARXNG_SECRET_KEY"` |
| `server.limiter` | `false` |
| `server.image_proxy` | `false` |

---

### Homepage

**Module:** `modules/services/homepage-dashboard.nix`  
**URL:** https://nixos.taile9f484.ts.net/ (Tailscale Serve → `:8083`)

| Option | Value |
|--------|-------|
| `services.homepage-dashboard.enable` | `true` |
| `listenPort` | `8083` |
| `openFirewall` | `false` |
| `allowedHosts` | `"nixos.taile9f484.ts.net,localhost:8083,127.0.0.1:8083"` |

Homepage has no bind-address option and listens on all interfaces. Direct access to
port 8083 stays blocked; Tailscale Serve terminates HTTPS on `:443` and proxies to
`127.0.0.1:8083`.

Branding: title **Homeport**, cool slate palette with a geometric grid (no warm
amber/night-light cast). Dark-by-default with a soft cool-gray light mode (theme
switcher kept). The balanced single-row top bar is optimized for fullscreen
2560×1440 and shows host load/RAM/uptime, live primary-Ethernet throughput, and
both NVIDIA GPUs (util, VRAM, temp) via `gpu-stats` on `127.0.0.1:8091`. Other
widgets: datetime, Open-Meteo (Chicago coords — adjust if needed), and
CPU/RAM/disk/uptime.
Every service tile uses `siteMonitor` for live HTTP latency (ms); Piper monitors
`/health`.

---

### Uptime Kuma

**Module:** `modules/services/uptime-kuma.nix` (+ `uptime-kuma-sync.py`)  
**URL:** http://nixos.taile9f484.ts.net:3001

| Option | Value |
|--------|-------|
| `services.uptime-kuma.enable` | `true` |
| `settings.HOST` | `"0.0.0.0"` |
| `settings.PORT` | `"3001"` |
| Firewall | `tailscale0` TCP `3001` |

#### Declarative sync (`uptime-kuma-sync.service`)

| Setting | Value |
|---------|-------|
| Type | oneshot (`RemainAfterExit`) |
| After | `uptime-kuma.service`, `ntfy-sh.service` |
| Env | `age.secrets.uptime-kuma-sync` → `secrets/uptime-kuma-sync.env.age` |
| Env keys | `KUMA_USERNAME`, `KUMA_PASSWORD`, `NTFY_TOPIC` |
| Tooling | `python3Packages.uptime-kuma-api` |
| Tag | `nix-managed` (stale tagged monitors deleted; manual UI monitors left alone) |
| Notifications | ntfy provider `ntfy-homeport` → `http://127.0.0.1:8090/<topic>` |

Monitors (interval 60s, maxretries 3): localhost HTTP for Homepage, llama.cpp, whisper.cpp, Piper, SearXNG, n8n, Portainer (ignore TLS), GPU stats, ntfy, Kuma; Tailscale/Serve HTTP for Homepage, n8n, Portainer, ntfy, Kuma; TCP for PostgreSQL `:5432` and OpenSSH `:22`. Docker covered via Portainer. Groups match Homepage sections. Admin user must exist in the Kuma UI before sync can login.

---

### Tailscale

**Module:** `modules/services/tailscale.nix`

#### agenix

| Secret | File | mode |
|--------|------|------|
| `tailscale-auth-key` | `secrets/tailscale-auth-key.age` | `0400` |

#### `services.tailscale`

| Option | Value |
|--------|-------|
| `enable` | `true` |
| `authKeyFile` | `config.age.secrets.tailscale-auth-key.path` |
| `openFirewall` | `false` |

---

### Printing (CUPS)

**Module:** `modules/services/printing.nix`

| Option | Value |
|--------|-------|
| `services.printing.enable` | `true` |

---

### Honcho (disabled)

**Module:** `modules/services/honcho.nix`  
**Import:** commented out in `hosts/nixos/configuration.nix`

Placeholder only — no active options. Commented examples mention:

- OCI container on `127.0.0.1:8000` with `honcho-server-env` agenix secret
- Or docker-compose systemd unit under `/var/lib/honcho/compose`

---

## Core / networking services

### OpenSSH

**Module:** `modules/core/openssh.nix`

| Option | Value |
|--------|-------|
| `services.openssh.enable` | `true` |
| `services.openssh.openFirewall` | `false` |
| `networking.firewall.interfaces.tailscale0.allowedTCPPorts` | `[ 22 ]` |

SSH is reachable on the Tailscale interface only, not LAN/WAN.
Homepage is also tailnet-reachable via Tailscale Serve on `:443`;
Homepage's own port 8083 remains closed in the firewall.

---

### NetworkManager

**Module:** `modules/core/networkmanager.nix`

| Option | Value |
|--------|-------|
| `networking.networkmanager.enable` | `true` |

---

### Hostname

**Module:** `modules/core/hostname.nix`

| Option | Value |
|--------|-------|
| `networking.hostName` | `"nixos"` |

---

## Desktop / audio / display

### PipeWire + PulseAudio + rtkit

**Module:** `modules/desktop/audio.nix`

| Option | Value |
|--------|-------|
| `services.pulseaudio.enable` | `false` |
| `security.rtkit.enable` | `true` |
| `services.pipewire.enable` | `true` |
| `services.pipewire.alsa.enable` | `true` |
| `services.pipewire.alsa.support32Bit` | `true` |
| `services.pipewire.pulse.enable` | `true` |

---

### GDM

**Module:** `modules/desktop/gdm.nix`

| Option | Value |
|--------|-------|
| `services.displayManager.gdm.enable` | `true` |

---

### GNOME + X server

**Module:** `modules/desktop/gnome.nix`

| Option | Value |
|--------|-------|
| `services.xserver.enable` | `true` |
| `services.xserver.xkb.layout` | `"us"` |
| `services.xserver.xkb.variant` | `""` |
| `services.desktopManager.gnome.enable` | `true` |
| `programs.dconf.enable` | `true` |

GNOME extension packages and excludes: see [GNOME desktop packages & excludes](#gnome-desktop-packages--excludes).

---

### NVIDIA (via X videoDrivers)

**Module:** `modules/hardware/nvidia.nix`

| Option | Value |
|--------|-------|
| `services.xserver.videoDrivers` | `[ "nvidia" ]` |
| `hardware.nvidia.open` | `false` |
| `hardware.nvidia.modesetting.enable` | `true` |
| `hardware.nvidia.powerManagement.enable` | `false` |
| `hardware.nvidia.package` | `config.boot.kernelPackages.nvidiaPackages.stable` |

#### Graphics (`modules/hardware/graphics.nix`)

| Option | Value |
|--------|-------|
| `hardware.graphics.enable` | `true` |
| `hardware.graphics.enable32Bit` | `true` |

---

## Security / secrets infrastructure

### Polkit (pkexec)

**Module:** `modules/core/polkit-pkexec.nix`

| Option | Value |
|--------|-------|
| `security.polkit.extraConfig` | Passwordless `org.freedesktop.policykit.exec` for user `rileyt` |

### agenix

**Module:** `modules/core/agenix.nix`

| Option | Value |
|--------|-------|
| `age.identityPaths` | `[ "/etc/ssh/ssh_host_ed25519_key" "/home/rileyt/.ssh/id_ed25519" ]` |

Service-owned secrets are declared in their own modules (SearXNG, Tailscale).

---

## Programs — system (`modules/programs/`, desktop)

### Steam

**Module:** `modules/programs/steam.nix`

| Option | Value |
|--------|-------|
| `programs.steam.enable` | `true` |
| `programs.steam.remotePlay.openFirewall` | `false` |

### Steam / games directories

**Module:** `modules/programs/games-dirs.nix`

| `systemd.tmpfiles.rules` | Mode / owner |
|--------------------------|--------------|
| `d /games` | `0755 root root` |
| `d /games/steam-library` | `0755 rileyt users` |

### Firefox

**Module:** `modules/programs/firefox.nix`

| Option | Value |
|--------|-------|
| `programs.firefox.enable` | `true` |

### System CLI packages

**Module:** `modules/programs/packages.nix`

| `environment.systemPackages` |
|------------------------------|
| `wget` |
| `git` |
| `curl` |
| `gh` |

### GNOME desktop packages & excludes

**Module:** `modules/desktop/gnome-extensions.nix`

| `environment.systemPackages` |
|------------------------------|
| `gnome-tweaks` |
| `gnome-extension-manager` |
| `gnomeExtensions.dash-to-dock` |
| `gnomeExtensions.blur-my-shell` |
| `gnomeExtensions.vitals` |
| `gnomeExtensions.gsconnect` |
| `gnomeExtensions.just-perfection` |
| `gnomeExtensions.user-themes` |
| `gnomeExtensions.caffeine` |

| `environment.gnome.excludePackages` |
|-------------------------------------|
| `gnome-maps` |
| `gnome-contacts` |
| `gnome-weather` |
| `gnome-cloud` |

### dconf (system)

**Module:** `modules/desktop/gnome.nix`

| Option | Value |
|--------|-------|
| `programs.dconf.enable` | `true` |

Packages also pulled in by services (not under `modules/programs/`):

| Service module | Packages |
|----------------|----------|
| `llama-cpp.nix` | CUDA `llama-cpp` (`pkgsUnstable`) |
| `whisper-cpp.nix` | `whisper-cpp`, `ffmpeg` |
| `piper.nix` | `piper-tts` |

---

## Programs — Home Manager (`home/`)

Imported via `home.nix`. User: `rileyt` (`home/core/identity.nix`).

### Home Manager itself

**Module:** `home/core/home-manager.nix`

| Option | Value |
|--------|-------|
| `programs.home-manager.enable` | `true` |

**Module:** `home/core/state-version.nix`

| Option | Value |
|--------|-------|
| `home.stateVersion` | `"26.05"` |

**Module:** `home/core/identity.nix`

| Option | Value |
|--------|-------|
| `home.username` | `"rileyt"` |
| `home.homeDirectory` | `"/home/rileyt"` |

### User CLI utilities

**Module:** `home/programs/utilities.nix`

| `home.packages` |
|-----------------|
| `htop` |
| `ripgrep` |
| `fd` |
| `unzip` |

### Google Chrome

**Module:** `home/programs/google-chrome.nix`

| Option | Value |
|--------|-------|
| `home.packages` | `[ pkgs.google-chrome ]` |

### Spotify

**Module:** `home/programs/spotify.nix`

| Option | Value |
|--------|-------|
| `home.packages` | `[ pkgs.spotify ]` |

### Discord

**Module:** `home/programs/discord.nix`

| Option | Value |
|--------|-------|
| `home.packages` | `[ pkgs.discord ]` |

### Cursor (IDE + CLI)

**Module:** `home/programs/cursor.nix`

| `home.packages` |
|-----------------|
| `cursor-cli` |
| `code-cursor` |

### Claude Code

**Module:** `home/programs/claude-code.nix`

| Option | Value |
|--------|-------|
| `home.packages` | `[ pkgsUnstable.claude-code ]` |

### Pointer cursor theme

**Module:** `home/desktop/cursor.nix`

| Option | Value |
|--------|-------|
| `home.pointerCursor.gtk.enable` | `true` |
| `home.pointerCursor.x11.enable` | `true` |
| `home.pointerCursor.package` | `pkgs.bibata-cursors` |
| `home.pointerCursor.name` | `"Bibata-Modern-Ice"` |
| `home.pointerCursor.size` | `24` |

### GNOME interface (dconf)

**Module:** `home/desktop/gnome/interface.nix`

| `dconf.settings."org/gnome/desktop/interface"` | Value |
|-----------------------------------------------|-------|
| `color-scheme` | `"prefer-dark"` |
| `clock-show-weekday` | `true` |
| `cursor-theme` | `"Bibata-Modern-Ice"` |
| `cursor-size` | `24` |
| `show-battery-percentage` | `true` |

### GNOME shell extensions enabled (dconf)

**Module:** `home/desktop/gnome/extensions.nix`

`dconf.settings."org/gnome/shell".enabled-extensions` = UUIDs from these packages:

| Extension package |
|-------------------|
| `gnomeExtensions.dash-to-dock` |
| `gnomeExtensions.blur-my-shell` |
| `gnomeExtensions.vitals` |
| `gnomeExtensions.gsconnect` |
| `gnomeExtensions.just-perfection` |
| `gnomeExtensions.user-themes` |
| `gnomeExtensions.caffeine` |

### Dash to Dock (dconf)

**Module:** `home/desktop/gnome/dash-to-dock.nix`

| `dconf.settings."org/gnome/shell/extensions/dash-to-dock"` | Value |
|-----------------------------------------------------------|-------|
| `dock-position` | `"BOTTOM"` |
| `extend-height` | `false` |
| `dock-fixed` | `true` |
| `dash-max-icon-size` | `48` |
| `click-action` | `"minimize-or-previews"` |
| `show-trash` | `false` |
| `show-mounts` | `false` |

---

## Boot / Nix (supporting, not app services)

| Module | Settings |
|--------|----------|
| `modules/core/boot.nix` | `boot.loader.systemd-boot.enable = true`; `boot.loader.efi.canTouchEfiVariables = true` |
| `modules/core/nix.nix` | `nix.settings.experimental-features = [ "nix-command" "flakes" ]` |
| `modules/core/nixpkgs.nix` | `nixpkgs.config.allowUnfree = true` |
| `modules/core/state-version.nix` | `system.stateVersion = "26.05"` |
| `modules/core/locale.nix` | `time.timeZone = "America/Chicago"`; `i18n.defaultLocale` / `extraLocaleSettings` = `en_US.UTF-8` |
| `modules/users/rileyt.nix` | user `rileyt`, groups `networkmanager` `wheel` |

---

## Port map (localhost unless noted)

| Port | Service |
|------|---------|
| 22 | OpenSSH (`tailscale0` only) |
| 443 | Tailscale Serve → Homepage (tailnet HTTPS) |
| 3001 | Uptime Kuma (`tailscale0` only) |
| 5432 | PostgreSQL (localhost) |
| 5678 | n8n localhost + Tailscale Serve HTTPS |
| 8080 | llama.cpp |
| 8081 | whisper.cpp |
| 8082 | Piper TTS |
| 8083 | Homepage (direct firewall closed; Serve upstream) |
| 8090 | ntfy (`tailscale0` only) |
| 8091 | GPU stats JSON API (localhost) |
| 8888 | SearXNG |
| 9443 | Portainer localhost + Tailscale Serve HTTPS |

Agent quick-refs: `.cursor/skills/edit-nixos/reference/services.md`, `reference/home-manager.md`.
