# NixOS Desktop Configuration

This repository is the NixOS configuration for the `nixos` workstation. It
defines a KDE Plasma desktop, dual-NVIDIA graphics, OpenSSH over the tailnet,
ntfy, n8n, Immich, Uptime Kuma, and a torrent media stack.
qBittorrent and Prowlarr lookups use a Private Internet Access WireGuard tunnel. The
rest of the desktop stays on the home network.

## Repository layout

```
flake.nix                         inputs and one host
flake.lock                        exact input revisions
dev/flake.nix                     global dev shell, separate from the system flake
dev/flake.lock                    nixpkgs pin for that shell only
hosts/nixos/default.nix           hostname, shared settings, which modules are on
hosts/nixos/packages.nix          programs installed by name
hosts/nixos/hardware-configuration.nix
modules/core/                     nix, boot, system, settings, users, nixctl, overlays
modules/dev/shell.nix             interactive `nix dev` command
modules/hardware/                 NVIDIA driver, vault disk, game drive
modules/desktop/                  Plasma, Cinnamon (off), KDE Connect, Chrome DNS policy
modules/network/                  Tailscale, DNS, SSH, NetworkManager, PIA, firewall
modules/services/arr/             Sonarr, Radarr, Lidarr, Bazarr, Prowlarr, Seerr,
                                  qBittorrent, Cleanuparr, Jellyfin, lidarr-drive,
                                  and the shared media directories
modules/services/                 Immich, n8n, ntfy, Uptime Kuma, Docker, Nemotron,
                                  nixctl-bridge
modules/apps/                     openlogi.nix, rustdesk.nix, pi.nix
pi/                               Pi agent config (models, settings, skills)
packages/                         Lidarr build, llama-cpp
tools/nixctl.sh                   the nixctl command
AGENTS.md                         short nixctl loader for agents
nix-agent.md                      machine rules for agents
agent.md                          Cursor pointer to the agent docs
secrets/                          agenix recipients and encrypted files
pia/                              public PIA certificate and server list
```

`hosts/nixos/default.nix` is the control panel. Feature settings stay in the
module that owns them. `hosts/nixos/hardware-configuration.nix` is generated
by `nixos-generate-config` and should not be edited by hand.

- `flake.nix` pins NixOS to the `nixos-26.05` branch. Cursor, Radarr, Sonarr,
  Immich, and `rustdesk-flutter` come from `nixpkgs-unstable`. Cursor, Radarr,
  and Sonarr are there because 26.05 lags behind. Immich is 3.3.5 on that pin
  because 26.05 has 2.7.5, which is marked insecure, and phone apps need 3.x.
  The overlays live in `modules/core/overlays.nix`.
- `packages/lidarr.nix` is the official Lidarr 3.1.6.5079 release, because
  nixpkgs does not have it yet.
- `modules/services/uptime-kuma.nix` enables the stock NixOS module
  (`services.uptime-kuma`) with the nixpkgs package. Port 3001 is opened
  on `tailscale0` and Tailscale Serve exposes HTTPS on the tailnet, same
  pattern as Immich and ntfy.
- `modules/services/arr/cleanuparr.nix` builds the official Cleanuparr
  2.10.12 linux-amd64 release and runs it. nixpkgs does not have it.
- `modules/services/ntfy.nix` runs ntfy 2.26.0 from the nixos-26.05 module
  and publishes it with Tailscale Serve. The phone password and the
  publisher token are age secrets. `secrets/ntfy-auth.age` is what the
  server reads. `secrets/ntfy-passwords.age` is the copy for the phone app.
- `modules/services/immich.nix` runs Immich 3.3.5 from nixpkgs-unstable
  because 26.05 has 2.7.5. The nixos-26.05 `services.immich` module still
  provides PostgreSQL, Redis, pgvector, and VectorChord. Photos are stored
  in `/vault/immich`.
