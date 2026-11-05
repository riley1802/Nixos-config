# NixOS Desktop Configuration

This repository is the NixOS configuration for the `nixos` workstation. It
defines a KDE Plasma desktop, dual-NVIDIA graphics, OpenSSH over the tailnet,
two llama.cpp servers plus a third that stays off, n8n, ntfy, Immich, Uptime Kuma, Netdata, Homarr, Homelable, and a
torrent media stack.
qBittorrent and Prowlarr lookups use a Private Internet Access WireGuard tunnel. The
rest of the desktop stays on the home network.

## Repository layout

```
flake.nix                         inputs and one host
flake.lock                        exact input revisions
hosts/nixos/default.nix           hostname, shared settings, which modules are on
hosts/nixos/packages.nix          programs installed by name
hosts/nixos/hardware-configuration.nix
modules/core/                     nix, boot, time, user, package overlays
modules/hardware/                 NVIDIA driver, vault disk, game drive
modules/desktop/                  Plasma, Cinnamon (off), KDE Connect, Chrome DNS policy
modules/network/                  Tailscale, DNS, SSH, NetworkManager, PIA, firewall
modules/services/arr/             Sonarr, Radarr, Lidarr, Bazarr, Prowlarr, Seerr,
                                  qBittorrent, Cleanuparr, and the shared media directories
modules/services/                 Jellyfin, Immich, n8n, ntfy, llama.cpp, Kokoro,
                                  Homarr, Homelable, Netdata, Uptime Kuma, Docker
modules/apps/openlogi.nix         MX Master 4
packages/                         Lidarr, Cleanuparr, llama.cpp, and Uptime Kuma builds
secrets/                          agenix recipients and encrypted files
pia/                              public PIA certificate and server list
```

`hosts/nixos/default.nix` is the control panel. Feature settings stay in the
module that owns them. `hosts/nixos/hardware-configuration.nix` is generated
by `nixos-generate-config` and should not be edited by hand.

- `flake.nix` pins NixOS to the `nixos-26.05` branch. Cursor, Radarr, and
  Immich come from `nixpkgs-unstable`. Cursor and Radarr are there because
  26.05 lags behind. Immich is 3.3.5 on that pin because 26.05 has 2.7.5,
  which is marked insecure, and phone apps need 3.x. The overlays live in
  `modules/core/overlays.nix`.
- `packages/lidarr.nix` is the official Lidarr 3.1.6.5079 release, because
  nixpkgs does not have it yet. `packages/uptime-kuma/package.nix` builds
  Uptime Kuma 2.5.8 for the same reason: 26.05 has 2.5.3 and the unstable
  pin has 2.5.7. 2.5.8 is the current release and includes its admin-only
  remote-code-execution fix. `packages/uptime-kuma/uptime-kuma-database-permissions.patch`
  keeps a newly created database from being world-readable.
- `modules/services/uptime-kuma.nix` runs that package.
- `packages/cleanuparr.nix` is the official Cleanuparr 2.10.12 linux-amd64
  build. nixpkgs does not have it. `modules/services/arr/cleanuparr.nix`
  runs it.
- `packages/llama-cpp.nix` builds llama.cpp 0.8.0 with CUDA. The 26.05 pin
  is build 9190, which cannot load LFM3. `modules/services/llama.nix` runs
  the two servers and publishes them with Tailscale Serve. Both servers
  require the API key in `secrets/llama-api-key.age`.
  `modules/services/breeze-tts.nix` runs Breeze TTS 2 Q8 on the GTX 1660
  SUPER. The package is the `breeze-tts` flake input, tag v0.1.6. The
  process listens on `127.0.0.1:8084` and `127.0.0.1:8085`, and Tailscale
  Serve publishes both. The Q8_0 weights download into `/var/lib/breeze-tts`
  on first start.
  `modules/services/nemotron.nix` is a third server, Nemotron 3.5 Bolt E4B.
  `my.hardware.gtx1660` in the host file chooses Breeze or Nemotron for the
  1660. The other unit stays installed and stopped. `gtx1660 breeze` or
  `gtx1660 nemotron` flips the running process; the host line is the boot
  default and what the tailnet publishes.
  `modules/services/kokoro.nix` runs Kokoro-82M on the CPU, separate from
  Breeze. It listens on `127.0.0.1:8087`. Tailscale Serve publishes that
  port. The weights are `hexgrad/Kokoro-82M` in `/var/lib/kokoro`.
