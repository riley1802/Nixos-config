# NixOS config

Change this computer only with `nixctl` (run `nixctl help`). Start with `nixctl map`.
Use the nixos-managing skill. Every nixctl output ends with RESULT: and usually NEXT: lines; do what NEXT says.
Never run nixos-rebuild or sudo yourself. If a task needs root, use `pkexec`.

These rules come from the chats on this machine (2026-06-29 through 2026-11-03). The service list in this file was checked against the running modules on 2026-11-10. `lessons.md` is the matching list of what went wrong and what fixed it. When a rule here and a chat disagree, the newer chat wins. When Riley says something in the moment, that wins over both.

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
- Two NVIDIA cards, 6 GB each. The RTX 3050 drives the displays. The GTX 1660 SUPER is the second card.
- Monitors are dual 2560×1440 and can sit at 60 Hz while the panel is 144 Hz. Pointer stutter has also been a USB receiver dongle, and a burst stall when Jellyfin transcode plus the USB game drive saturated the bus. Check the dongle, refresh rates, and disk stalls before changing the compositor.
- Chrome's secure DNS stays off. With it on, Chrome asks Cloudflare and cannot resolve `nixos.taile9f484.ts.net`. MagicDNS names for `taile9f484.ts.net` go through dnsproxy to `100.100.100.100`. Tailscale's own DNS client stays off so it does not replace that forwarder.
- `*.ts.net` in Chrome is HTTPS-only. `http://nixos.taile9f484.ts.net:PORT` times out. Tailscale Serve terminates TLS. The app itself listens on `127.0.0.1`.

## How a service is published

- Bind the app to loopback. Open the port on `tailscale0` only. Add the route in the single Tailscale Serve unit. A second unit that also writes Serve config races the first and drops routes at boot.
- `openFirewall = true` opens the home LAN. That is a separate decision. SSH is tailnet-only.
- Docker publishes on `127.0.0.1` by default. Docker's iptables rules skip the NixOS firewall, so a container published on `0.0.0.0` is on the LAN even when the firewall looks closed.
- Accounts for Uptime Kuma and Immich live under `/var/lib/…`. Nix does not own those databases. Edit them with the app's own UI or its database, with the service stopped when the file is sqlite.
- After an agenix edit, the running service still has the old `/run/agenix` file until `nixctl apply`. A restart alone does not re-decrypt.
- Edit secrets with `agenix` from `/etc/nixos` and `AGENIX_RULES=secrets/secrets.nix`. A non-interactive `EDITOR=cp` can encrypt an empty file. Encrypted `.age` files are tracked. `secrets/result` is a build symlink and stays untracked. Never print plaintext, tokens, or password hashes.

## Disks

- `/vault` is the ext4 disk labeled vault. Its mount parent stays `root:root`. systemd tmpfiles refuse to create directories there otherwise ("unsafe path transition"). `/vault/media` is a bindfs view of the game drive, group `media`, mode `0770`. `mirror-only=@media` left the group as `users` and Sonarr and Lidarr could not see the download folders.
- "0 B free" on `/vault` has meant the filesystem was full, with the last free blocks inside ext4's reserved space, which non-root services cannot use. Check `df` and reserved blocks before treating it as an unmounted disk.
- Sonarr and Radarr hardlink imports. A download and a library file can be one inode. Adding the two directory sizes double-counts.
- The 4 TB game drive is NTFS at `/mnt/game-drive`, mounted with ntfs-3g so the existing "old stuff" directory stays rileyt-only. Apps keep using `/vault/media/…`, which is a view onto the game drive. The unit name for that mount is escaped: `mnt-game\x2ddrive.mount`.
- Immich photos stay on `/vault/immich` (ext4). Dropping files into the upload directory does not show them. An external library is a scan of a directory the `immich` user can read. Copying onto NTFS and chmodding it does not do that.
- ntfs-3g shows one mode for the whole volume. chmod on it is a no-op.

## Media stack and PIA