- Netdata was removed. `modules/network/tailscale.nix` still turns off a
  leftover Serve route on port 19999. PIA's port-forward API also uses
  outbound HTTPS to port 19999. That is not a local listener. The same
  unit turns off retired Serve ports: 3010 (Homepage), 19999 (Netdata),
  3000 (homelable), 7575 (homarr), 8081, 8082, 8084, 8085, 8087, and 8088.
  Port 8083 is Nemotron when `my.services.nemotron.enable` is true. Active
  Serve ports are 2283 Immich, 5678 n8n, 2586 ntfy, 3001 Uptime Kuma,
  8083 Nemotron, and 11011 Cleanuparr.
- Jellyfin, lidarr-drive, and the other arr apps live in
  `modules/services/arr/`.
- `modules/network/pia.nix` builds the split tunnel and routes Prowlarr
  lookups through it.
- `secrets/secrets.nix` lists the age recipients. `secrets/pia-credentials.age`
  is the encrypted PIA username and password. The decrypted file is
  `/run/agenix/pia-credentials` and is not in git. `secrets/ntfy-auth.age`
  and `secrets/ntfy-passwords.age` are the ntfy credentials. Decrypted
  copies are `/run/agenix/ntfy-auth` and `/run/agenix/ntfy-passwords`.
  `secrets/llama-api-key.age` is the Nemotron API key; the decrypted copy is
  `/run/agenix/llama-api-key` (mode `0440`, group `users`, so the desktop
  user can call the API from Pi). `secrets/rclone-gdrive.age` is required for
  the Lidarr Google Drive copy and is not in the repo yet, so the nightly
  timer is not installed even though `lidarr-drive` is enabled.
- `pia/ca.rsa.4096.crt` and `pia/pia-servers.json` are public PIA material
  used to reach a server by IP when the VPN hostnames are filtered.

## System configuration

The workstation uses:

- systemd-boot on EFI
- hostname `nixos`
- NetworkManager
- timezone `America/Chicago` and locale `en_US.UTF-8`
- Nix flakes and the `nix-command` interface
- unfree packages and redistributable firmware
- the proprietary stable NVIDIA driver with modesetting
- two NVIDIA GPUs, 6 GiB each. The RTX 3050 is the display card. The GTX
  1660 SUPER runs Nemotron.
- KDE Plasma 6 on Wayland with SDDM. KWin is pinned to the RTX 3050 through
  `/run/display-gpu`, because `KWIN_DRM_DEVICES` is split on `:` and the PCI
  path contains colons. Plasma (X11) stays in the SDDM menu. Cinnamon remains
  in `modules/desktop/cinnamon.nix` and is off; turn it on only with Plasma
  off, because each desktop starts its own display manager.
- PipeWire for ALSA and PulseAudio clients
- KDE Connect
- Tailscale with manual login and no automatically provisioned auth key
- Docker, enabled at boot with its default local Unix socket. Published
  container ports bind to `127.0.0.1` by default, because Docker's own
  iptables rules bypass the NixOS firewall. Use `-p 0.0.0.0:PORT:PORT` only
  for a port that should really be open on the home network.
- a local DNS proxy on `127.0.0.1:53` that forwards lookups over TLS.
  Names under `taile9f484.ts.net` go to MagicDNS at `100.100.100.100`
  instead, because 1.1.1.1 does not know them. Tailscale's own DNS client
  stays off so it does not replace this forwarder.
- a managed Chrome policy that turns Chrome's "secure DNS" off, so Chrome
  uses that forwarder. With secure DNS left on Cloudflare, Chrome cannot
  resolve `nixos.taile9f484.ts.net`.

The normal user is `rileyt`, with membership in `wheel`, `networkmanager`,
`docker`, and `media`. Docker group membership is effectively root-equivalent
and should only be granted to trusted users.

Cursor (`code-cursor`), Discord, GitHub CLI (`gh`), Git, Google Chrome,
htop, Spotify, and uv are installed system-wide from
`hosts/nixos/packages.nix`. OpenLogi comes from `modules/apps/openlogi.nix`
and is the local manager for the MX Master 4; its agent starts with the
graphical session. RustDesk is `rustdesk-flutter` from the unstable overlay,
installed by `modules/apps/rustdesk.nix`, because nixos-26.05 `rustdesk` is
the old Sciter client. Pi (`pi-coding-agent` 1.4.0 from the unstable overlay)
is installed by `modules/apps/pi.nix`. Its config is `pi/` in this repo, and
the `pi` command points at that directory from any working directory. It
talks to Nemotron on loopback and must not start its own llama.cpp. The `uinput` kernel module is loaded at boot so
OpenLogi's device node receives a seat ACL. The menu also has a Chrome app
entry for Cleanuparr that opens `http://127.0.0.1:11011`.

