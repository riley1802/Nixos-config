# NixOS config

Change this computer only with `nixctl` (run `nixctl help`). Start with `nixctl map`.
Use the nixos-managing skill. Every nixctl output ends with RESULT: and usually NEXT: lines; do what NEXT says.
Never run nixos-rebuild or sudo yourself. If a task needs root, use `pkexec`.

These rules come from the chats on this machine (2026-06-29 through 2026-11-03). `lessons.md` is the matching list of what went wrong and what fixed it. When a rule here and a chat disagree, the newer chat wins. When Riley says something in the moment, that wins over both.

## Before editing

1. Run `nixctl map` and read the module that owns the thing being changed. One feature lives in one file. The arr stack, including qBittorrent, lives under `modules/services/arr/`. Jellyfin is its own module.
2. Run `nixctl option NAME` before writing an option. A guessed name that does not exist fails the build.
3. New files are invisible to the flake until they are tracked. `nixctl` stages them. A hand-run `nix flake check` or `nix build` on an untracked file fails as if the file were missing.
4. Edit only `modules/` and `hosts/`. Leave `hardware-configuration.nix`, `system.stateVersion`, `secrets/`, `flake.lock`, `flake.nix`, and `tools/` alone.
5. Ask before a destructive step: wiping home, deleting `/var/lib/<service>`, garbage-collecting generations, rolling back, or removing a service that holds data. Push only when Riley asks.
6. After a meaningful change, update the matching docs in the same step: `README.md`, module comments, this file, and `lessons.md` when something broke and got fixed.

## Commands that have failed here

- `pkexec` is how root work runs. `sudo` from an agent shell has no TTY. `pkexec` also drops `PATH`, so a command that needs `jq`, `wg`, or `bash` is `pkexec env "PATH=$PATH" …`, or a script under `/run/current-system/sw/bin`.
- `nixctl apply` is the rebuild. The one-time exception is the bootstrap, before nixctl exists: `pkexec nixos-rebuild switch --flake /etc/nixos`. A relative flake path (`.#nixos`) fails because pkexec starts in the wrong directory.
- Bare `nix fmt` with no path has hung this repo for many minutes. Format with `nix fmt .` or an explicit path. `nix fmt` can also break a Nix `''` string that contains another `''`. Check again after formatting.
- `nixctl apply` builds, tests, and keeps the generation only if no new unit is broken. Read the last lines. `RESULT: FAIL` means stop and follow `NEXT:`.
- A `switch` that errors while reloading the live NTFS game drive is not a failed generation. ntfs-3g cannot remount a volume that is already mounted.
- The graphical session can block `reboot` with a logind inhibitor. The menu reboot works. From a shell, `pkexec systemctl reboot -i`.
- The agent shell often has no `python3` or `jq` on `PATH`. Use `/run/current-system/sw/bin` or a store path.
- `uv` is installed system-wide and is the default for Python projects and tools. Use `uv init`, `uv add`, `uv sync`, `uv run`, and `uv tool` instead of direct `pip`; Nix still owns system-level Python packages and services.

## This computer

- Host `nixos`, user `rileyt`, timezone `America/Chicago`. The laptop on the tailnet is `rileys-minty`, account `riley`. `ssh laptop` is that account, not `rileyt`.
- Desktop is KDE Plasma 6 on Wayland with SDDM. KWin is pinned to the RTX 3050 with `KWIN_DRM_DEVICES=/run/display-gpu`, a symlink to `/dev/dri/by-path/pci-0000:02:00.0-card`. The by-path node itself must not be that variable: KWin splits it on `:`. Plasma (X11) is in the SDDM menu. Cinnamon remains in `modules/desktop/cinnamon.nix` and is off; do not enable it while Plasma is on, because each one starts its own display manager. GNOME was the first desktop. There is no Pi host in this repo.
- Two NVIDIA cards, 6 GB each. The RTX 3050 drives the displays. The GTX 1660 SUPER is the second card. A model that needs both cards cannot run next to another model. The 3050 also compositing the desktop is why a big context OOMs even when the weights look small.
- Monitors are dual 2560×1440 and can sit at 60 Hz while the panel is 144 Hz. Pointer stutter has also been a USB receiver dongle, and a burst stall when Jellyfin transcode plus the USB game drive saturated the bus. Check the dongle, refresh rates, and disk stalls before changing the compositor.
- Chrome's secure DNS stays off. With it on, Chrome asks Cloudflare and cannot resolve `nixos.taile9f484.ts.net`. MagicDNS names for `taile9f484.ts.net` go through dnsproxy to `100.100.100.100`. Tailscale's own DNS client stays off so it does not replace that forwarder.
- `*.ts.net` in Chrome is HTTPS-only. `http://nixos.taile9f484.ts.net:PORT` times out. Tailscale Serve terminates TLS. The app itself listens on `127.0.0.1`.