- qBittorrent is the torrent client. PIA WireGuard (`pia` interface, table 51820) is the torrent path. Tailscale is the remote-UI path. They are different.
- `RestrictNetworkInterfaces` records the interface index when the process starts. If Prowlarr or qBittorrent starts before `pia` exists, the allow-list ignores `pia` and traffic dies. Order them after the tunnel, and restart them when the tunnel recreates the interface.
- Marked Prowlarr packets need MASQUERADE out `pia`. Without it they leave with the LAN address and time out. An IPv6 REJECT on that cgroup has hung .NET indexers.
- The NixOS qBittorrent module rewrites its config on every start. A password set only in the UI is gone on the next start. Persist it through the module's restore hook, and set it with the API.
- A slow download with a fast tunnel has been a queue limit (one stalled torrent holding the slot), not the VPN.
- Lidarr's in-app updater must stay `external`. The package is a pinned tarball in the store. An in-app update cannot replace it and should not be allowed to try.

## Services worth remembering

- Netdata was removed. `modules/network/tailscale.nix` still turns off a leftover Serve route on port 19999. PIA's port-forward API also dials outbound HTTPS on 19999. That is not a local listener.
- ntfy's `base-url` cannot contain a path. A path prefix returns HTML where the client expects the API.
- An oci-container `extraOptions` of `--restart=…` conflicts with Nix's `--rm`. systemd restarts the container.
- Uptime Kuma monitors live in its sqlite database, not only in the Nix module.
- OpenLogi is installed for the MX Master 4. It was not the cause of the November pointer stutter.
- n8n is on. Editor is <http://127.0.0.1:5678>. Tailscale Serve is <https://nixos.taile9f484.ts.net:5678>. The editor base URL stays the loopback URL because Spotify OAuth rejects the tailnet host.
- Nemotron (`services/nemotron`) is the llama.cpp server on 127.0.0.1:8083, on the GTX 1660 SUPER. The RTX 3050 is the display. Do not bring back the old llama.cpp servers. Pi (`apps/pi`) is the coding agent on that server. Its config is `/etc/nixos/pi`, extensions are `pi/extensions/`, sessions stay in `~/.local/state/pi/sessions`, and pi-memory notes stay in `~/.local/state/pi/memory`. Do not start a second llama.cpp.
- nixctl-bridge listens on 127.0.0.1:8094 for the Discord operator. Do not publish it off loopback. Read-only nixctl runs immediately. A command saved earlier runs as saved. Anything else waits for Discord approval.
- RustDesk direct access is tailnet TCP 21118 only (`apps/rustdesk`).
- lidarr-drive is enabled. The 3:00 AM copy is not installed until `secrets/rclone-gdrive.age` exists. Do not invent that file.

## Removed on purpose

Do not bring these back unless Riley asks in this chat: GitLab, the Rust game server, Hermes, Ghostty, Goose, the Tauri Homeport app, Homepage, Netdata, Liquid d1-2B (`llama-cpp-d1`, port 8086), World Monitor, the Raspberry Pi host, and the Pi OS / USB-bootstrap scripts. Building an aarch64 Pi image on this desktop runs under qemu and pegs every core for hours. The Pi GNOME session also boot-looped on a Pi 4.

Also removed, with their modules: Breeze TTS, the research data platform, EmbeddingGemma, Homarr, Homelable, Kokoro, the old llama.cpp servers (ports 8081, 8082, 8084, 8085, 8087, and 8088), Open Terminal, SearXNG, and Open WebUI. Nemotron on 8083 (`services/nemotron`) is the current llama.cpp server and replaced that stack. Retired Serve ports are turned off by `modules/network/tailscale.nix`. Old files under `/var/lib` were left on disk. The age files `homarr-encryption-key`, `homelable-env`, `homelable-login`, and `searxng-env` are still in `secrets/` and are no longer wired to a service. `llama-api-key` is wired to `services/nemotron`.

## When something breaks

1. `nixctl status`, then `nixctl logs UNIT`.
2. If it broke on the generation just applied, `nixctl rollback`.
3. The same step failing three times means stop. Report the last `ERROR:` line.
4. Add a `lessons.md` entry: what went wrong, and what resolved it.