For Python development, uv is the default project and package manager:
use `uv init`, `uv add`, `uv sync`, `uv run`, and `uv tool` rather than
calling `pip` directly. Nix remains responsible for system-level Python
packages and service environments.

The NixOS firewall stays enabled.

- KDE Connect uses TCP and UDP 1714–1764 on `enp132s0` only, so a phone on
  the home Wi-Fi can pair. Those ports are not accepted on Tailscale or on
  the VPN.
- OpenSSH accepts TCP port 22 only on `tailscale0`, and only for `rileyt`,
  using public keys. Password and root logins are disabled.
- Jellyfin accepts TCP port 8096 on `enp132s0` and `tailscale0` on
  purpose, so a phone or another player on the home Wi-Fi can use
  `http://192.168.50.101:8096`, and any device on the tailnet can play
  video and music. That port is not accepted on the VPN interface.
- Uptime Kuma accepts TCP port 3001 on `tailscale0` only. The process listens
  on `127.0.0.1:3001`. Tailscale Serve presents HTTPS for
  `nixos.taile9f484.ts.net:3001` and proxies to that port. This computer can
  still open `http://127.0.0.1:3001`. The home network and the VPN cannot.
- ntfy accepts TCP port 2586 on `tailscale0` only. The process listens on
  `127.0.0.1`. Tailscale Serve presents HTTPS for
  `nixos.taile9f484.ts.net:2586` and proxies to that port. This computer
  can still open `http://127.0.0.1:2586`. The home network and the VPN
  cannot.
- Immich accepts TCP 2283 on `tailscale0` only. The process listens on
  `127.0.0.1`. Tailscale Serve presents HTTPS for
  `nixos.taile9f484.ts.net:2283` and proxies to that port. This computer
  uses `http://127.0.0.1:2283`. The home network and the VPN cannot.
- Cleanuparr accepts TCP port 11011 on `tailscale0` only. The process
  listens on `127.0.0.1`. Tailscale Serve presents HTTPS for
  `nixos.taile9f484.ts.net:11011` and proxies to that port. This computer
  can still open `http://127.0.0.1:11011`. The home network and the VPN
  cannot.
- n8n accepts TCP port 5678 on `tailscale0` only. The process listens on
  `127.0.0.1:5678`. Tailscale Serve presents HTTPS for
  `nixos.taile9f484.ts.net:5678`. This computer uses
  `http://127.0.0.1:5678`. The editor base URL is that loopback address
  because Spotify OAuth allows plain HTTP only for `127.0.0.1` and rejects
  the tailnet host.
- Nemotron accepts TCP port 8083 on `tailscale0` only. `llama-server`
  listens on `127.0.0.1:8083`. Tailscale Serve presents HTTPS for
  `nixos.taile9f484.ts.net:8083`. The API key is the age secret
  `secrets/llama-api-key.age` (decrypted at `/run/agenix/llama-api-key`).
- RustDesk accepts TCP port 21118 on `tailscale0` only, for Android direct
  access. That port is not on the LAN or the VPN.
- nixctl-bridge listens on `127.0.0.1:8094` only. It is not on Tailscale.
  Read-only `nixctl` commands run immediately. A command saved earlier runs
  as saved. Anything else waits for Discord approval. Do not publish this
  port.
- The media web pages and the qBittorrent WebUI accept their ports on
  `tailscale0` only: 5055 Seerr, 6767 Bazarr, 7878 Radarr, 8080
  qBittorrent, 8686 Lidarr, 8989 Sonarr, and 9696 Prowlarr. These are
  admin pages. This repository does not contain a Tailscale ACL or
  policy file, so tailnet membership is the network limit, and each
  app still requires its own login. Those passwords are not in git.
  KDE Connect stays on the home network, and the torrent listen port
  stays on the VPN.