## How a service is published

- Bind the app to loopback. Open the port on `tailscale0` only. Add the route in the single Tailscale Serve unit. A second unit that also writes Serve config races the first and drops routes at boot.
- `openFirewall = true` opens the home LAN. That is a separate decision. SSH is tailnet-only.
- Docker publishes on `127.0.0.1` by default. Docker's iptables rules skip the NixOS firewall, so a container published on `0.0.0.0` is on the LAN even when the firewall looks closed.
- Tiles and accounts for Homarr, n8n, Uptime Kuma, and Immich live under `/var/lib/…`. Nix does not own those databases. Edit them with the app's own UI or its database, with the service stopped when the file is sqlite.
- After an agenix edit, the running service still has the old `/run/agenix` file until `nixctl apply`. A restart alone does not re-decrypt.
- Edit secrets with `agenix` from `/etc/nixos` and `AGENIX_RULES=secrets/secrets.nix`. A non-interactive `EDITOR=cp` can encrypt an empty file. Encrypted `.age` files are tracked. `secrets/result` is a build symlink and stays untracked. Never print plaintext, tokens, or password hashes.

## Disks

- `/vault` is the ext4 disk labeled vault. Its mount parent stays `root:root`. systemd tmpfiles refuse to create directories there otherwise ("unsafe path transition"). `/vault/media` is a bindfs view of the game drive, group `media`, mode `0770`. `mirror-only=@media` left the group as `users` and Sonarr and Lidarr could not see the download folders.
- "0 B free" on `/vault` has meant the filesystem was full, with the last free blocks inside ext4's reserved space, which non-root services cannot use. Check `df` and reserved blocks before treating it as an unmounted disk.
- Sonarr and Radarr hardlink imports. A download and a library file can be one inode. Adding the two directory sizes double-counts.
- The 4 TB game drive is NTFS at `/mnt/game-drive`, mounted with ntfs-3g so the existing "old stuff" directory stays rileyt-only. Apps keep using `/vault/media/…`, which is a view onto the game drive. The unit name for that mount is escaped: `mnt-game\x2ddrive.mount`.
- Immich photos stay on `/vault/immich` (ext4). Dropping files into the upload directory does not show them. An external library is a scan of a directory the `immich` user can read. Copying onto NTFS and chmodding it does not do that.
- ntfs-3g shows one mode for the whole volume. chmod on it is a no-op.

## llama.cpp