- `modules/services/n8n.nix` runs n8n 2.34.6 from the nixos-26.05 module and
  publishes it with Tailscale Serve. The owner account and workflows stay in
  `/var/lib/n8n`.
- `modules/services/ntfy.nix` runs ntfy 2.26.0 from the nixos-26.05 module
  and publishes it with Tailscale Serve. The phone password and the
  publisher token are age secrets. `secrets/ntfy-auth.age` is what the
  server reads. `secrets/ntfy-passwords.age` is the copy for the phone app.
- `modules/services/immich.nix` runs Immich 3.3.5 from nixpkgs-unstable
  because 26.05 has 2.7.5. The nixos-26.05 `services.immich` module still
  provides PostgreSQL, Redis, pgvector, and VectorChord. Photos are stored
  in `/vault/immich`.
- `modules/services/homarr.nix` runs the official container
  `ghcr.io/homarr-labs/homarr:v2.10.1`, which is not in nixpkgs. On this
  computer it is `http://127.0.0.1:7575`. On the tailnet it is
  `https://nixos.taile9f484.ts.net:7575`. The tiles stay in
  `/var/lib/homarr`.
- `modules/services/homelable.nix` runs the official containers
  `ghcr.io/pouzor/homelable-backend:3.6.0`,
  `ghcr.io/pouzor/homelable-frontend:3.6.0`, and
  `ghcr.io/pouzor/homelable-mcp:3.6.0`. On this computer the diagram is
  `http://127.0.0.1:3000`. On the tailnet it is
  `https://nixos.taile9f484.ts.net:3000`. The canvas stays in
  `/var/lib/homelable`. The login is `pkexec cat /run/agenix/homelable-login`.
- `modules/services/netdata.nix` runs a local Netdata agent on loopback and
  publishes it with Tailscale Serve. The package is `netdataCloud`, because
  the default build has no dashboard files and the page is
  "File does not exist, or is not accessible:". The dashboard assets
  are NCUL-1 and are built on this computer. Open `/v3` for the
  charts. This agent has no local password without a Netdata Cloud
  claim, and the agent is not claimed, so a tailnet device can open
  `/v3`. Charts and alarm state stay in `/var/lib/netdata`.
- `modules/services/jellyfin.nix` runs Jellyfin. The arr apps and
  qBittorrent are the files in `modules/services/arr/`.
- `modules/network/pia.nix` builds the split tunnel and routes Prowlarr
  lookups through it.
- `secrets/secrets.nix` lists the age recipients. `secrets/pia-credentials.age`
  is the encrypted PIA username and password. The decrypted file is
  `/run/agenix/pia-credentials` and is not in git. `secrets/ntfy-auth.age`
  and `secrets/ntfy-passwords.age` are the ntfy credentials. Decrypted
  copies are `/run/agenix/ntfy-auth` and `/run/agenix/ntfy-passwords`.
  `secrets/homarr-encryption-key.age` is Homarr's
  `SECRET_ENCRYPTION_KEY`. The decrypted file is
  `/run/agenix/homarr-encryption-key`.
  `secrets/llama-api-key.age` is the llama.cpp API key for the servers
  and for Open WebUI. The decrypted file is `/run/agenix/llama-api-key`.
  `secrets/homelable-env.age` is Homelable's `SECRET_KEY`, admin password
  hash, and MCP keys. `secrets/homelable-login.age` is the admin username
  and password. Decrypted copies are `/run/agenix/homelable-env` and
  `/run/agenix/homelable-login`.
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