- qBittorrent's torrent port is accepted only on the `pia` interface.

The system SSH client maps `ssh laptop` to
`riley@rileys-minty.taile9f484.ts.net`.

`system.stateVersion` is `26.05`. Do not change it during a normal NixOS
upgrade; it controls compatibility defaults for stateful services.

## Media stack

Requests and playback work in a browser on this computer. The same pages
are available on the tailnet. Only Jellyfin is also open on the home Wi-Fi.

| App | Address | Role |
|---|---|---|
| Seerr | http://127.0.0.1:5055 or http://nixos.taile9f484.ts.net:5055 | Request a show or movie |
| Jellyfin | http://192.168.50.101:8096 on Wi-Fi, http://nixos.taile9f484.ts.net:8096 on Tailscale | Watch and listen |
| Sonarr | http://127.0.0.1:8989 or http://nixos.taile9f484.ts.net:8989 | TV downloads and library |
| Radarr | http://127.0.0.1:7878 or http://nixos.taile9f484.ts.net:7878 | Movie downloads and library |
| Prowlarr | http://127.0.0.1:9696 or http://nixos.taile9f484.ts.net:9696 | Indexers for the apps above |
| Lidarr | http://127.0.0.1:8686 or http://nixos.taile9f484.ts.net:8686 | Music. Add artists here; Seerr does not request music |
| Bazarr | http://127.0.0.1:6767 or http://nixos.taile9f484.ts.net:6767 | Subtitles, after a language profile is chosen |
| qBittorrent | http://127.0.0.1:8080 or http://nixos.taile9f484.ts.net:8080 | Torrent client. Sonarr, Radarr, and Lidarr drive it |
| Cleanuparr | http://127.0.0.1:11011 or https://nixos.taile9f484.ts.net:11011 | Removes stalled, failed, and blocked downloads. The first visit creates the login. Cleaners stay off until enabled. Turn Dry run on first |
| Uptime Kuma | http://127.0.0.1:3001 or https://nixos.taile9f484.ts.net:3001 | Whether the apps above, Pi-hole, and the tailnet path to the Pi are up |

A request in Seerr goes to Sonarr or Radarr. That app asks Prowlarr for a
torrent. Prowlarr's search leaves through the VPN. The grab goes to
qBittorrent, which is bound to the `pia` interface, so the download stops if
the tunnel is down instead of using the home address. Finished files are
moved into the library and then show up in Jellyfin. Cleanuparr reads the
same queue. Its login and the API keys it stores stay in
`/var/lib/cleanuparr`. Turn on Dry run in its General page before enabling
a cleaner, or the cleaner deletes downloads.

The vault disk is mounted at `/vault`. `/vault/media` is a bindfs view of
the game drive. Files there show as group `media`, mode `0770`, so Sonarr,
Radarr, Lidarr, and the other media apps can read and write them. The NTFS
volume underneath stays rileyt-only, which is what keeps `old stuff` private.

- Incomplete downloads: `/vault/media/downloads/incomplete`
- TV, movies, and music downloads: `/vault/media/downloads/tv`, `movies`, and `music`
- Library: `/vault/media/library/tv`, `movies`, and `music`

Sonarr, Radarr, Lidarr, Bazarr, and Jellyfin run as group `media`. Sonarr's
config directory and qBittorrent's config directory are mode `0700` so other
local accounts cannot read API keys or the WebUI password hash. PIA
credentials stay in the age file. Do not commit plaintext passwords, API
keys, or WireGuard private keys.

Uptime Kuma checks those apps every 60 seconds, plus Pi-hole on the home
network and the same Pi-hole page over its tailnet address. The second
check fails when Tailscale cannot reach the Pi even if the home-network
check is still up. The admin account, monitor list, and the ntfy
notification live under `/var/lib/uptime-kuma/` (e.g. `kuma.db`). That directory is not in git.
Stop the service before editing the sqlite file.
The notification posts to this computer's ntfy topic `uptime` and is
attached to every monitor.
The dashboard is HTTP inside the Tailscale tunnel, which is already
encrypted. It is not published on the home LAN.