- The package is the CUDA build in `packages/llama-cpp.nix` (v0.8.0). The 26.05 llama.cpp cannot load LFM3. The stock module's sandbox also blocks CUDA (`MemoryDenyWriteExecute`, `PrivateUsers`).
- Two servers: LFM3-Omni-2B on the 3050 at `127.0.0.1:8081` (model id `lfm3-omni`), 1.7B on CPU at `127.0.0.1:8082`. Omni replaced VL on that port so voice input works. VL weights stay on disk and are not loaded. Both servers need the API key in `secrets/llama-api-key.age`. Health on loopback stays open. Everything else needs the bearer token. Omni is non-reasoning: the server uses `--reasoning off` and `--temp 0`.
- Nemotron 3.5 Bolt E4B is `modules/services/nemotron.nix`. The host line `my.hardware.gtx1660` is `breeze-tts` or `nemotron`. That process boots and is the one Tailscale, Open WebUI, and Homarr publish. The other unit stays installed and stopped. `gtx1660 nemotron` or `gtx1660 breeze` flips the running process without a rebuild; the tailnet follows the host line after `nixctl apply`. When Nemotron is the one running it is `127.0.0.1:8083`, model id `nemotron-bolt`, Q4_K_M, q8_0 KV, context 32768, `--fit on --fit-ctx 32768` (the 5.76 GiB file does not fit on the 6 GB card with the cache, so fit keeps the window and moves layers to the CPU), `--spec-type draft-mtp` with `mtp-gemma-4-E4B-it-Q8_0.gguf` and `--spec-draft-n-max 1`, pinned to the 1660 SUPER `GPU-f2ae9716-6783-f900-4fed-c05b9cb3a6aa`. On 2026-11-04 that draft length was 74.7 tok/s against 57.4 with no draft on a short prompt. Filled windows with MTP: 16k context 186.7 tok/s prefill and 55.9 tok/s generation; 32k context 157.0 and 42.8.
- Breeze TTS 2 Q8 (`breeze-tts-2-q8_0.gguf`, HoppouAI/Breeze-TTS-2.cpp v0.1.6) is `modules/services/breeze-tts.nix` on the 1660 SUPER. HTTP and the web UI are `127.0.0.1:8084`. The WebSocket is `127.0.0.1:8085`. Tailscale Serve publishes both on `tailscale0` only: `https://nixos.taile9f484.ts.net:8084/` and `:8085`. No API key; the tailnet is the access boundary. `GET /health`. `POST /v1/audio/speech` (form fields return raw 24 kHz s16le PCM; OpenAI-style JSON with `response_format` `wav` returns WAV). Vulkan device 1, `GGML_VK_VISIBLE_DEVICES=1`, NVIDIA ICD only. The first start downloads the GGUF into `/var/lib/breeze-tts/models` with curl, not the Hugging Face XET client. Saved voices are `/var/lib/breeze-tts/voices`. n8n Discord replies use Breeze `http://127.0.0.1:8084/v1/audio/speech` (JSON, `response_format` wav) only while the 1660 is running Breeze (`gtx1660 breeze`). The host line is what boots and what Tailscale publishes. Omni still hears the memo and writes the answer.
- Kokoro-82M (`hexgrad/Kokoro-82M`, nixpkgs `python3Packages.kokoro`, CPU torch) is `modules/services/kokoro.nix`. It is separate from Breeze and stays up at boot. Loopback `127.0.0.1:8087`, Tailscale Serve `https://nixos.taile9f484.ts.net:8087`, no API key. `GET /health`. `POST /v1/audio/speech` is JSON (`input`, `voice` default `af_heart`, `response_format` `wav`) and returns 24 kHz mono WAV. A voice whose name starts with `b` uses British English; every other accepted name uses American English. One synthesis at a time. 16 threads (`OMP_NUM_THREADS` and `torch.set_num_threads`). Weights live in `/var/lib/kokoro/huggingface` with `HF_HUB_DISABLE_XET=1`. On 2026-11-04, voice `af_heart`, one warmup discarded, median of three runs: 16 CPU threads, 46-character sentence 0.453 s wall, 3.275 s audio, real-time factor 7.22; 1016-character passage 9.667 s wall, 59.7 s audio, first audio at 4.424 s, real-time factor 6.18, RSS about 2001 MiB. The RTX 3050 (PyTorch 2.11.0+cu128, desktop still on the card, Omni stopped) did those clips in 0.136 s (RTF 24.1) and 1.990 s (first audio 0.876 s, RTF 30.0), peak allocation 1027 MiB, reserved 1160 MiB. It does not fit beside Omni (about 3.6 GiB) plus the desktop (about 0.9 GiB) on the 6 GiB card, so the service stays on the CPU. `python3Packages.torch-bin` is the CUDA wheel, but building it compiles NCCL from source for every architecture and pegs the machine. Do not start that build for a timing run.
- `--parallel` above 1 splits the context across slots, so a configured 64k is not 64k per request. Pin `--parallel 1` when measuring context.
- A context that fits the weight file can still CUDA-OOM once the KV cache and the desktop are on the same 6 GB card. Raise context in small steps and watch memory.
- Hugging Face XET downloads have stalled as `.incomplete` files on this machine, so the server then fails to load the model. Set `HF_HUB_DISABLE_XET=1` for those downloads.
- n8n does not read the age file. Its OpenAI credential is a manual URL (`http://127.0.0.1:8082/v1`), model id `lfm3-1.7b`, and the real key from `/run/agenix/llama-api-key`. A dummy key is rejected. Leave "Use Responses API" off.