Cursor, Google Chrome, Git, htop, llama.cpp, OpenLogi, and Spotify are
installed system-wide. OpenLogi is the local manager for the MX Master 4;
its agent starts with the graphical session. The `uinput` kernel module is
loaded at boot so that agent's device node receives a seat ACL. The menu
also has Chrome app entries for Homarr and Cleanuparr.
Those open `http://127.0.0.1:7575` and `http://127.0.0.1:11011`.

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
  on every address so both IPv4 and IPv6 tailnet clients can connect, and
  the firewall is what keeps the home network and the VPN out. This computer
  can still open `http://127.0.0.1:3001` through the trusted loopback
  interface.
- llama.cpp is reached through Tailscale Serve on TCP 8081 and 8082.
  Those two ports are accepted on `tailscale0`. Port 8083 is Nemotron.
  Serve and the firewall publish it only while `my.hardware.gtx1660` is
  `nemotron`. The llama processes themselves
  listen on `127.0.0.1` only. Chrome forces HTTPS for every `*.ts.net`
  name, so plain HTTP on the tailnet hostname times out. Serve presents a
  Let's Encrypt certificate for `nixos.taile9f484.ts.net` and proxies to
  the loopback ports. Uptime Kuma still checks `http://127.0.0.1:8081/health`
  and `http://127.0.0.1:8082/health`. Those health URLs stay open. Other
  routes require the API key in `secrets/llama-api-key.age`.
- Breeze TTS 2 Q8 accepts TCP 8084 and 8085 on `tailscale0` only while
  `my.hardware.gtx1660` is `breeze-tts`. The process listens on
  `127.0.0.1`. Tailscale Serve presents HTTPS for
  `nixos.taile9f484.ts.net:8084` (the page and the HTTP API) and
  `:8085` (the WebSocket the page opens when it speaks) and proxies to
  those ports. This computer can still open `http://127.0.0.1:8084`. The
  home network and the VPN cannot. The server does not authenticate; the
  tailnet is the access boundary. The service is
  `modules/services/breeze-tts.nix`, model `breeze-tts-2-q8_0.gguf`,
  device GTX 1660 SUPER
  (`GPU-f2ae9716-6783-f900-4fed-c05b9cb3a6aa`). Check
  `http://127.0.0.1:8084/health`. Synthesis is `POST /v1/audio/speech`.
  A form post returns raw 24 kHz signed 16-bit PCM. OpenAI-style JSON
  with `"response_format":"wav"` returns WAV. Saved voices live in
  `/var/lib/breeze-tts/voices`. n8n's Discord replies use Breeze at
  `http://127.0.0.1:8084/v1/audio/speech`.
- Kokoro-82M accepts TCP 8087 on `tailscale0` only. The process listens on
  `127.0.0.1`. Tailscale Serve presents HTTPS for
  `nixos.taile9f484.ts.net:8087` and proxies to that port. This computer
  can still open `http://127.0.0.1:8087`. The home network and the VPN
  cannot. The server does not authenticate; the tailnet is the access
  boundary. The service is `modules/services/kokoro.nix`. It uses the
  nixpkgs `kokoro` package, CPU torch, and 16 threads. Check
  `http://127.0.0.1:8087/health`. Synthesis is
  `POST /v1/audio/speech` with JSON `input`, optional `voice` (default
  `af_heart`; a name starting with `b` is British English), and
  `response_format` `wav`. The response is 24 kHz mono WAV. On 2026-11-04,
  voice `af_heart`, one warmup discarded, median of three runs: 16 CPU
  threads spoke a 46-character sentence in 0.453 seconds (3.275 seconds of
  audio, real-time factor 7.22) and a 1016-character passage in 9.667
  seconds (59.7 seconds of audio, first audio at 4.424 seconds, real-time
  factor 6.18). The RTX 3050, with the desktop still on the card and Omni
  stopped, did the same clips in 0.136 seconds (real-time factor 24.1) and
  1.990 seconds (first audio at 0.876 seconds, real-time factor 30.0).
  Peak GPU allocation was 1027 MiB. That does not fit beside Omni, so the
  service stays on the CPU.