## ntfy

ntfy is the push server for the phone. On this computer the web app is
`http://127.0.0.1:2586`. On the tailnet it is
`https://nixos.taile9f484.ts.net:2586`. The phone has to be on the same
tailnet. Install Tailscale on the phone and log in before subscribing.

Anonymous publish and subscribe are denied, and signup is off. Two users
are created at startup. The plaintext is not in git. Read it with:

```sh
pkexec cat /run/agenix/ntfy-passwords
```

| Who | User | Can |
|---|---|---|
| Phone | `rileyt` | Read and publish every topic |
| Sonarr, Radarr, Lidarr, Uptime Kuma | `apps` | Publish only, using the token |

| Topic | Who publishes | When |
|---|---|---|
| `movies` | Radarr | A movie file is imported |
| `shows` | Sonarr | An episode file is imported |
| `music` | Lidarr | A release is imported |
| `uptime` | Uptime Kuma | A monitor changes state |

A grab, which is the moment a torrent is added, does not notify. An
upgrade to a better copy does not notify either. Those switches are in
each app under Settings, Connect, on the ntfy connection. The connections
are stored in each app's database, not in this repository.

Messages are kept for 24 hours, including across a reboot, so a phone that
was off overnight still receives them.

On the phone:

1. Install the ntfy app.
2. Set the default server to `https://nixos.taile9f484.ts.net:2586` with
   no trailing slash. The iOS app only wakes for a server URL that matches
   this exactly.
3. Log in as `rileyt` with the phone password from the file above.
4. Subscribe to `movies`, `shows`, `music`, and `uptime`.

Android keeps its own connection to this server. Turn off battery
optimization for ntfy, or the phone will stop showing notifications after
it sleeps. iOS cannot keep that connection. This server asks `ntfy.sh` to
wake the phone. The wake-up text is `New message` and does not include the
movie, show, or song title. The phone then downloads the real message from
this computer. If the phone is not on the tailnet, the lock screen stays
on `New message`.

## Immich

Immich is the photo and video backup server. On this computer it is
`http://127.0.0.1:2283`. On the tailnet it is
`https://nixos.taile9f484.ts.net:2283`. The phone app uses the tailnet
URL. The process listens on `127.0.0.1`, and Tailscale Serve presents
HTTPS for that hostname.

The library is `/vault/immich`, mode `0700`, owned by user `immich` and
group `immich`. The Postgres database stays on the root disk at the
module default. Redis is a local unix socket. The server is Immich
3.3.5 from the nixpkgs-unstable pin. nixos-26.05 packages 2.7.5, which
is marked insecure.

The first visit creates the admin account. Do that on this computer at
`http://127.0.0.1:2283`, before an untrusted device is on the tailnet,
and leave open registration disabled.

Machine learning for faces and search runs on CPU. The module default
is one worker. The RTX 3050 is left to the desktop. The GTX 1660 SUPER
runs Nemotron.

On the phone:

1. Tailscale on the phone, on this same tailnet. That login is already
   required for ntfy.
2. Immich from the App Store, Play Store, or F-Droid. Use a 3.3.x app
   so it matches server 3.3.5.
3. Create the admin user at `http://127.0.0.1:2283` on this computer
   first, and leave open registration off, before an untrusted device
   is on the tailnet.
4. In the app, set the server endpoint to
   `https://nixos.taile9f484.ts.net:2283`, log in, open the cloud icon,
   select the camera album (Android Camera; iOS Recents), and enable
   backup. Album sync mirrors phone albums on the server if wanted.
5. Uploads are Wi-Fi only unless changed in the app.
6. Android: exempt Immich from battery optimization. iOS: Settings >
   General > Background App Refresh for Immich. iOS schedules background
   uploads itself; opening the app uploads sooner.
7. The app checksums files and skips ones already on the server.

https://docs.immich.app/features/mobile-backup

## n8n