## Media stack and PIA

- qBittorrent is the torrent client. PIA WireGuard (`pia` interface, table 51820) is the torrent path. Tailscale is the remote-UI path. They are different.
- `RestrictNetworkInterfaces` records the interface index when the process starts. If Prowlarr or qBittorrent starts before `pia` exists, the allow-list ignores `pia` and traffic dies. Order them after the tunnel, and restart them when the tunnel recreates the interface.
- Marked Prowlarr packets need MASQUERADE out `pia`. Without it they leave with the LAN address and time out. An IPv6 REJECT on that cgroup has hung .NET indexers.
- The NixOS qBittorrent module rewrites its config on every start. A password set only in the UI is gone on the next start. Persist it through the module's restore hook, and set it with the API.
- A slow download with a fast tunnel has been a queue limit (one stalled torrent holding the slot), not the VPN.
- Lidarr's in-app updater must stay `external`. The package is a pinned tarball in the store. An in-app update cannot replace it and should not be allowed to try.

## Services worth remembering

- Homelable is the network diagram at `127.0.0.1:3000`. Tailscale Serve publishes `https://nixos.taile9f484.ts.net:3000`. Login: `pkexec cat /run/agenix/homelable-login`. The canvas is `/var/lib/homelable`. The scanner covers `192.168.50.0/24` from the `br-homelable` bridge and does not see MAC addresses. MCP is `127.0.0.1:8001` only; its key is in `/run/agenix/homelable-env`.
- Homepage was removed. Homarr on port 7575 is the board. Its tiles are in `/var/lib/homarr`, not in the Nix file. A ping URL there has to be `http://host.docker.internal:PORT`. That name is `172.30.88.1`, not Docker's `host-gateway` (`172.17.0.1`). Loopback apps are proxied on that gateway. The click URL stays `http://127.0.0.1:PORT`.
- Netdata was removed. `modules/network/tailscale.nix` still turns off a leftover Serve route on port 19999. PIA's port-forward API also dials outbound HTTPS on 19999. That is not a local listener.
- ntfy's `base-url` cannot contain a path. n8n 2.x serves its assets at `/`, so an `N8N_PATH` or an nginx `/n8n/` prefix returns HTML where the browser expects JavaScript.
- An oci-container `extraOptions` of `--restart=…` conflicts with Nix's `--rm`. systemd restarts the container.
- Uptime Kuma monitors live in its sqlite database, not only in the Nix module.
- OpenLogi is installed for the MX Master 4. It was not the cause of the November pointer stutter.

## Removed on purpose

Do not bring these back unless Riley asks in this chat: GitLab, the Rust game server, Hermes, Ghostty, Goose, the Tauri Homeport app, Homepage, Netdata, Liquid d1-2B (`llama-cpp-d1`, port 8086), World Monitor, the Raspberry Pi host, and the Pi OS / USB-bootstrap scripts. Building an aarch64 Pi image on this desktop runs under qemu and pegs every core for hours. The Pi GNOME session also boot-looped on a Pi 4.

## When something breaks

1. `nixctl status`, then `nixctl logs UNIT`.
2. If it broke on the generation just applied, `nixctl rollback`.
3. The same step failing three times means stop. Report the last `ERROR:` line.
4. Add a `lessons.md` entry: what went wrong, and what resolved it.
