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
- Cinnamon can block `reboot` with a logind inhibitor. The menu reboot works. From a shell, `pkexec systemctl reboot -i`.
- The agent shell often has no `python3` or `jq` on `PATH`. Use `/run/current-system/sw/bin` or a store path.

## This computer

- Host `nixos`, user `rileyt`, timezone `America/Chicago`. The laptop on the tailnet is `rileys-minty`, account `riley`. `ssh laptop` is that account, not `rileyt`.
- Desktop is Cinnamon on X11 with LightDM. GNOME was the first desktop and was replaced. There is no Pi host in this repo.
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

- `/vault` is the ext4 disk labeled vault. Its mount parent stays `root:root`. systemd tmpfiles refuse to create directories there otherwise ("unsafe path transition"). Media directories are `2775` and group `media`, with the setgid bit, so new files stay in the group.
- "0 B free" on `/vault` has meant the filesystem was full, with the last free blocks inside ext4's reserved space, which non-root services cannot use. Check `df` and reserved blocks before treating it as an unmounted disk.
- Sonarr and Radarr hardlink imports. A download and a library file can be one inode. Adding the two directory sizes double-counts.
- The 4 TB game drive is NTFS at `/mnt/game-drive`, mounted with ntfs-3g so the existing "old stuff" directory stays rileyt-only. Apps keep using `/vault/media/…`, which is a view onto the game drive. The unit name for that mount is escaped: `mnt-game\x2ddrive.mount`.
- Immich photos stay on `/vault/immich` (ext4). Dropping files into the upload directory does not show them. An external library is a scan of a directory the `immich` user can read. Copying onto NTFS and chmodding it does not do that.
- ntfs-3g shows one mode for the whole volume. chmod on it is a no-op.

## llama.cpp

- The package is the CUDA build in `packages/llama-cpp.nix` (v0.8.0). The 26.05 llama.cpp cannot load LFM3. The stock module's sandbox also blocks CUDA (`MemoryDenyWriteExecute`, `PrivateUsers`).
- Two servers: LFM3-Omni-2B on the 3050 at `127.0.0.1:8081` (model id `lfm3-omni`), 1.7B on CPU at `127.0.0.1:8082`. Omni replaced VL on that port so voice input works. VL weights stay on disk and are not loaded. Both servers need the API key in `secrets/llama-api-key.age`. Health on loopback stays open. Everything else needs the bearer token. Omni is non-reasoning: the server uses `--reasoning off` and `--temp 0`.
- Nemotron 3.5 Bolt E4B is `modules/services/nemotron.nix` and stays off until `nixctl enable services/nemotron`. When on, it is `127.0.0.1:8083`, model id `nemotron-bolt`, Q4_K_M, q8_0 KV, context 8192, `--fit on` (the 5.76 GiB file does not fit on the 6 GB card with the cache), pinned to the 1660 SUPER `GPU-f2ae9716-6783-f900-4fed-c05b9cb3a6aa`. Do not run Nemotron and Chatterbox on the 1660 at the same time.
- Chatterbox Turbo (`ResembleAI/chatterbox-turbo`) is `modules/services/chatterbox.nix` on the 1660 SUPER at `127.0.0.1:8084`. Loopback only; no Tailscale Serve route. `GET /health`. `POST /tts` with JSON `{"text":"..."}` returns 24 kHz WAV (optional `audio_prompt_path`; default is `/var/lib/chatterbox/ref.wav`, Resemble's male radio-host clip). Weights and a pip venv live under `/var/lib/chatterbox`. Set `HF_HUB_DISABLE_XET=1` when fetching weights.
- `--parallel` above 1 splits the context across slots, so a configured 64k is not 64k per request. Pin `--parallel 1` when measuring context.
- A context that fits the weight file can still CUDA-OOM once the KV cache and the desktop are on the same 6 GB card. Raise context in small steps and watch memory.
- Hugging Face XET downloads have stalled as `.incomplete` files on this machine, so the server then fails to load the model. Set `HF_HUB_DISABLE_XET=1` for those downloads.
- n8n does not read the age file. Its OpenAI credential is a manual URL (`http://127.0.0.1:8082/v1`), a model name, and a dummy key stored in n8n's own database.

## Media stack and PIA

- qBittorrent is the torrent client. PIA WireGuard (`pia` interface, table 51820) is the torrent path. Tailscale is the remote-UI path. They are different.
- `RestrictNetworkInterfaces` records the interface index when the process starts. If Prowlarr or qBittorrent starts before `pia` exists, the allow-list ignores `pia` and traffic dies. Order them after the tunnel, and restart them when the tunnel recreates the interface.
- Marked Prowlarr packets need MASQUERADE out `pia`. Without it they leave with the LAN address and time out. An IPv6 REJECT on that cgroup has hung .NET indexers.
- The NixOS qBittorrent module rewrites its config on every start. A password set only in the UI is gone on the next start. Persist it through the module's restore hook, and set it with the API.
- A slow download with a fast tunnel has been a queue limit (one stalled torrent holding the slot), not the VPN.
- Lidarr's in-app updater must stay `external`. The package is a pinned tarball in the store. An in-app update cannot replace it and should not be allowed to try.

## Services worth remembering

- Homepage was removed. Homarr on port 7575 is the board. Its tiles are in `/var/lib/homarr`, not in the Nix file. A ping URL there has to be `http://host.docker.internal:PORT`. That name is `172.30.88.1`, not Docker's `host-gateway` (`172.17.0.1`). Loopback apps are proxied on that gateway. The click URL stays `http://127.0.0.1:PORT`.
- Netdata's default package has no dashboard files, so `/` returns "File does not exist". This machine uses `netdataCloud` and the charts are under `/v3`.
- ntfy's `base-url` cannot contain a path. n8n 2.x serves its assets at `/`, so an `N8N_PATH` or an nginx `/n8n/` prefix returns HTML where the browser expects JavaScript.
- An oci-container `extraOptions` of `--restart=…` conflicts with Nix's `--rm`. systemd restarts the container.
- Uptime Kuma monitors live in its sqlite database, not only in the Nix module.
- OpenLogi is installed for the MX Master 4. It was not the cause of the November pointer stutter.

## Removed on purpose

Do not bring these back unless Riley asks in this chat: GitLab, the Rust game server, Hermes, Ghostty, Goose, the Tauri Homeport app, Homepage, World Monitor, the Raspberry Pi host, and the Pi OS / USB-bootstrap scripts. Building an aarch64 Pi image on this desktop runs under qemu and pegs every core for hours. The Pi GNOME session also boot-looped on a Pi 4.

## When something breaks

1. `nixctl status`, then `nixctl logs UNIT`.
2. If it broke on the generation just applied, `nixctl rollback`.
3. The same step failing three times means stop. Report the last `ERROR:` line.
4. Add a `lessons.md` entry: what went wrong, and what resolved it.