n8n is the workflow editor. On this computer it is
`http://127.0.0.1:5678`. On the tailnet it is
`https://nixos.taile9f484.ts.net:5678`. The package is n8n 2.34.6 from
nixos-26.05. Each `*.schema.js` is hardlinked to a matching `*.ts` so the
MCP node list still resolves.

Spotify OAuth must be started from a browser on this PC. The editor base
URL stays on loopback HTTP because Spotify only allows that for
`127.0.0.1`.

## Nemotron

Nemotron 3.5 Bolt E4B runs in `llama-server` from `packages/llama-cpp.nix`.
The model alias is `nemotron-bolt`. On this computer the API is
`http://127.0.0.1:8083`. On the tailnet it is
`https://nixos.taile9f484.ts.net:8083`. Model files live under
`/var/lib/llama-cpp/models`. Inference uses the GTX 1660 SUPER with context
32768. The API key comes from `secrets/llama-api-key.age`.

The persona text is in `nemotron-bolt-system-prompt.md`.

## Pi

Pi is the terminal coding agent (`pi` from `pi-coding-agent`). It uses
`http://127.0.0.1:8083` with model `nemotron-bolt`. The agent directory is
`/etc/nixos/pi` (`PI_CODING_AGENT_DIR`), so the same `models.json`,
`settings.json`, `APPEND_SYSTEM.md`, and skills apply in any working
directory. That directory is this repo. Session transcripts go to
`~/.local/state/pi/sessions` and are not committed. `auth.json`,
`trust.json`, and `models-store.json` are gitignored because Pi writes them
beside the config. The nixos-managing skill there is Part 1 only. Force it
with `/skill:nixos-managing`. Pi must not start its own llama.cpp server;
Nemotron on the GTX 1660 SUPER is the only inference backend.

## RustDesk

RustDesk is the remote desktop host for Android on the tailnet. Direct
access is TCP port 21118 on `tailscale0` only. The client is
`rustdesk-flutter` from nixpkgs-unstable, the Wayland Flutter client.

## nixctl-bridge

The nixctl-bridge service listens on `127.0.0.1:8094` for the Discord
operator. Read-only `nixctl` commands run immediately. A command saved
earlier runs as saved. Anything else waits for approval in Discord.

## lidarr-drive

`modules/services/arr/lidarr-drive.nix` copies
`/vault/media/library/music` to `gdrive:Lidarr` every night at 3:00 AM
`America/Chicago`. The module is enabled in `hosts/nixos/default.nix`. The
timer is not installed until `secrets/rclone-gdrive.age` is committed. The
copy needs `services/arr/media` for the library paths.

## VPN

`modules/network/pia.nix` logs in with the age secret and writes
`/etc/wireguard/pia.conf` at start. That file is mode `0600` and is not in
git. The tunnel uses routing table `51820`. qBittorrent traffic sourced from
the tunnel address uses that table. The desktop default route stays on
`enp132s0`.

Prowlarr lookups are marked and sent through the same table. Traffic to
`127.0.0.1` and to the Tailscale range `100.64.0.0/10` is not marked, so
the local apps and a browser on the tailnet can still reach Prowlarr.
Sonarr, Radarr, and Lidarr are not marked.

Prowlarr and qBittorrent may only use `lo`, `pia`, and `tailscale0`
(systemd `RestrictNetworkInterfaces`). That is the kill switch: when the
tunnel is down, while a service is starting before its routing is in place,
or for IPv6, which the IPv4 mark does not cover, traffic that would leave
through `enp132s0` is dropped instead of using the home address. It also
covers qBittorrent's own HTTP requests (RSS, `.torrent` URLs), which do not
follow its `Interface = pia` binding.

The PIA scripts give curl the username, password, and tokens on stdin
(`curl -K -`), not on its command line, so other local accounts cannot read
them with `ps`. The connect script checks that PIA's answer is an address, a
WireGuard key, and a port before writing it into `pia.conf`, whose `PostUp`
lines `wg-quick` runs as root.
The forwarded-port keepalive runs every 15 minutes. The listen port in
`modules/services/arr/qbittorrent.nix` has to match the port PIA assigned.