- n8n accepts TCP port 5678 on `tailscale0` only. The process listens on
  `127.0.0.1`. Tailscale Serve presents HTTPS for
  `nixos.taile9f484.ts.net:5678` and proxies to that port. This computer
  can still open `http://127.0.0.1:5678`.
- ntfy accepts TCP port 2586 on `tailscale0` only. The process listens on
  `127.0.0.1`. Tailscale Serve presents HTTPS for
  `nixos.taile9f484.ts.net:2586` and proxies to that port. This computer
  can still open `http://127.0.0.1:2586`. The home network and the VPN
  cannot.
- Immich accepts TCP 2283 on `tailscale0` only. The process listens on
  `127.0.0.1`. Tailscale Serve presents HTTPS for
  `nixos.taile9f484.ts.net:2283` and proxies to that port. This computer
  uses `http://127.0.0.1:2283`. The home network and the VPN cannot.
- Homarr accepts TCP port 7575 on `tailscale0` only. The container publishes
  `127.0.0.1:7575`. Tailscale Serve presents HTTPS for
  `nixos.taile9f484.ts.net:7575` and proxies to that port. This computer
  can still open `http://127.0.0.1:7575`. The home network and the VPN
  cannot.
- Cleanuparr accepts TCP port 11011 on `tailscale0` only. The process
  listens on `127.0.0.1`. Tailscale Serve presents HTTPS for
  `nixos.taile9f484.ts.net:11011` and proxies to that port. This computer
  can still open `http://127.0.0.1:11011`. The home network and the VPN
  cannot.
- Homarr's status checks come from `172.30.88.2` on the bridge
  `br-homarr`. The firewall accepts that address on the app ports.
  `docker0` is not opened. Open WebUI, both llama servers, n8n, and ntfy
  stay on `127.0.0.1`. A proxy on the bridge gateway,
  `172.30.88.1`, forwards those five pings. qBittorrent and Prowlarr
  also accept the bridge, and Prowlarr's reply to it stays off the VPN.
- Netdata accepts TCP port 19999 on `tailscale0` only. The process listens
  on `127.0.0.1`. Tailscale Serve presents HTTPS for
  `nixos.taile9f484.ts.net:19999` and proxies to that port. This computer
  uses `http://127.0.0.1:19999/v3`. The home network and the VPN cannot.
  `/v3` has no local password. Netdata 2.10.3's bearer protection is a
  Cloud sign-in, and this agent is not claimed, so any device already on
  the tailnet can open the charts. PIA's remote API also uses port 19999.
  That is an outbound HTTPS call from `modules/network/pia.nix`, not this
  listener.
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
| Uptime Kuma | http://127.0.0.1:3001 or http://nixos.taile9f484.ts.net:3001 | Whether the apps above, Pi-hole, and the tailnet path to the Pi are up |

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
notification live in `/var/lib/uptime-kuma`. That directory is not in git.
The notification posts to this computer's ntfy topic `uptime` and is
attached to every monitor.
The dashboard is HTTP inside the Tailscale tunnel, which is already
encrypted. It is not published on the home LAN.

## Dashboards

Homarr is the visual board. Uptime Kuma still checks the apps and still
posts outage notifications to the ntfy topic `uptime`. The board does not
replace that.

| App | Address | What is stored where |
|---|---|---|
| Homarr | http://127.0.0.1:7575 or https://nixos.taile9f484.ts.net:7575 | The container and the encryption key are declared here. Tiles and the admin account are created in the web UI and stay in `/var/lib/homarr`, which is not in git. |
| Homelable | http://127.0.0.1:3000 or https://nixos.taile9f484.ts.net:3000 | The containers and the login are declared here. The canvas stays in `/var/lib/homelable`, which is not in git. Login: `pkexec cat /run/agenix/homelable-login`. |
| Netdata | http://127.0.0.1:19999/v3 or https://nixos.taile9f484.ts.net:19999/v3 | Agent config is in `modules/services/netdata.nix`. `/v3` has no local password. This agent cannot require one without a Netdata Cloud claim, and it is not claimed, so any tailnet device can open the charts. The root URL is the Cloud sign-in. Charts and alarm state stay in `/var/lib/netdata`, which is not in git. |

The Chrome menu entries open the loopback addresses. The tailnet addresses
are for the phone. Finish first-run setup on this computer before an
untrusted device is on the tailnet. Homarr's first visit, at
`http://127.0.0.1:7575`, creates the admin account. Open WebUI's first
account, at `http://127.0.0.1:8088`, is the admin. Immich's first visit,
at `http://127.0.0.1:2283`, creates the admin account, and open
registration stays disabled.

Homarr's board is the media apps and the services on this computer.
Tiles open on this computer.
Sonarr, Radarr, Lidarr, Bazarr, Jellyfin, and Seerr are also integrations.
The container is the only member of the Docker network `homarr`, at
`172.30.88.2` on the bridge `br-homarr`. Status checks use
`http://host.docker.internal:PORT`, stored on each app in
`/var/lib/homarr`. The firewall accepts only that source address.
`docker0` is not opened, so another container on the default bridge
cannot reach them. Open WebUI, both llama servers, n8n, and ntfy stay on
loopback; Homarr reaches them through a proxy on `172.30.88.1`.
qBittorrent and Prowlarr accept the bridge in addition to `lo`, `pia`,
and `tailscale0`. Further tile changes stay in `/var/lib/homarr`.

## llama.cpp

Two `llama-server` processes from llama.cpp 0.8.0 (build 11960). One
process cannot be GPU-only for one model and CPU-only for the other.

| Model | Where it runs | Context | KV cache | Browser | API base |
|---|---|---|---|---|---|
| LFM3-Omni-2B Q8_0 | RTX 3050 | 32768 | q8_0 | https://nixos.taile9f484.ts.net:8081/ | https://nixos.taile9f484.ts.net:8081/v1 |
| LFM3-1.7B Q8_0 | CPU, 12 threads | 32768 | q8_0 | https://nixos.taile9f484.ts.net:8082/ | https://nixos.taile9f484.ts.net:8082/v1 |

Nemotron 3.5 Bolt E4B Q4_K_M listens on `127.0.0.1:8083` when
`my.hardware.gtx1660` is `nemotron`, with model id `nemotron-bolt`, context
32768, a q8_0 KV cache, and the Gemma 4 E4B MTP assistant
`mtp-gemma-4-E4B-it-Q8_0.gguf` as `--spec-type draft-mtp` with
`--spec-draft-n-max 1`. It is pinned to the GTX 1660 SUPER
(`GPU-f2ae9716-6783-f900-4fed-c05b9cb3a6aa`). The official GGUF is
6,180,446,208 bytes, about 5.76 GiB, so the unit does not set `-ngl` and
sets `--fit on` and `--fit-ctx 32768`. Sampling is `--temp 1.0`, `--top-p 0.95`, and
`--reasoning on`. The weight file belongs in `/home/rileyt/llama-models`
as `Nemotron-3.5-Bolt-E4B-Q4_K_M.gguf`. The host line
`my.hardware.gtx1660` chooses this server or Breeze. `gtx1660 nemotron`
starts it immediately and stops Breeze. Tailscale Serve, Open WebUI, and
the Homarr ping proxy add port 8083 only when the host line is `nemotron`
and `nixctl apply` has run.
Measured on 2026-11-04 on this 1660, 128 new tokens, seed 1, short prompt:
57.4 tok/s with no drafter, 74.7 tok/s at draft length 1, 65.4 at 2, 61.4
at 3, and 53.3 at 4. Draft length 1 is what the unit uses. With that
drafter and a filled window: 15811 prompt tokens at context 16384 were
186.7 tok/s prefill and 55.9 tok/s generation; 32218 prompt tokens at
context 32768 were 157.0 and 42.8. The unit uses 32768.
https://huggingface.co/nvidia/NVIDIA-Nemotron-3.5-Bolt-E4B-4GB
https://huggingface.co/unsloth/gemma-4-E4B-it-GGUF/blob/main/MTP/README.md