## Development shell

`nix dev` opens one development shell from any directory. Nix 2.34 has no
`dev` command, and bash cannot alias a two-word command, so
`modules/dev/shell.nix` installs a shell function named `nix`. That function
sends only `nix dev` to `dev/flake.nix`. Every other `nix` command still runs
the real Nix binary. The function is in the interactive shell startup, so a
terminal that was already open does not have it until that terminal starts a
new shell.

The shell is its own flake, not an output of the system flake. It sits in
`dev/` so `modules/default.nix` does not import it as a NixOS module. Its
nixpkgs pin is `nixos-26.05`, locked in `dev/flake.lock`, separate from the
system `flake.lock`. The shell provides git, python3, uv, nodejs, rustc,
cargo, go, gcc, and pkg-config.

Add or remove a tool by editing the package list in `dev/flake.nix`, then
`git add` that file. Nix only sees files git is tracking. The next `nix dev`
uses the new list. That edit does not need `nixctl apply`. Arguments after
`dev` are passed through, so `nix dev -c python3` runs that command inside
the shell.

Turn the command off with `nixctl disable dev/shell`, then
`nixctl apply "disable nix dev"`. The flake files can stay.

## Apply and validate

Change this computer with `nixctl` after it is installed. Run `nixctl map`
to see which modules are on, edit the repo, then `nixctl apply "what
changed"`. `nixctl apply` builds the config, activates it as a test, and
keeps it only if no new service is broken. It also commits the change
locally. It does not push. Agent rules are in `nix-agent.md`. The short
loader is `AGENTS.md`. `agent.md` points Cursor at those files.

nixctl is not on the running system until the next switch. Run this once
from `/etc/nixos`:

```sh
pkexec nixos-rebuild switch --flake /etc/nixos
```

After that, `nixctl status` should print `RESULT: OK`. Later changes are
`nixctl apply "what changed"`. If a switch misbehaves, `nixctl rollback`
returns to the previous generation.

## OpenSSH

OpenSSH is the remote shell for this workstation and the Linux Mint laptop
`rileys-minty`. Both machines are on the `taile9f484.ts.net` tailnet. SSH is
not exposed on the LAN or the public internet: `sshd` listens on port 22, and
the firewall accepts that port only on `tailscale0`.

`services.openssh.openFirewall` stays false because its NixOS default would
open port 22 on every interface. Password authentication,
keyboard-interactive authentication, and root login are disabled. The only
allowed account on this machine is `rileyt`. Login from the laptop uses the
public key installed in `/home/rileyt/.ssh/authorized_keys`. That file and
the private keys under `/home/rileyt/.ssh/` are local state; they are not
stored in this repository.

The system SSH client alias is:

```text
ssh laptop
```

It connects to `riley@rileys-minty.taile9f484.ts.net`. The laptop account is
`riley`, which is a different name from the `rileyt` account on this
workstation. From the laptop, this machine is:

```text
ssh rileyt@nixos
```

`nixos` resolves through Tailscale MagicDNS. The same host is
`nixos.taile9f484.ts.net`.

On the laptop, OpenSSH must be installed and the public key from
`/home/rileyt/.ssh/id_ed25519.pub` must be present in
`/home/riley/.ssh/authorized_keys`. `apt update` on that machine can fail
while the Spotify or Cursor apt repositories have missing signing keys. The
install can continue with `sudo apt update || true` and then
`sudo apt install -y openssh-server`. If `ufw` is active, allow TCP port 22
on `tailscale0` only.

Useful checks:

```sh
systemctl status sshd
ssh -G laptop
tailscale status
```

## Hardware configuration

`hosts/nixos/hardware-configuration.nix` records the current root, EFI, and swap UUIDs,
the detected initrd modules, Intel CPU microcode, KVM support, and Intel NPU
support. Re-run `nixos-generate-config` after disk or platform changes and
review the generated diff instead of hand-editing this file.

Because disk UUIDs and the username are machine-specific, review this
repository before publishing it publicly. The age file is encrypted, and it
is safe to commit. Plaintext credentials are not.