On this computer the running pages are `http://127.0.0.1:8081/` and
`http://127.0.0.1:8082/`. The `/v1` path is the OpenAI-compatible API. A
browser opened on `/v1` does not show the chat page.

Both servers require an API key on every route except `/health` and
`/v1/health`. The key is `secrets/llama-api-key.age`. The decrypted
file is `/run/agenix/llama-api-key`. It is not in git. Read it with
`pkexec cat /run/agenix/llama-api-key`. Open WebUI sends that key. The
llama-server pages need it before a prompt runs. n8n does not read the
file: its OpenAI credential has to use that same line. Uptime Kuma
still probes `/health`, which does not require the key.

The GGUF files are official Liquid AI Q8_0 weights. They are downloaded to
`/home/rileyt/llama-models` and copied into `/var/lib/llama-cpp/models`
when the system activates. The weights are not in git. LFM3-Omni-2B is
loaded on port 8081. LFM3-VL-2B used that slot before. Activation copies
both, and the VL files stay in the service directory unloaded. Omni loads
`mmproj-LFM3-Omni-2B-Q8_0.gguf`, which carries the audio and vision
weights. `ffmpeg` is on that service's `PATH` for video input. The model
id on port 8081 is `lfm3-omni`. Omni does not reason, so the server uses
`--reasoning off` and `--temp 0`.

The Omni server is pinned to the RTX 3050 by GPU UUID
`GPU-d80211d0-ecb1-e279-4f4d-34c53d278895`. That card has 6GB and also
drives the desktop. The GTX 1660 SUPER runs whichever
`my.hardware.gtx1660` names, Breeze TTS or Nemotron.
The package builds CUDA for compute capabilities 7.5 and 8.6, which
covers both cards, and CPU backends for runtime dispatch. The 1.7B server sets
`CUDA_VISIBLE_DEVICES` empty, `--device none`, and `-ngl 0`. A thread
sweep at 8, 12, 16, and 20 chose 12 because that count had the fastest
generation. 20 was fastest on a 512-token prefill. Both servers set
`--cache-type-k q8_0`, `--cache-type-v q8_0`, and `--flash-attn on`.

Omni answers in text or speech and does not think. Its server uses
`--reasoning off` and `--temp 0`. Speech sampling stays in the GGUF.
The 1.7B server uses `--temp 0.1`, `--top-k 50`, and `--repeat-penalty 1.1`.
That model thinks before it answers and keeps the trace in
`reasoning_content`, so a very small `max_tokens` can come back with an
empty answer. A client of the 1.7B server should allow up to 16384 new
tokens. Omni has reasoning turned off, so a short reply does not need
that budget.

Measured on 2026-10-28 with `llama-bench`, three runs each, before the
servers moved. Those runs used an f16 KV cache, with Omni on the RTX 3050
and the 1.7B model on the CPU. llama-bench sizes the context to the test.

LFM3-Omni-2B Q8_0 on the RTX 3050:

| Test | Tokens/s |
|---|---|
| pp512 | 4082.64 ± 159.09 |
| pp4096 | 3625.93 ± 52.43 |
| pp16384 | 3262.16 ± 26.90 |
| tg128 | 53.12 ± 0.20 |
| tg512 | 52.53 ± 0.52 |

LFM3-1.7B Q8_0 on the CPU at 12 threads:

| Test | Tokens/s |
|---|---|
| pp512 | 246.60 ± 5.24 |
| pp2048 | 240.25 ± 1.62 |
| pp8192 | 227.70 ± 1.03 |
| tg128 | 31.33 ± 0.06 |
| tg512 | 31.00 ± 0.20 |

`llama-bench` labels the Omni text file `lfm3 1.7B Q8_0` because the text
tensors are 1.73B parameters. The file's own metadata says
`general.name = LFM3 Omni 2B`. The vision and audio weights are in the
mmproj.

## Open WebUI

Open WebUI 0.13.0 is the chat page for the running llama.cpp servers. It is
the official image `ghcr.io/open-webui/open-webui:v0.13.0`, on the host
network so it can call llama.cpp on `127.0.0.1`. On this computer it is
`http://127.0.0.1:8088`. On the tailnet it is
`https://nixos.taile9f484.ts.net:8088`. The first account created is the
admin. Create it at the loopback URL before an untrusted device is on
the tailnet. The API keys sent to the llama servers come from
`/run/agenix/llama-api-key`. Chats stay in `/var/lib/open-webui/data`, which
is not in git. v0.13.0 changes the database schema. The first switch to
that version saves `/var/lib/open-webui/data/webui.db.bak-before-0.13.0`.
Going back to 0.11.1 means restoring that file.

## n8n

n8n 2.34.6 is the workflow editor. On this computer it is
`http://127.0.0.1:5678`. On the tailnet it is
`https://nixos.taile9f484.ts.net:5678`. The first visit creates the owner
account. That account, the workflows, the SQLite database, and the
encryption key live in `/var/lib/n8n` and are not in git.

LFM3-1.7B is the model n8n calls for ordinary text. The request stays on
this computer at `http://127.0.0.1:8082/v1`. It does not go out through
Tailscale. LFM3-Omni-2B is on `http://127.0.0.1:8081/v1`, model id
`lfm3-omni`. Discord voice messages are converted at
`http://127.0.0.1:8091/` (POST the audio bytes, the response is 16 kHz
mono wav) because llama.cpp does not decode Discord's Ogg Opus.
`http://127.0.0.1:8091/discord-voice` turns speech wav into the Ogg Opus
file, duration, and waveform Discord uses for a voice memo. The Discord
chat workflow asks Breeze for that wav at
`http://127.0.0.1:8084/v1/audio/speech` with `"response_format":"wav"`.
After the owner account exists, add one OpenAI credential:

- API key: the single line in `/run/agenix/llama-api-key`
  (`pkexec cat /run/agenix/llama-api-key`). Update the saved credential
  to that line before a workflow calls the model.
- Base URL: `http://127.0.0.1:8082/v1`
- Organization ID: empty

On an OpenAI node or an OpenAI Chat Model node, the model id is
`lfm3-1.7b`. Leave "Use Responses API" off. The 1.7B server has one slot
and is shared with Open WebUI, so a workflow waits if a chat is already
generating.

Uptime Kuma checks `http://127.0.0.1:5678/healthz` every 60 seconds, the
same way it checks the other apps. That monitor lives in
`/var/lib/uptime-kuma`, not in this repository.

A workflow sends a phone notification with an HTTP Request node. n8n does
not send one on its own.

- Method: `POST`
- URL: `http://127.0.0.1:2586/n8n`
- Authentication: Generic credential type, Header Auth. Name
  `Authorization`, value `Bearer` and the publisher token from
  `pkexec cat /run/agenix/ntfy-passwords`
- Body: the message text

`Title` and `Priority` can be extra headers. `Priority: high` is 4 and
`urgent` is 5. The phone is subscribed to the topic `n8n`.

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
| Sonarr, Radarr, Lidarr, Uptime Kuma, n8n | `apps` | Publish only, using the token |

| Topic | Who publishes | When |
|---|---|---|
| `movies` | Radarr | A movie file is imported |
| `shows` | Sonarr | An episode file is imported |
| `music` | Lidarr | A release is imported |
| `uptime` | Uptime Kuma | A monitor changes state |
| `n8n` | an n8n workflow | The workflow posts a message |

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
4. Subscribe to `movies`, `shows`, `music`, `uptime`, and `n8n`.

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
is one worker. The RTX 3050 is left to the desktop and LFM3-Omni.

The Homarr tile is added in the Homarr web UI and
stored in `/var/lib/homarr`.

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

## Apply and validate

Change this computer with `nixctl` after it is installed. `nixctl apply`
builds the config, activates it as a test, and keeps it only if no new
service is broken. It also commits the change locally. It does not push.

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
